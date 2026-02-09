//
//  CommunityManager.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CloudKit
import Network
#if canImport(DeviceKit)
import DeviceKit
#endif

/// Manages all CloudKit operations for the public Community feature
@MainActor
@Observable
final class CommunityManager {
    // MARK: - State

    /// Published colors fetched from the public database
    private(set) var colors: [CommunityColor] = []

    /// Published palettes fetched from the public database
    private(set) var palettes: [CommunityPalette] = []

    /// Whether a fetch operation is in progress
    private(set) var isLoading: Bool = false

    /// Whether more content is available for pagination
    private(set) var hasMoreColors: Bool = true
    private(set) var hasMorePalettes: Bool = true

    /// Current error, if any
    private(set) var error: OpaliteError?

    /// Current user's CloudKit record ID (nil if not signed in)
    private(set) var currentUserRecordID: CKRecord.ID?

    /// Current user's display name from settings
    var publisherName: String = "User"

    /// Whether the device has network connectivity
    private(set) var isConnectedToNetwork: Bool = true

    /// Whether the current user is an admin
    private(set) var isAdmin: Bool = false

    // MARK: - Private

    /// Admin email for Community moderation
    private let adminEmail = "nick@molargiksoftware.com"

    @ObservationIgnored
    private let container: CKContainer

    @ObservationIgnored
    private let publicDatabase: CKDatabase

    @ObservationIgnored
    private var colorCursor: CKQueryOperation.Cursor?

    @ObservationIgnored
    private var paletteCursor: CKQueryOperation.Cursor?

    /// Rate limiting: timestamps of recent publishes
    @ObservationIgnored
    private var recentPublishes: [Date] = []

    @ObservationIgnored
    private let networkMonitor = NWPathMonitor()

    @ObservationIgnored
    private let networkQueue = DispatchQueue(label: "com.opalite.networkmonitor")

    private let maxPublishesPerHour = 10
    private let resultsPerPage = 20

    // MARK: - Initialization

    init(containerIdentifier: String = "iCloud.com.molargiksoftware.Opalite") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDatabase = container.publicCloudDatabase

        startNetworkMonitoring()

        Task {
            await fetchCurrentUserRecordID()
        }
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnectedToNetwork = isConnected
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - User Identity

    /// Fetches the current user's CloudKit record ID
    func fetchCurrentUserRecordID() async {
        do {
            let recordID = try await container.userRecordID()
            currentUserRecordID = recordID
        } catch {
            currentUserRecordID = nil
            #if DEBUG
            print("[CommunityManager] Failed to fetch user record ID: \(error)")
            #endif
        }
    }

    /// Checks if the current user is signed into iCloud
    var isUserSignedIn: Bool {
        currentUserRecordID != nil
    }

    /// Discovers the current user's name from iCloud user identity
    /// Returns a formatted display name (first + last) or nil if unavailable
    @available(iOS, deprecated: 17.0, message: "Using deprecated CloudKit user discoverability APIs")
    func discoverCurrentUserName() async -> String? {
        guard let userRecordID = currentUserRecordID else {
            #if DEBUG
            print("[CommunityManager] No user record ID available for name discovery")
            #endif
            return nil
        }

        do {
            let status = try await container.requestApplicationPermission(.userDiscoverability)
            guard status == .granted else {
                #if DEBUG
                print("[CommunityManager] User discoverability not granted for name discovery")
                #endif
                return nil
            }

            let identity = try await container.userIdentity(forUserRecordID: userRecordID)

            if let nameComponents = identity?.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                formatter.style = .default
                let formattedName = formatter.string(from: nameComponents)
                if !formattedName.isEmpty {
                    return formattedName
                }
            }

            return nil
        } catch {
            #if DEBUG
            print("[CommunityManager] Failed to discover user name: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Publishing Colors

    /// Publishes a color to the public Community database
    @discardableResult
    func publishColor(_ color: OpaliteColor) async throws -> CKRecord.ID {
        guard isUserSignedIn, let userRecordID = currentUserRecordID else {
            throw OpaliteError.communityPublishFailed(reason: "Sign in to iCloud to publish")
        }

        // Rate limiting check
        guard canPublish() else {
            throw OpaliteError.communityRateLimited
        }

        let record = CKRecord(recordType: CommunityColor.recordType)
        record["originalColorID"] = color.id.uuidString
        record["name"] = color.name
        record["notes"] = color.notes
        record["red"] = color.red
        record["green"] = color.green
        record["blue"] = color.blue
        record["alpha"] = color.alpha
        record["hexString"] = color.hexString
        record["publisherName"] = publisherName
        record["publisherUserRecordID"] = CKRecord.Reference(recordID: userRecordID, action: .none)
        record["createdOnDeviceName"] = color.createdOnDeviceName
        record["originalCreatedAt"] = color.createdAt
        record["publishedAt"] = Date()
        record["likeCount"] = Int64(0)
        record["reportCount"] = Int64(0)
        record["isHidden"] = Int64(0)

        do {
            let savedRecord = try await publicDatabase.save(record)
            recentPublishes.append(Date())
            cleanupRateLimitTracking()

            // Add to local cache
            let newColor = try CommunityColor(record: savedRecord)
            colors.insert(newColor, at: 0)

            return savedRecord.recordID
        } catch {
            throw OpaliteError.communityPublishFailed(reason: error.localizedDescription)
        }
    }

    /// Publishes a palette to the public Community database
    @discardableResult
    func publishPalette(_ palette: OpalitePalette, previewImage: Data? = nil) async throws -> CKRecord.ID {
        guard isUserSignedIn, let userRecordID = currentUserRecordID else {
            throw OpaliteError.communityPublishFailed(reason: "Sign in to iCloud to publish")
        }

        guard canPublish() else {
            throw OpaliteError.communityRateLimited
        }

        let paletteRecord = CKRecord(recordType: CommunityPalette.recordType)
        paletteRecord["originalPaletteID"] = palette.id.uuidString
        paletteRecord["name"] = palette.name
        paletteRecord["notes"] = palette.notes
        paletteRecord["tags"] = palette.tags
        paletteRecord["colorCount"] = Int64(palette.colors?.count ?? 0)
        paletteRecord["publisherName"] = publisherName
        paletteRecord["publisherUserRecordID"] = CKRecord.Reference(recordID: userRecordID, action: .none)
        paletteRecord["createdOnDeviceName"] = nil // Palettes don't track device name
        paletteRecord["originalCreatedAt"] = palette.createdAt
        paletteRecord["publishedAt"] = Date()
        paletteRecord["likeCount"] = Int64(0)
        paletteRecord["reportCount"] = Int64(0)
        paletteRecord["isHidden"] = Int64(0)

        // Attach preview image as CKAsset if provided
        if let imageData = previewImage {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
            try imageData.write(to: tempURL)
            paletteRecord["previewImageData"] = CKAsset(fileURL: tempURL)
        }

        do {
            let savedPaletteRecord = try await publicDatabase.save(paletteRecord)
            let paletteRecordID = savedPaletteRecord.recordID

            // Track saved colors for local cache
            var savedCommunityColors: [CommunityColor] = []

            // Now publish all colors in the palette and create junction records
            if let colors = palette.colors, !colors.isEmpty {
                for (index, color) in colors.enumerated() {
                    // First, publish the color
                    let colorRecord = CKRecord(recordType: CommunityColor.recordType)
                    colorRecord["originalColorID"] = color.id.uuidString
                    colorRecord["name"] = color.name
                    colorRecord["notes"] = color.notes
                    colorRecord["red"] = color.red
                    colorRecord["green"] = color.green
                    colorRecord["blue"] = color.blue
                    colorRecord["alpha"] = color.alpha
                    colorRecord["hexString"] = color.hexString
                    colorRecord["publisherName"] = publisherName
                    colorRecord["publisherUserRecordID"] = CKRecord.Reference(recordID: userRecordID, action: .none)
                    colorRecord["createdOnDeviceName"] = color.createdOnDeviceName
                    colorRecord["originalCreatedAt"] = color.createdAt
                    colorRecord["publishedAt"] = Date()
                    colorRecord["likeCount"] = Int64(0)
                    colorRecord["reportCount"] = Int64(0)
                    colorRecord["isHidden"] = Int64(0)

                    let savedColorRecord = try await publicDatabase.save(colorRecord)

                    // Track for local cache
                    if let communityColor = try? CommunityColor(record: savedColorRecord) {
                        savedCommunityColors.append(communityColor)
                    }

                    // Create junction record
                    let junctionRecord = CKRecord(recordType: "PublishedPaletteColor")
                    junctionRecord["paletteRecordID"] = CKRecord.Reference(recordID: paletteRecordID, action: .deleteSelf)
                    junctionRecord["colorRecordID"] = CKRecord.Reference(recordID: savedColorRecord.recordID, action: .none)
                    junctionRecord["sortOrder"] = Int64(index)

                    _ = try await publicDatabase.save(junctionRecord)
                }
            }

            recentPublishes.append(Date())
            cleanupRateLimitTracking()

            // Add to local cache with colors populated
            var newPalette = try CommunityPalette(record: savedPaletteRecord)
            newPalette.colors = savedCommunityColors
            palettes.insert(newPalette, at: 0)

            return paletteRecordID
        } catch {
            throw OpaliteError.communityPublishFailed(reason: error.localizedDescription)
        }
    }

    /// Unpublishes a color from the public database
    func unpublishColor(recordID: CKRecord.ID) async throws {
        do {
            try await publicDatabase.deleteRecord(withID: recordID)
            colors.removeAll { $0.id == recordID }
        } catch {
            throw OpaliteError.communityDeleteFailed(reason: error.localizedDescription)
        }
    }

    /// Unpublishes a palette and its associated junction records
    func unpublishPalette(recordID: CKRecord.ID) async throws {
        // First, delete junction records
        let predicate = NSPredicate(format: "paletteRecordID == %@", CKRecord.Reference(recordID: recordID, action: .none))
        let query = CKQuery(recordType: "PublishedPaletteColor", predicate: predicate)

        do {
            let (junctionResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)
            for result in junctionResults {
                if case .success = result.1 {
                    try await publicDatabase.deleteRecord(withID: result.0)
                }
            }

            // Then delete the palette record
            try await publicDatabase.deleteRecord(withID: recordID)
            palettes.removeAll { $0.id == recordID }
        } catch {
            throw OpaliteError.communityDeleteFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Fetching

    /// Fetches published colors from the public database
    func fetchPublishedColors(sortBy: CommunitySortOption = .newest, refresh: Bool = false) async throws {
        if refresh {
            colorCursor = nil
            colors = []
            hasMoreColors = true
        }

        guard hasMoreColors else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let predicate = NSPredicate(format: "isHidden == %d", Int64(0))
        let sortDescriptor = NSSortDescriptor(key: sortBy.sortDescriptorKey, ascending: sortBy.ascending)
        let query = CKQuery(recordType: CommunityColor.recordType, predicate: predicate)
        query.sortDescriptors = [sortDescriptor]

        do {
            let (results, cursor) = try await publicDatabase.records(matching: query, resultsLimit: resultsPerPage)

            var newColors: [CommunityColor] = []
            for result in results {
                if case .success(let record) = result.1 {
                    if let color = try? CommunityColor(record: record) {
                        newColors.append(color)
                    }
                }
            }

            // Filter out duplicates before appending
            let existingIDs = Set(colors.map { $0.id })
            let uniqueNewColors = newColors.filter { !existingIDs.contains($0.id) }
            colors.append(contentsOf: uniqueNewColors)
            colorCursor = cursor
            hasMoreColors = cursor != nil
        } catch {
            self.error = .communityFetchFailed(reason: error.localizedDescription)
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches more colors using the stored cursor
    func fetchMoreColors(sortBy: CommunitySortOption = .newest) async throws {
        guard let cursor = colorCursor else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (results, newCursor) = try await publicDatabase.records(continuingMatchFrom: cursor, resultsLimit: resultsPerPage)

            var newColors: [CommunityColor] = []
            for result in results {
                if case .success(let record) = result.1 {
                    if let color = try? CommunityColor(record: record) {
                        newColors.append(color)
                    }
                }
            }

            // Filter out duplicates before appending
            let existingIDs = Set(colors.map { $0.id })
            let uniqueNewColors = newColors.filter { !existingIDs.contains($0.id) }
            colors.append(contentsOf: uniqueNewColors)
            colorCursor = newCursor
            hasMoreColors = newCursor != nil
        } catch {
            self.error = .communityFetchFailed(reason: error.localizedDescription)
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches published palettes from the public database
    func fetchPublishedPalettes(sortBy: CommunitySortOption = .newest, refresh: Bool = false) async throws {
        if refresh {
            paletteCursor = nil
            palettes = []
            hasMorePalettes = true
        }

        guard hasMorePalettes else { return }

        isLoading = true
        error = nil

        let predicate = NSPredicate(format: "isHidden == %d", Int64(0))
        let sortDescriptor = NSSortDescriptor(key: sortBy.sortDescriptorKey, ascending: sortBy.ascending)
        let query = CKQuery(recordType: CommunityPalette.recordType, predicate: predicate)
        query.sortDescriptors = [sortDescriptor]

        do {
            let (results, cursor) = try await publicDatabase.records(matching: query, resultsLimit: resultsPerPage)

            // First pass: create palettes without colors (shows immediately with placeholders)
            var newPalettes: [CommunityPalette] = []
            for result in results {
                if case .success(let record) = result.1 {
                    if let palette = try? CommunityPalette(record: record) {
                        newPalettes.append(palette)
                    }
                }
            }

            // Filter out duplicates before appending
            let existingIDs = Set(palettes.map { $0.id })
            let uniqueNewPalettes = newPalettes.filter { !existingIDs.contains($0.id) }
            palettes.append(contentsOf: uniqueNewPalettes)
            paletteCursor = cursor
            hasMorePalettes = cursor != nil

            // Stop showing loading indicator - palettes are visible with placeholders
            isLoading = false

            // Second pass: load colors concurrently in background
            await loadColorsForPalettes(uniqueNewPalettes)
        } catch {
            isLoading = false
            self.error = .communityFetchFailed(reason: error.localizedDescription)
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    /// Loads colors for multiple palettes concurrently, updating each palette as its colors arrive
    private func loadColorsForPalettes(_ palettesToLoad: [CommunityPalette]) async {
        await withTaskGroup(of: (CKRecord.ID, [CommunityColor]).self) { group in
            for palette in palettesToLoad {
                group.addTask {
                    let colors = (try? await self.fetchPaletteColors(paletteRecordID: palette.id)) ?? []
                    return (palette.id, colors)
                }
            }

            for await (paletteID, colors) in group {
                if let index = palettes.firstIndex(where: { $0.id == paletteID }) {
                    var updatedPalette = palettes[index]
                    updatedPalette.colors = colors
                    palettes[index] = updatedPalette
                }
            }
        }
    }

    /// Fetches more palettes using the stored cursor
    func fetchMorePalettes(sortBy: CommunitySortOption = .newest) async throws {
        guard let cursor = paletteCursor else { return }

        isLoading = true

        do {
            let (results, newCursor) = try await publicDatabase.records(continuingMatchFrom: cursor, resultsLimit: resultsPerPage)

            // First pass: create palettes without colors
            var newPalettes: [CommunityPalette] = []
            for result in results {
                if case .success(let record) = result.1 {
                    if let palette = try? CommunityPalette(record: record) {
                        newPalettes.append(palette)
                    }
                }
            }

            // Filter out duplicates before appending
            let existingIDs = Set(palettes.map { $0.id })
            let uniqueNewPalettes = newPalettes.filter { !existingIDs.contains($0.id) }
            palettes.append(contentsOf: uniqueNewPalettes)
            paletteCursor = newCursor
            hasMorePalettes = newCursor != nil

            // Stop loading indicator - palettes visible with placeholders
            isLoading = false

            // Load colors concurrently in background
            await loadColorsForPalettes(uniqueNewPalettes)
        } catch {
            isLoading = false
            self.error = .communityFetchFailed(reason: error.localizedDescription)
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches colors belonging to a specific palette
    func fetchPaletteColors(paletteRecordID: CKRecord.ID) async throws -> [CommunityColor] {
        // First, get junction records
        let predicate = NSPredicate(format: "paletteRecordID == %@", CKRecord.Reference(recordID: paletteRecordID, action: .none))
        let sortDescriptor = NSSortDescriptor(key: "sortOrder", ascending: true)
        let query = CKQuery(recordType: "PublishedPaletteColor", predicate: predicate)
        query.sortDescriptors = [sortDescriptor]

        do {
            let (junctionResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)

            var colorRecordIDs: [CKRecord.ID] = []
            for result in junctionResults {
                if case .success(let record) = result.1,
                   let colorRef = record["colorRecordID"] as? CKRecord.Reference {
                    colorRecordIDs.append(colorRef.recordID)
                }
            }

            // Fetch color records concurrently, preserving sort order
            let indexedColors = await withTaskGroup(of: (Int, CommunityColor?).self) { group in
                for (index, recordID) in colorRecordIDs.enumerated() {
                    group.addTask {
                        guard let record = try? await self.publicDatabase.record(for: recordID),
                              let color = try? CommunityColor(record: record) else {
                            return (index, nil)
                        }
                        return (index, color)
                    }
                }

                var results: [(Int, CommunityColor?)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }

            return indexedColors
                .sorted { $0.0 < $1.0 }
                .compactMap(\.1)
        } catch {
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Local Sorting

    /// Sorts cached colors locally without network fetch
    func sortColors(by option: CommunitySortOption) {
        switch option {
        case .newest:
            colors.sort { $0.publishedAt > $1.publishedAt }
        case .oldest:
            colors.sort { $0.publishedAt < $1.publishedAt }
        case .alphabetical:
            colors.sort { ($0.name ?? $0.hexString).localizedCaseInsensitiveCompare($1.name ?? $1.hexString) == .orderedAscending }
        }
    }

    /// Sorts cached palettes locally without network fetch
    func sortPalettes(by option: CommunitySortOption) {
        switch option {
        case .newest:
            palettes.sort { $0.publishedAt > $1.publishedAt }
        case .oldest:
            palettes.sort { $0.publishedAt < $1.publishedAt }
        case .alphabetical:
            palettes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    // MARK: - Search (Local Filtering)

    /// Full unfiltered colors cache (for search restoration)
    private var allColors: [CommunityColor] = []
    /// Full unfiltered palettes cache (for search restoration)
    private var allPalettes: [CommunityPalette] = []
    /// Whether we're currently showing search results
    private(set) var isShowingSearchResults = false

    /// Stores current data as the full cache (call after fetching)
    func cacheFullDataset() {
        allColors = colors
        allPalettes = palettes
    }

    /// Searches colors by name or hex string (local filter on cached data)
    func searchColors(query searchQuery: String, sortBy: CommunitySortOption = .newest) async throws {
        guard !searchQuery.isEmpty else {
            // Restore full dataset
            if isShowingSearchResults {
                colors = allColors
                sortColors(by: sortBy)
                isShowingSearchResults = false
            }
            return
        }

        // If we don't have cached data, fetch first
        if allColors.isEmpty {
            try await fetchPublishedColors(sortBy: sortBy, refresh: true)
            cacheFullDataset()
        }

        let lowercaseQuery = searchQuery.lowercased()

        // Filter locally - search by name, hex, or color classification
        colors = allColors.filter { color in
            let nameMatch = color.name?.lowercased().contains(lowercaseQuery) ?? false
            let hexMatch = color.hexString.lowercased().contains(lowercaseQuery)
            let colorClassificationMatch = color.matchesColorSearch(lowercaseQuery)
            return nameMatch || hexMatch || colorClassificationMatch
        }

        sortColors(by: sortBy)
        isShowingSearchResults = true
        hasMoreColors = false
    }

    /// Searches palettes by name or tags (local filter on cached data)
    func searchPalettes(query searchQuery: String, sortBy: CommunitySortOption = .newest) async throws {
        guard !searchQuery.isEmpty else {
            // Restore full dataset
            if isShowingSearchResults {
                palettes = allPalettes
                sortPalettes(by: sortBy)
                isShowingSearchResults = false
            }
            return
        }

        // If we don't have cached data, fetch first
        if allPalettes.isEmpty {
            try await fetchPublishedPalettes(sortBy: sortBy, refresh: true)
            cacheFullDataset()
        }

        let lowercaseQuery = searchQuery.lowercased()

        // Filter locally - search by name or tags
        palettes = allPalettes.filter { palette in
            let nameMatch = palette.name.lowercased().contains(lowercaseQuery)
            let tagMatch = palette.tags.contains { $0.lowercased().contains(lowercaseQuery) }
            return nameMatch || tagMatch
        }

        sortPalettes(by: sortBy)
        isShowingSearchResults = true
        hasMorePalettes = false
    }

    // MARK: - Reporting

    /// Reports an item for moderation
    func reportItem(recordID: CKRecord.ID, type: CommunityItemType, reason: ReportReason, details: String?) async throws {
        guard isUserSignedIn, let userRecordID = currentUserRecordID else {
            throw OpaliteError.communityReportFailed(reason: "Sign in to iCloud to report")
        }

        let reportRecord = CKRecord(recordType: "CommunityReport")
        reportRecord["reporterUserRecordID"] = CKRecord.Reference(recordID: userRecordID, action: .none)
        reportRecord["targetRecordID"] = CKRecord.Reference(recordID: recordID, action: .none)
        reportRecord["targetType"] = type.rawValue
        reportRecord["reason"] = reason.rawValue
        reportRecord["details"] = details
        reportRecord["status"] = "pending"
        reportRecord["createdAt"] = Date()

        do {
            _ = try await publicDatabase.save(reportRecord)

            // Increment report count
            let targetRecord = try await publicDatabase.record(for: recordID)
            let currentReportCount = targetRecord["reportCount"] as? Int64 ?? 0
            targetRecord["reportCount"] = currentReportCount + 1

            // Auto-hide if threshold exceeded
            if currentReportCount + 1 >= 5 {
                targetRecord["isHidden"] = Int64(1)
            }

            _ = try await publicDatabase.save(targetRecord)

            // Update local cache
            if type == .color {
                if let index = colors.firstIndex(where: { $0.id == recordID }) {
                    colors[index].reportCount += 1
                    if colors[index].reportCount >= 5 {
                        colors.remove(at: index)
                    }
                }
            } else {
                if let index = palettes.firstIndex(where: { $0.id == recordID }) {
                    palettes[index].reportCount += 1
                    if palettes[index].reportCount >= 5 {
                        palettes.remove(at: index)
                    }
                }
            }
        } catch {
            throw OpaliteError.communityReportFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Save to Portfolio

    /// Saves an CommunityColor to the user's portfolio (requires Onyx subscription)
    func saveColorToPortfolio(
        _ communityColor: CommunityColor,
        colorManager: ColorManager,
        subscriptionManager: SubscriptionManager
    ) throws {
        guard subscriptionManager.hasOnyxEntitlement else {
            throw OpaliteError.communityRequiresOnyx
        }

        // Check for duplicates by original color ID
        let existingColor = colorManager.colors.first { $0.id == communityColor.originalColorID }
        if existingColor != nil {
            throw OpaliteError.communityColorAlreadyExists
        }

        #if canImport(DeviceKit)
        let deviceName = Device.current.safeDescription
        #else
        let deviceName = "Unknown Device"
        #endif

        let newColor = OpaliteColor(
            id: UUID(), // Create new ID to avoid conflicts
            name: communityColor.name,
            notes: communityColor.notes,
            createdByDisplayName: communityColor.publisherName,
            createdOnDeviceName: deviceName,
            updatedOnDeviceName: deviceName,
            createdAt: Date(),
            updatedAt: Date(),
            red: communityColor.red,
            green: communityColor.green,
            blue: communityColor.blue,
            alpha: communityColor.alpha
        )

        _ = try colorManager.createColor(existing: newColor)
    }

    /// Saves an CommunityPalette to the user's portfolio (requires Onyx subscription)
    func savePaletteToPortfolio(
        _ communityPalette: CommunityPalette,
        colorManager: ColorManager,
        subscriptionManager: SubscriptionManager
    ) async throws {
        guard subscriptionManager.hasOnyxEntitlement else {
            throw OpaliteError.communityRequiresOnyx
        }

        // Check for duplicates by original palette ID
        let existingPalette = colorManager.palettes.first { $0.id == communityPalette.originalPaletteID }
        if existingPalette != nil {
            throw OpaliteError.communityPaletteAlreadyExists
        }

        // Fetch the palette colors
        let communityColors = try await fetchPaletteColors(paletteRecordID: communityPalette.id)

        // Create local colors
        var localColors: [OpaliteColor] = []
        for communityColor in communityColors {
            #if canImport(DeviceKit)
            let deviceName = Device.current.safeDescription
            #else
            let deviceName = "Unknown Device"
            #endif

            let localColor = OpaliteColor(
                id: UUID(),
                name: communityColor.name,
                notes: communityColor.notes,
                createdByDisplayName: communityColor.publisherName,
                createdOnDeviceName: deviceName,
                updatedOnDeviceName: deviceName,
                createdAt: Date(),
                updatedAt: Date(),
                red: communityColor.red,
                green: communityColor.green,
                blue: communityColor.blue,
                alpha: communityColor.alpha
            )
            localColors.append(localColor)
        }

        // Create the palette with colors
        try colorManager.createPalette(
            name: communityPalette.name,
            notes: communityPalette.notes,
            tags: communityPalette.tags,
            colors: localColors
        )
    }

    // MARK: - Publisher Profile

    /// Fetches content metadata published by a specific user (palettes without colors for fast initial load)
    func fetchPublisherContentMetadata(userRecordID: CKRecord.ID) async throws -> (colors: [CommunityColor], palettes: [CommunityPalette]) {
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)

        // Fetch colors
        let colorPredicate = NSPredicate(format: "publisherUserRecordID == %@ AND isHidden == %d", userRef, Int64(0))
        let colorQuery = CKQuery(recordType: CommunityColor.recordType, predicate: colorPredicate)
        colorQuery.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]

        // Fetch palettes
        let palettePredicate = NSPredicate(format: "publisherUserRecordID == %@ AND isHidden == %d", userRef, Int64(0))
        let paletteQuery = CKQuery(recordType: CommunityPalette.recordType, predicate: palettePredicate)
        paletteQuery.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]

        do {
            let (colorResults, _) = try await publicDatabase.records(matching: colorQuery, resultsLimit: 50)
            let (paletteResults, _) = try await publicDatabase.records(matching: paletteQuery, resultsLimit: 50)

            var userColors: [CommunityColor] = []
            for result in colorResults {
                if case .success(let record) = result.1,
                   let color = try? CommunityColor(record: record) {
                    userColors.append(color)
                }
            }

            // Create palettes without loading colors (for fast display with placeholders)
            var userPalettes: [CommunityPalette] = []
            for result in paletteResults {
                if case .success(let record) = result.1,
                   let palette = try? CommunityPalette(record: record) {
                    userPalettes.append(palette)
                }
            }

            return (userColors, userPalettes)
        } catch {
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches content published by a specific user (full load with palette colors)
    func fetchPublisherContent(userRecordID: CKRecord.ID) async throws -> (colors: [CommunityColor], palettes: [CommunityPalette]) {
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)

        // Fetch colors
        let colorPredicate = NSPredicate(format: "publisherUserRecordID == %@ AND isHidden == %d", userRef, Int64(0))
        let colorQuery = CKQuery(recordType: CommunityColor.recordType, predicate: colorPredicate)
        colorQuery.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]

        // Fetch palettes
        let palettePredicate = NSPredicate(format: "publisherUserRecordID == %@ AND isHidden == %d", userRef, Int64(0))
        let paletteQuery = CKQuery(recordType: CommunityPalette.recordType, predicate: palettePredicate)
        paletteQuery.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]

        do {
            let (colorResults, _) = try await publicDatabase.records(matching: colorQuery, resultsLimit: 50)
            let (paletteResults, _) = try await publicDatabase.records(matching: paletteQuery, resultsLimit: 50)

            var userColors: [CommunityColor] = []
            for result in colorResults {
                if case .success(let record) = result.1,
                   let color = try? CommunityColor(record: record) {
                    userColors.append(color)
                }
            }

            // First pass: create palettes without colors
            var userPalettes: [CommunityPalette] = []
            for result in paletteResults {
                if case .success(let record) = result.1,
                   let palette = try? CommunityPalette(record: record) {
                    userPalettes.append(palette)
                }
            }

            // Load colors concurrently for all palettes
            await withTaskGroup(of: (CKRecord.ID, [CommunityColor]).self) { group in
                for palette in userPalettes {
                    group.addTask {
                        let colors = (try? await self.fetchPaletteColors(paletteRecordID: palette.id)) ?? []
                        return (palette.id, colors)
                    }
                }

                for await (paletteID, colors) in group {
                    if let index = userPalettes.firstIndex(where: { $0.id == paletteID }) {
                        userPalettes[index].colors = colors
                    }
                }
            }

            return (userColors, userPalettes)
        } catch {
            throw OpaliteError.communityFetchFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Rate Limiting

    private func canPublish() -> Bool {
        cleanupRateLimitTracking()
        return recentPublishes.count < maxPublishesPerHour
    }

    private func cleanupRateLimitTracking() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        recentPublishes.removeAll { $0 < oneHourAgo }
    }

    // MARK: - Refresh

    /// Refreshes all Community content
    func refreshAll() async {
        do {
            try await fetchPublishedColors(refresh: true)
            try await fetchPublishedPalettes(refresh: true)
        } catch {
            #if DEBUG
            print("[CommunityManager] Failed to refresh: \(error)")
            #endif
        }
    }

    // MARK: - Admin

    /// Check if current user is admin (by email)
    func checkAdminStatus() async {
        guard let userRecordID = currentUserRecordID else {
            isAdmin = false
            #if DEBUG
            print("[CommunityManager] No user record ID available")
            #endif
            return
        }

        do {
            let result = try await performAdminCheck(userRecordID: userRecordID)
            isAdmin = result
            #if DEBUG
            print("[CommunityManager] Admin status: \(result ? "confirmed" : "not admin")")
            #endif
        } catch {
            isAdmin = false
            #if DEBUG
            print("[CommunityManager] Failed to check admin status: \(error)")
            #endif
        }
    }

    /// Helper to perform admin check using deprecated CloudKit APIs
    /// These APIs are deprecated but still functional; no modern replacement exists for email-based user lookup
    @available(iOS, deprecated: 17.0, message: "Using deprecated CloudKit user discoverability APIs")
    private func performAdminCheck(userRecordID: CKRecord.ID) async throws -> Bool {
        // Request permission to discover user identity
        let status = try await container.requestApplicationPermission(.userDiscoverability)
        guard status == .granted else {
            #if DEBUG
            print("[CommunityManager] User discoverability not granted: \(status)")
            #endif
            return false
        }

        // Look up the admin by email and check if it matches current user
        let adminIdentities = try await container.userIdentities(forEmailAddresses: [adminEmail])

        // Check if the admin email's identity matches the current user's record ID
        if let adminIdentity = adminIdentities[adminEmail],
           adminIdentity.userRecordID == userRecordID {
            return true
        }

        return false
    }

    /// Fetch all reported colors (admin only)
    func fetchReportedColors() async throws -> [CommunityColor] {
        guard isAdmin else { throw OpaliteError.communityAdminRequired }

        let predicate = NSPredicate(format: "reportCount > 0")
        let query = CKQuery(recordType: CommunityColor.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "reportCount", ascending: false)]

        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)
        return results.compactMap { result -> CommunityColor? in
            guard case .success(let record) = result.1 else { return nil }
            return try? CommunityColor(record: record)
        }
    }

    /// Fetch all reported palettes (admin only)
    func fetchReportedPalettes() async throws -> [CommunityPalette] {
        guard isAdmin else { throw OpaliteError.communityAdminRequired }

        let predicate = NSPredicate(format: "reportCount > 0")
        let query = CKQuery(recordType: CommunityPalette.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "reportCount", ascending: false)]

        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)
        return results.compactMap { result -> CommunityPalette? in
            guard case .success(let record) = result.1 else { return nil }
            return try? CommunityPalette(record: record)
        }
    }

    /// Clear reports for an item (admin only)
    func clearReports(recordID: CKRecord.ID) async throws {
        guard isAdmin else { throw OpaliteError.communityAdminRequired }

        let record = try await publicDatabase.record(for: recordID)
        record["reportCount"] = Int64(0)
        record["isHidden"] = Int64(0)
        _ = try await publicDatabase.save(record)

        // Delete associated report records
        let predicate = NSPredicate(format: "targetRecordID == %@", CKRecord.Reference(recordID: recordID, action: .none))
        let query = CKQuery(recordType: "CommunityReport", predicate: predicate)
        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)

        for result in results {
            if case .success = result.1 {
                try await publicDatabase.deleteRecord(withID: result.0)
            }
        }
    }

    /// Delete an entity and its reports (admin only)
    func adminDeleteEntity(recordID: CKRecord.ID, type: CommunityItemType) async throws {
        guard isAdmin else { throw OpaliteError.communityAdminRequired }

        // Delete associated reports first
        let predicate = NSPredicate(format: "targetRecordID == %@", CKRecord.Reference(recordID: recordID, action: .none))
        let query = CKQuery(recordType: "CommunityReport", predicate: predicate)
        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)

        for result in results {
            if case .success = result.1 {
                try await publicDatabase.deleteRecord(withID: result.0)
            }
        }

        // Delete the entity
        if type == .palette {
            try await unpublishPalette(recordID: recordID)
        } else {
            try await unpublishColor(recordID: recordID)
        }
    }
}

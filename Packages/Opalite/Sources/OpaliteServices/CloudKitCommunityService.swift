//
//  CloudKitCommunityService.swift
//  OpaliteServices
//
//  The CloudKit public-database implementation of `CommunityService`. Pagination cursors
//  are kept here and handed out as opaque tokens so callers stay CloudKit-free.
//

import CloudKit
import Foundation
import OpaliteCore
import os

public final class CloudKitCommunityService: CommunityService {
    private let container: CKContainer
    private let database: CKDatabase
    private var cursors: [String: CKQueryOperation.Cursor] = [:]

    public init(containerIdentifier: String = AppGroup.cloudKitContainerID) {
        container = CKContainer(identifier: containerIdentifier)
        database = container.publicCloudDatabase
    }

    // MARK: - Identity

    public func currentUserRecordID() async -> CommunityRecordID? {
        do {
            let id = try await container.userRecordID()
            return CommunityRecordID(id)
        } catch {
            Log.community.notice("No CloudKit user: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Fetching

    public func fetchColors(sortBy: CommunitySortOption, cursor: CommunityCursor?, limit: Int) async throws(OpaliteError) -> CommunityPage<CommunityColor> {
        let results: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            if let cursor, let ckCursor = cursors.removeValue(forKey: cursor.token) {
                results = try await database.records(continuingMatchFrom: ckCursor, resultsLimit: limit)
            } else {
                let query = CKQuery(recordType: CommunityColor.recordType, predicate: NSPredicate(format: "isHidden == %d", Int64(0)))
                query.sortDescriptors = [NSSortDescriptor(key: sortBy.sortField, ascending: sortBy.ascending)]
                results = try await database.records(matching: query, resultsLimit: limit)
            }
        } catch {
            throw .communityFetchFailed(reason: error.localizedDescription)
        }
        let items = results.matchResults.compactMap { _, result -> CommunityColor? in
            guard case .success(let record) = result else { return nil }
            return CommunityColor(record: record)
        }
        return CommunityPage(items: items, nextCursor: store(results.queryCursor))
    }

    public func fetchPalettes(sortBy: CommunitySortOption, cursor: CommunityCursor?, limit: Int) async throws(OpaliteError) -> CommunityPage<CommunityPalette> {
        let results: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            if let cursor, let ckCursor = cursors.removeValue(forKey: cursor.token) {
                results = try await database.records(continuingMatchFrom: ckCursor, resultsLimit: limit)
            } else {
                let query = CKQuery(recordType: CommunityPalette.recordType, predicate: NSPredicate(format: "isHidden == %d", Int64(0)))
                query.sortDescriptors = [NSSortDescriptor(key: sortBy.sortField, ascending: sortBy.ascending)]
                results = try await database.records(matching: query, resultsLimit: limit)
            }
        } catch {
            throw .communityFetchFailed(reason: error.localizedDescription)
        }
        let items = results.matchResults.compactMap { _, result -> CommunityPalette? in
            guard case .success(let record) = result else { return nil }
            return CommunityPalette(record: record)
        }
        return CommunityPage(items: items, nextCursor: store(results.queryCursor))
    }

    public func fetchPaletteColors(paletteID: CommunityRecordID) async throws(OpaliteError) -> [CommunityColor] {
        let reference = CKRecord.Reference(recordID: paletteID.ckRecordID, action: .none)
        let query = CKQuery(recordType: CommunityPalette.junctionRecordType, predicate: NSPredicate(format: "paletteRecordID == %@", reference))
        query.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        do {
            let (junctions, _) = try await database.records(matching: query, resultsLimit: 100)
            let colorIDs = junctions.compactMap { _, result -> CKRecord.ID? in
                guard case .success(let record) = result, let ref = record["colorRecordID"] as? CKRecord.Reference else { return nil }
                return ref.recordID
            }
            guard !colorIDs.isEmpty else { return [] }
            let fetched = try await database.records(for: colorIDs)
            return colorIDs.compactMap { id in
                guard case .success(let record)? = fetched[id] else { return nil }
                return CommunityColor(record: record)
            }
        } catch {
            throw .communityFetchFailed(reason: error.localizedDescription)
        }
    }

    public func fetchPublisherContent(userRecordID: CommunityRecordID) async throws(OpaliteError) -> (colors: [CommunityColor], palettes: [CommunityPalette]) {
        let reference = CKRecord.Reference(recordID: userRecordID.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "publisherUserRecordID == %@ AND isHidden == %d", reference, Int64(0))
        let colorQuery = CKQuery(recordType: CommunityColor.recordType, predicate: predicate)
        colorQuery.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]
        let paletteQuery = CKQuery(recordType: CommunityPalette.recordType, predicate: predicate)
        paletteQuery.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]
        do {
            let (colorResults, _) = try await database.records(matching: colorQuery, resultsLimit: 50)
            let (paletteResults, _) = try await database.records(matching: paletteQuery, resultsLimit: 50)
            let colors = colorResults.compactMap { _, result -> CommunityColor? in
                guard case .success(let record) = result else { return nil }
                return CommunityColor(record: record)
            }
            let palettes = paletteResults.compactMap { _, result -> CommunityPalette? in
                guard case .success(let record) = result else { return nil }
                return CommunityPalette(record: record)
            }
            return (colors, palettes)
        } catch {
            throw .communityFetchFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Publishing

    public func publish(_ color: ColorPublication, publisherName: String) async throws(OpaliteError) -> CommunityColor {
        guard let user = await currentUserRecordID() else { throw .communityNotSignedIn }
        let record = Self.makeColorRecord(color, publisherName: publisherName, user: user)
        do {
            let saved = try await database.save(record)
            guard let community = CommunityColor(record: saved) else { throw OpaliteError.communityPublishFailed(reason: "Unreadable record") }
            return community
        } catch let error as OpaliteError {
            throw error
        } catch {
            throw .communityPublishFailed(reason: error.localizedDescription)
        }
    }

    public func publish(_ palette: PalettePublication, publisherName: String) async throws(OpaliteError) -> CommunityPalette {
        guard let user = await currentUserRecordID() else { throw .communityNotSignedIn }
        let record = CKRecord(recordType: CommunityPalette.recordType)
        record["originalPaletteID"] = palette.originalPaletteID.uuidString
        record["name"] = palette.name
        record["notes"] = palette.notes
        record["tags"] = palette.tags
        record["colorCount"] = Int64(palette.colors.count)
        record["publisherName"] = publisherName
        record["publisherUserRecordID"] = CKRecord.Reference(recordID: user.ckRecordID, action: .none)
        record["originalCreatedAt"] = palette.originalCreatedAt
        record["publishedAt"] = Date()
        record["likeCount"] = Int64(0)
        record["reportCount"] = Int64(0)
        record["isHidden"] = Int64(0)
        if let png = palette.previewImagePNG {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
            try? png.write(to: url)
            record["previewImageData"] = CKAsset(fileURL: url)
        }
        do {
            let savedPalette = try await database.save(record)
            var savedColors: [CommunityColor] = []
            for (index, color) in palette.colors.enumerated() {
                let colorRecord = Self.makeColorRecord(color, publisherName: publisherName, user: user)
                let savedColor = try await database.save(colorRecord)
                if let community = CommunityColor(record: savedColor) { savedColors.append(community) }
                let junction = CKRecord(recordType: CommunityPalette.junctionRecordType)
                junction["paletteRecordID"] = CKRecord.Reference(recordID: savedPalette.recordID, action: .deleteSelf)
                junction["colorRecordID"] = CKRecord.Reference(recordID: savedColor.recordID, action: .none)
                junction["sortOrder"] = Int64(index)
                _ = try await database.save(junction)
            }
            guard var community = CommunityPalette(record: savedPalette) else { throw OpaliteError.communityPublishFailed(reason: "Unreadable record") }
            community.colors = savedColors
            return community
        } catch let error as OpaliteError {
            throw error
        } catch {
            throw .communityPublishFailed(reason: error.localizedDescription)
        }
    }

    public func unpublishColor(id: CommunityRecordID) async throws(OpaliteError) {
        do {
            try await database.deleteRecord(withID: id.ckRecordID)
        } catch {
            throw .communityDeleteFailed(reason: error.localizedDescription)
        }
    }

    public func unpublishPalette(id: CommunityRecordID) async throws(OpaliteError) {
        let reference = CKRecord.Reference(recordID: id.ckRecordID, action: .none)
        let query = CKQuery(recordType: CommunityPalette.junctionRecordType, predicate: NSPredicate(format: "paletteRecordID == %@", reference))
        do {
            let (junctions, _) = try await database.records(matching: query, resultsLimit: 100)
            for (recordID, result) in junctions where (try? result.get()) != nil {
                try await database.deleteRecord(withID: recordID)
            }
            try await database.deleteRecord(withID: id.ckRecordID)
        } catch {
            throw .communityDeleteFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Reporting & moderation

    public func report(id: CommunityRecordID, type: CommunityItemType, reason: ReportReason, details: String?) async throws(OpaliteError) -> Int64 {
        guard let user = await currentUserRecordID() else { throw .communityNotSignedIn }
        let report = CKRecord(recordType: CommunityPalette.reportRecordType)
        report["reporterUserRecordID"] = CKRecord.Reference(recordID: user.ckRecordID, action: .none)
        report["targetRecordID"] = CKRecord.Reference(recordID: id.ckRecordID, action: .none)
        report["targetType"] = type.rawValue
        report["reason"] = reason.rawValue
        report["details"] = details
        report["status"] = "pending"
        report["createdAt"] = Date()
        do {
            _ = try await database.save(report)
            let target = try await database.record(for: id.ckRecordID)
            let count = (target["reportCount"] as? Int64 ?? 0) + 1
            target["reportCount"] = count
            if CommunityModeration.isHidden(afterReports: count) { target["isHidden"] = Int64(1) }
            _ = try await database.save(target)
            return count
        } catch {
            throw .communityReportFailed(reason: error.localizedDescription)
        }
    }

    public func fetchReportedColors() async throws(OpaliteError) -> [CommunityColor] {
        let query = CKQuery(recordType: CommunityColor.recordType, predicate: NSPredicate(format: "reportCount > 0"))
        query.sortDescriptors = [NSSortDescriptor(key: "reportCount", ascending: false)]
        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 100)
            return results.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return CommunityColor(record: record)
            }
        } catch {
            throw .communityFetchFailed(reason: error.localizedDescription)
        }
    }

    public func fetchReportedPalettes() async throws(OpaliteError) -> [CommunityPalette] {
        let query = CKQuery(recordType: CommunityPalette.recordType, predicate: NSPredicate(format: "reportCount > 0"))
        query.sortDescriptors = [NSSortDescriptor(key: "reportCount", ascending: false)]
        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 100)
            return results.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return CommunityPalette(record: record)
            }
        } catch {
            throw .communityFetchFailed(reason: error.localizedDescription)
        }
    }

    public func clearReports(id: CommunityRecordID) async throws(OpaliteError) {
        do {
            let record = try await database.record(for: id.ckRecordID)
            record["reportCount"] = Int64(0)
            record["isHidden"] = Int64(0)
            _ = try await database.save(record)
            let reference = CKRecord.Reference(recordID: id.ckRecordID, action: .none)
            let query = CKQuery(recordType: CommunityPalette.reportRecordType, predicate: NSPredicate(format: "targetRecordID == %@", reference))
            let (results, _) = try await database.records(matching: query, resultsLimit: 100)
            for (recordID, result) in results where (try? result.get()) != nil {
                try await database.deleteRecord(withID: recordID)
            }
        } catch {
            throw .communityDeleteFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func store(_ cursor: CKQueryOperation.Cursor?) -> CommunityCursor? {
        guard let cursor else { return nil }
        let token = UUID().uuidString
        cursors[token] = cursor
        return CommunityCursor(token: token)
    }

    private static func makeColorRecord(_ color: ColorPublication, publisherName: String, user: CommunityRecordID) -> CKRecord {
        let record = CKRecord(recordType: CommunityColor.recordType)
        record["originalColorID"] = color.originalColorID.uuidString
        record["name"] = color.name
        record["notes"] = color.notes
        record["red"] = color.rgba.red
        record["green"] = color.rgba.green
        record["blue"] = color.rgba.blue
        record["alpha"] = color.rgba.alpha
        record["hexString"] = color.rgba.hexString
        record["publisherName"] = publisherName
        record["publisherUserRecordID"] = CKRecord.Reference(recordID: user.ckRecordID, action: .none)
        record["createdOnDeviceName"] = color.createdOnDeviceName
        record["originalCreatedAt"] = color.originalCreatedAt
        record["publishedAt"] = Date()
        record["likeCount"] = Int64(0)
        record["reportCount"] = Int64(0)
        record["isHidden"] = Int64(0)
        return record
    }
}

// MARK: - Record mapping

extension CommunityRecordID {
    init(_ id: CKRecord.ID) { self.init(recordName: id.recordName) }
    var ckRecordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }
}

extension CommunityColor {
    /// Reads a `PublishedColor` record; nil for other record types.
    public init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        self.init(
            id: CommunityRecordID(record.recordID),
            originalColorID: UUID(uuidString: record["originalColorID"] as? String ?? "") ?? UUID(),
            name: record["name"] as? String,
            notes: record["notes"] as? String,
            red: record["red"] as? Double ?? 0,
            green: record["green"] as? Double ?? 0,
            blue: record["blue"] as? Double ?? 0,
            alpha: record["alpha"] as? Double ?? 1,
            hexString: record["hexString"] as? String,
            publisherName: record["publisherName"] as? String ?? "Unknown",
            publisherUserRecordID: (record["publisherUserRecordID"] as? CKRecord.Reference).map { CommunityRecordID($0.recordID) } ?? .unknown,
            createdOnDeviceName: record["createdOnDeviceName"] as? String,
            originalCreatedAt: record["originalCreatedAt"] as? Date ?? record.creationDate ?? Date(),
            publishedAt: record["publishedAt"] as? Date ?? record.creationDate ?? Date(),
            reportCount: record["reportCount"] as? Int64 ?? 0,
            isHidden: (record["isHidden"] as? Int64 ?? 0) != 0
        )
    }
}

extension CommunityPalette {
    /// Reads a `PublishedPalette` record (colors load separately); nil for other types.
    public init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        var previewData: Data?
        if let asset = record["previewImageData"] as? CKAsset, let url = asset.fileURL {
            previewData = try? Data(contentsOf: url)
        }
        self.init(
            id: CommunityRecordID(record.recordID),
            originalPaletteID: UUID(uuidString: record["originalPaletteID"] as? String ?? "") ?? UUID(),
            name: record["name"] as? String ?? "Untitled",
            notes: record["notes"] as? String,
            tags: record["tags"] as? [String] ?? [],
            colorCount: Int(record["colorCount"] as? Int64 ?? 0),
            previewImageData: previewData,
            publisherName: record["publisherName"] as? String ?? "Unknown",
            publisherUserRecordID: (record["publisherUserRecordID"] as? CKRecord.Reference).map { CommunityRecordID($0.recordID) } ?? .unknown,
            createdOnDeviceName: record["createdOnDeviceName"] as? String,
            originalCreatedAt: record["originalCreatedAt"] as? Date ?? record.creationDate ?? Date(),
            publishedAt: record["publishedAt"] as? Date ?? record.creationDate ?? Date(),
            reportCount: record["reportCount"] as? Int64 ?? 0,
            isHidden: (record["isHidden"] as? Int64 ?? 0) != 0
        )
    }
}

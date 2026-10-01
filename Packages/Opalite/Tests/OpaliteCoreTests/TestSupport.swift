//
//  TestSupport.swift
//  OpaliteCoreTests
//
//  In-memory fakes for the Core seams and repositories so use-cases, status sync, and
//  the deep-link hand-off are exercised without SwiftData, WidgetKit, or WatchConnectivity.
//

import Foundation
import Testing
@testable import OpaliteCore

// MARK: - Key-value store

final class FakeKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private var values: [String: Any] = [:]
    private let lock = NSLock()

    init() {}

    private func read<T>(_ key: String, as _: T.Type) -> T? {
        lock.lock(); defer { lock.unlock() }
        return values[key] as? T
    }

    func bool(forKey key: String) -> Bool { read(key, as: Bool.self) ?? false }
    func double(forKey key: String) -> Double { read(key, as: Double.self) ?? 0 }
    func integer(forKey key: String) -> Int { read(key, as: Int.self) ?? 0 }
    func string(forKey key: String) -> String? { read(key, as: String.self) }
    func data(forKey key: String) -> Data? { read(key, as: Data.self) }
    func object(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    func set(_ value: Any?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
    func removeObject(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: key)
    }

    var keys: [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(values.keys)
    }
}

// MARK: - Seams

final class RecordingDonor: IntentDonating {
    private(set) var donated: [DonatableAction] = []
    func donate(_ action: DonatableAction) { donated.append(action) }
}

final class FakeWidgetReloader: WidgetTimelineReloading {
    private(set) var reloadAllCount = 0
    private(set) var reloadedKinds: [String] = []
    func reloadTimelines(ofKind kind: String) { reloadedKinds.append(kind) }
    func reloadAllTimelines() { reloadAllCount += 1 }
}

final class FakeWatchPusher: WatchPortfolioPushing {
    private(set) var snapshots: [WatchPortfolioSnapshot] = []
    func push(_ snapshot: WatchPortfolioSnapshot) { snapshots.append(snapshot) }
}

final class FakeIndexer: PortfolioIndexing {
    private(set) var reindexCount = 0
    private(set) var lastColorCount = 0
    private(set) var lastPaletteCount = 0
    func reindex(colors: [OpaliteColor], palettes: [OpalitePalette]) {
        reindexCount += 1
        lastColorCount = colors.count
        lastPaletteCount = palettes.count
    }
}

final class FakeVocabulary: ShortcutVocabularyUpdating {
    private(set) var updateCount = 0
    func updateAppShortcutParameters() { updateCount += 1 }
}

// MARK: - Repositories

final class FakeColorRepository: ColorRepository {
    var storage: [OpaliteColor] = []
    var failure: PersistenceError?
    private let changeCenter: PortfolioChangeCenter

    init(changeCenter: PortfolioChangeCenter = PortfolioChangeCenter(), colors: [OpaliteColor] = []) {
        self.changeCenter = changeCenter
        self.storage = colors
    }

    private func failIfNeeded() throws(PersistenceError) {
        if let failure { throw failure }
    }

    func colors() throws(PersistenceError) -> [OpaliteColor] {
        try failIfNeeded()
        return storage.sorted { ($0.updatedAt, $0.createdAt) > ($1.updatedAt, $1.createdAt) }
    }

    func color(withID id: UUID) throws(PersistenceError) -> OpaliteColor? {
        try failIfNeeded()
        return storage.first { $0.id == id }
    }

    func count() throws(PersistenceError) -> Int {
        try failIfNeeded()
        return storage.count
    }

    func insert(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) {
        try failIfNeeded()
        if color.createdByDisplayName?.isEmpty ?? true { color.createdByDisplayName = authorship.displayName }
        if color.createdOnDeviceName == nil { color.createdOnDeviceName = authorship.deviceName }
        if let palette = color.palette {
            if palette.colors == nil { palette.colors = [] }
            if palette.colors?.contains(where: { $0.id == color.id }) == false { palette.colors?.append(color) }
        }
        storage.removeAll { $0.id == color.id }
        storage.append(color)
        changeCenter.notify(.colorCreated(color.id))
    }

    func update(_ color: OpaliteColor, authorship: Authorship, configure: (OpaliteColor) -> Void) throws(PersistenceError) {
        try failIfNeeded()
        configure(color)
        color.updatedAt = .now
        color.updatedOnDeviceName = authorship.deviceName
        changeCenter.notify(.colorUpdated(color.id))
    }

    func delete(_ color: OpaliteColor) throws(PersistenceError) {
        try failIfNeeded()
        color.palette?.colors?.removeAll { $0.id == color.id }
        storage.removeAll { $0.id == color.id }
        changeCenter.notify(.colorDeleted(color.id))
    }

    func attach(_ color: OpaliteColor, to palette: OpalitePalette, authorship: Authorship) throws(PersistenceError) {
        try failIfNeeded()
        color.palette?.colors?.removeAll { $0.id == color.id }
        color.palette = palette
        if palette.colors == nil { palette.colors = [] }
        palette.colors?.removeAll { $0.id == color.id }
        palette.colors?.append(color)
        color.updatedAt = .now
        palette.updatedAt = .now
        changeCenter.notify(.colorUpdated(color.id))
    }

    func detach(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) {
        try failIfNeeded()
        guard let palette = color.palette else { return }
        palette.colors?.removeAll { $0.id == color.id }
        color.palette = nil
        color.updatedAt = .now
        changeCenter.notify(.colorUpdated(color.id))
    }
}

final class FakePaletteRepository: PaletteRepository {
    var storage: [OpalitePalette] = []
    var failure: PersistenceError?
    private let changeCenter: PortfolioChangeCenter

    init(changeCenter: PortfolioChangeCenter = PortfolioChangeCenter(), palettes: [OpalitePalette] = []) {
        self.changeCenter = changeCenter
        self.storage = palettes
    }

    private func failIfNeeded() throws(PersistenceError) {
        if let failure { throw failure }
    }

    func palettes() throws(PersistenceError) -> [OpalitePalette] {
        try failIfNeeded()
        return storage.sorted { $0.createdAt > $1.createdAt }
    }

    func palette(withID id: UUID) throws(PersistenceError) -> OpalitePalette? {
        try failIfNeeded()
        return storage.first { $0.id == id }
    }

    func count() throws(PersistenceError) -> Int {
        try failIfNeeded()
        return storage.count
    }

    func insert(_ palette: OpalitePalette, authorship: Authorship) throws(PersistenceError) {
        try failIfNeeded()
        if palette.createdByDisplayName?.isEmpty ?? true { palette.createdByDisplayName = authorship.displayName }
        storage.removeAll { $0.id == palette.id }
        storage.append(palette)
        for color in palette.colors ?? [] { color.palette = palette }
        changeCenter.notify(.paletteCreated(palette.id))
    }

    func update(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) throws(PersistenceError) {
        try failIfNeeded()
        configure(palette)
        palette.updatedAt = .now
        changeCenter.notify(.paletteUpdated(palette.id))
    }

    func delete(_ palette: OpalitePalette, deleteColors: Bool) throws(PersistenceError) {
        try failIfNeeded()
        for color in palette.colors ?? [] where !deleteColors { color.palette = nil }
        palette.canvasFile?.palette = nil
        storage.removeAll { $0.id == palette.id }
        changeCenter.notify(.paletteDeleted(palette.id))
    }

    func attach(_ canvas: CanvasFile, to palette: OpalitePalette) throws(PersistenceError) {
        try failIfNeeded()
        canvas.palette?.canvasFile = nil
        palette.canvasFile?.palette = nil
        palette.canvasFile = canvas
        canvas.palette = palette
        changeCenter.notify(.paletteUpdated(palette.id))
    }

    func detachCanvas(from palette: OpalitePalette) throws(PersistenceError) {
        try failIfNeeded()
        palette.canvasFile?.palette = nil
        palette.canvasFile = nil
        changeCenter.notify(.paletteUpdated(palette.id))
    }
}

final class FakeCanvasRepository: CanvasRepository {
    var storage: [CanvasFile] = []
    var failure: PersistenceError?
    private let changeCenter: PortfolioChangeCenter

    init(changeCenter: PortfolioChangeCenter = PortfolioChangeCenter(), canvases: [CanvasFile] = []) {
        self.changeCenter = changeCenter
        self.storage = canvases
    }

    private func failIfNeeded() throws(PersistenceError) {
        if let failure { throw failure }
    }

    func canvases() throws(PersistenceError) -> [CanvasFile] {
        try failIfNeeded()
        return storage.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func canvas(withID id: UUID) throws(PersistenceError) -> CanvasFile? {
        try failIfNeeded()
        return storage.first { $0.id == id }
    }

    func count() throws(PersistenceError) -> Int {
        try failIfNeeded()
        return storage.count
    }

    func insert(_ canvas: CanvasFile, deviceName: String?) throws(PersistenceError) {
        try failIfNeeded()
        canvas.lastEditedDeviceName = deviceName
        storage.append(canvas)
        changeCenter.notify(.canvasCreated(canvas.id))
    }

    func update(_ canvas: CanvasFile, deviceName: String?, configure: (CanvasFile) -> Void) throws(PersistenceError) {
        try failIfNeeded()
        configure(canvas)
        canvas.updatedAt = .now
        changeCenter.notify(.canvasUpdated(canvas.id))
    }

    func delete(_ canvas: CanvasFile) throws(PersistenceError) {
        try failIfNeeded()
        canvas.palette?.canvasFile = nil
        storage.removeAll { $0.id == canvas.id }
        changeCenter.notify(.canvasDeleted(canvas.id))
    }
}

// MARK: - Helpers

extension Double {
    /// Approximate equality for color math.
    func isClose(to other: Double, tolerance: Double = 0.001) -> Bool {
        abs(self - other) <= tolerance
    }
}

extension RGBA {
    func isClose(to other: RGBA, tolerance: Double = 0.001) -> Bool {
        red.isClose(to: other.red, tolerance: tolerance)
            && green.isClose(to: other.green, tolerance: tolerance)
            && blue.isClose(to: other.blue, tolerance: tolerance)
            && alpha.isClose(to: other.alpha, tolerance: tolerance)
    }
}

/// Polls a main-actor condition until it holds or the timeout elapses.
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

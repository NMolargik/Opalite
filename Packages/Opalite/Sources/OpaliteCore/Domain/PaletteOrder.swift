//
//  PaletteOrder.swift
//  OpaliteCore
//
//  The user's manual palette order, persisted as JSON `[UUID]` in UserDefaults. New
//  palettes go to the front; unknown ids are dropped; palettes missing from the stored
//  order sort after it by creation date.
//

import Foundation

nonisolated public struct PaletteOrder: Equatable, Sendable {
    public private(set) var ids: [UUID]

    public init(ids: [UUID] = []) { self.ids = ids }

    // MARK: - Persistence

    public static func decode(_ data: Data) -> PaletteOrder {
        guard !data.isEmpty, let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return PaletteOrder() }
        return PaletteOrder(ids: ids)
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(ids)) ?? Data()
    }

    public static func load(from defaults: any KeyValueStoring) -> PaletteOrder {
        decode(defaults.data(forKey: AppStorageKeys.paletteOrder) ?? Data())
    }

    public func save(to defaults: any KeyValueStoring) {
        defaults.set(encoded(), forKey: AppStorageKeys.paletteOrder)
    }

    // MARK: - Mutation

    /// Moves (or inserts) `id` to the front.
    public mutating func prepend(_ id: UUID) {
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
    }

    public mutating func remove(_ id: UUID) {
        ids.removeAll { $0 == id }
    }

    /// Replaces the order wholesale (drag-to-reorder result).
    public mutating func replace(with newIDs: [UUID]) {
        ids = newIDs.uniqued()
    }

    /// Moves the items at `source` before `destination`, with `List.onMove` semantics.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        let moving = source.sorted().map { ids[$0] }
        var remaining = ids
        for index in source.sorted(by: >) { remaining.remove(at: index) }
        let removedBefore = source.filter { $0 < destination }.count
        let insertAt = max(0, min(remaining.count, destination - removedBefore))
        remaining.insert(contentsOf: moving, at: insertAt)
        ids = remaining
    }

    // MARK: - Application

    /// Sorts `palettes` by this order, appending any not in the order newest-first.
    public func apply(to palettes: [OpalitePalette]) -> [OpalitePalette] {
        let position = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let ordered = palettes.filter { position[$0.id] != nil }.sorted { position[$0.id]! < position[$1.id]! }
        let rest = palettes.filter { position[$0.id] == nil }.sorted { $0.createdAt > $1.createdAt }
        return ordered + rest
    }

    /// The order reconciled against the palettes that actually exist (drops stale ids,
    /// appends new ones at the end so the stored order is complete).
    public func reconciled(with palettes: [OpalitePalette]) -> PaletteOrder {
        PaletteOrder(ids: apply(to: palettes).map(\.id))
    }
}

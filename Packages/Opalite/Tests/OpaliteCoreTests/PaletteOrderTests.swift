//
//  PaletteOrderTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("PaletteOrder")
struct PaletteOrderTests {
    let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    @Test func prependInsertsAtFrontAndDeduplicates() {
        var order = PaletteOrder(ids: [a, b])
        order.prepend(c)
        #expect(order.ids == [c, a, b])
        order.prepend(b)
        #expect(order.ids == [b, c, a])
        order.prepend(b)
        #expect(order.ids == [b, c, a])
    }

    @Test func removeDropsTheID() {
        var order = PaletteOrder(ids: [a, b, c])
        order.remove(b)
        #expect(order.ids == [a, c])
        order.remove(UUID())
        #expect(order.ids == [a, c])
    }

    @Test func replaceDeduplicatesKeepingFirstOccurrence() {
        var order = PaletteOrder(ids: [a])
        order.replace(with: [c, b, c, a, b])
        #expect(order.ids == [c, b, a])
    }

    @Test func moveForwardFollowsListOnMoveSemantics() {
        var order = PaletteOrder(ids: [a, b, c, d])
        order.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(order.ids == [b, a, c, d])
    }

    @Test func moveToEnd() {
        var order = PaletteOrder(ids: [a, b, c, d])
        order.move(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        #expect(order.ids == [b, c, d, a])
    }

    @Test func moveBackward() {
        var order = PaletteOrder(ids: [a, b, c, d])
        order.move(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(order.ids == [d, a, b, c])
    }

    @Test func moveMultipleContiguousItems() {
        var order = PaletteOrder(ids: [a, b, c, d])
        order.move(fromOffsets: IndexSet([0, 1]), toOffset: 4)
        #expect(order.ids == [c, d, a, b])
    }

    @Test func moveMultipleNonContiguousItems() {
        var order = PaletteOrder(ids: [a, b, c, d])
        order.move(fromOffsets: IndexSet([0, 2]), toOffset: 4)
        #expect(order.ids == [b, d, a, c])
    }

    @Test func moveToSamePositionIsNoOp() {
        var order = PaletteOrder(ids: [a, b, c, d])
        order.move(fromOffsets: IndexSet(integer: 1), toOffset: 1)
        #expect(order.ids == [a, b, c, d])
        order.move(fromOffsets: IndexSet(integer: 1), toOffset: 2)
        #expect(order.ids == [a, b, c, d])
    }

    @Test func moveWithEmptySetIsNoOp() {
        var order = PaletteOrder(ids: [a, b])
        order.move(fromOffsets: IndexSet(), toOffset: 1)
        #expect(order.ids == [a, b])
    }

    @Test func applySortsByOrderThenNewestFirst() {
        let now = Date()
        let p1 = OpalitePalette(id: a, name: "A", createdAt: now.addingTimeInterval(-300))
        let p2 = OpalitePalette(id: b, name: "B", createdAt: now.addingTimeInterval(-200))
        let p3 = OpalitePalette(id: c, name: "C", createdAt: now.addingTimeInterval(-100))
        let p4 = OpalitePalette(id: d, name: "D", createdAt: now)
        let order = PaletteOrder(ids: [b, UUID(), a])
        let applied = order.apply(to: [p1, p2, p3, p4])
        #expect(applied.map(\.id) == [b, a, d, c], "ordered first, then unordered newest-first")
    }

    @Test func applyWithEmptyOrderIsNewestFirst() {
        let now = Date()
        let old = OpalitePalette(id: a, name: "Old", createdAt: now.addingTimeInterval(-10))
        let new = OpalitePalette(id: b, name: "New", createdAt: now)
        #expect(PaletteOrder().apply(to: [old, new]).map(\.id) == [b, a])
    }

    @Test func reconciledDropsStaleAndAppendsNew() {
        let now = Date()
        let p1 = OpalitePalette(id: a, name: "A", createdAt: now.addingTimeInterval(-10))
        let p2 = OpalitePalette(id: b, name: "B", createdAt: now)
        let order = PaletteOrder(ids: [c, a])
        let reconciled = order.reconciled(with: [p1, p2])
        #expect(reconciled.ids == [a, b])
        #expect(order.reconciled(with: []).ids.isEmpty)
    }

    @Test func encodeDecodeRoundTrip() {
        let order = PaletteOrder(ids: [a, b, c])
        #expect(PaletteOrder.decode(order.encoded()) == order)
    }

    @Test func decodeToleratesGarbage() {
        #expect(PaletteOrder.decode(Data()) == PaletteOrder())
        #expect(PaletteOrder.decode(Data("not json".utf8)) == PaletteOrder())
        #expect(PaletteOrder.decode(Data("[\"nope\"]".utf8)) == PaletteOrder())
    }

    @Test func persistsThroughAKeyValueStore() {
        let store = FakeKeyValueStore()
        #expect(PaletteOrder.load(from: store) == PaletteOrder())
        let order = PaletteOrder(ids: [b, a])
        order.save(to: store)
        #expect(store.data(forKey: AppStorageKeys.paletteOrder) != nil)
        #expect(PaletteOrder.load(from: store) == order)
    }
}

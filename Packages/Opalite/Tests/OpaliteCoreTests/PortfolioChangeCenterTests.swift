//
//  PortfolioChangeCenterTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("PortfolioChange")
struct PortfolioChangeTests {
    @Test func canvasChangesDoNotAffectThePortfolio() {
        let id = UUID()
        for change in [PortfolioChange.canvasCreated(id), .canvasUpdated(id), .canvasDeleted(id)] {
            #expect(!change.affectsPortfolio)
            #expect(change.affectsCanvases)
        }
    }

    @Test func colorAndPaletteChangesAffectOnlyThePortfolio() {
        let id = UUID()
        for change in [PortfolioChange.colorCreated(id), .colorUpdated(id), .colorDeleted(id), .paletteCreated(id), .paletteUpdated(id), .paletteDeleted(id)] {
            #expect(change.affectsPortfolio)
            #expect(!change.affectsCanvases)
        }
    }

    @Test func bulkAffectsEverything() {
        #expect(PortfolioChange.bulk.affectsPortfolio && PortfolioChange.bulk.affectsCanvases)
    }
}

@Suite("PortfolioChangeCenter")
struct PortfolioChangeCenterTests {
    @Test func multicastsToEverySubscriber() async {
        let center = PortfolioChangeCenter()
        let first = center.changes()
        let second = center.changes()
        #expect(center.subscriberCount == 2)

        let id = UUID()
        center.notify(.colorCreated(id))
        center.notify(.bulk)

        var firstIterator = first.makeAsyncIterator()
        var secondIterator = second.makeAsyncIterator()
        #expect(await firstIterator.next() == .colorCreated(id))
        #expect(await firstIterator.next() == .bulk)
        #expect(await secondIterator.next() == .colorCreated(id))
        #expect(await secondIterator.next() == .bulk)
    }

    @Test func notifyingWithoutSubscribersIsHarmless() {
        let center = PortfolioChangeCenter()
        center.notify(.bulk)
        #expect(center.subscriberCount == 0)
    }

    @Test func terminationRemovesTheSubscriber() async {
        let center = PortfolioChangeCenter()
        let stream = center.changes()
        #expect(center.subscriberCount == 1)

        let consumer = Task { @MainActor in
            for await _ in stream {}
        }
        await Task.yield()
        consumer.cancel()
        await consumer.value
        #expect(await waitUntil { center.subscriberCount == 0 })
    }

    @Test func droppingAStreamRemovesTheSubscriber() async {
        let center = PortfolioChangeCenter()
        do {
            _ = center.changes()
        }
        #expect(await waitUntil { center.subscriberCount == 0 })
    }

    @Test func lateSubscribersOnlySeeLaterChanges() async {
        let center = PortfolioChangeCenter()
        center.notify(.bulk)
        let stream = center.changes()
        let id = UUID()
        center.notify(.paletteDeleted(id))
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == .paletteDeleted(id))
    }

    @Test func useCaseWrapsTheCenter() async {
        let center = PortfolioChangeCenter()
        let observe = ObservePortfolioChangesUseCase(center: center)
        let stream = observe()
        #expect(center.subscriberCount == 1)
        center.notify(.colorDeleted(UUID()))
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.affectsPortfolio == true)
    }
}

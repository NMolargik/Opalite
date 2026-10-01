//
//  OpaliteErrorTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("OpaliteError")
struct OpaliteErrorTests {
    nonisolated static let everyError: [OpaliteError] = [
        .importFailed(reason: "r"), .exportFailed(reason: "r"), .pdfExportFailed,
        .subscriptionLoadFailed, .subscriptionPurchaseFailed, .subscriptionRestoreFailed, .subscriptionVerificationFailed,
        .communityFetchFailed(reason: "r"), .communityPublishFailed(reason: "r"), .communityDeleteFailed(reason: "r"), .communityReportFailed(reason: "r"),
        .communityRateLimited, .communityRequiresOnyx, .communityColorAlreadyExists, .communityPaletteAlreadyExists, .communityNotSignedIn, .communityOffline,
        .paletteLimitReached, .canvasLimitReached, .unknown("custom"),
    ]

    @Test("Every error has a description and a symbol", arguments: everyError)
    func descriptionsAndSymbols(error: OpaliteError) {
        #expect(!(error.errorDescription ?? "").isEmpty)
        #expect(!error.systemImage.isEmpty)
        #expect(error.localizedDescription == error.errorDescription)
    }

    @Test func reasonsAreInterpolated() {
        #expect(OpaliteError.importFailed(reason: "bad bytes").errorDescription?.contains("bad bytes") == true)
        #expect(OpaliteError.communityPublishFailed(reason: "quota").errorDescription?.contains("quota") == true)
        #expect(OpaliteError.unknown("custom").errorDescription == "custom")
    }

    @Test func onlyLimitErrorsRequireOnyx() {
        let requiring = Self.everyError.filter(\.requiresOnyx)
        #expect(requiring.count == 3)
        #expect(requiring.contains(.communityRequiresOnyx) && requiring.contains(.paletteLimitReached) && requiring.contains(.canvasLimitReached))
        #expect(requiring.allSatisfy { $0.systemImage == "lock.fill" })
    }

    @Test func equalityHonorsAssociatedValues() {
        #expect(OpaliteError.importFailed(reason: "a") == .importFailed(reason: "a"))
        #expect(OpaliteError.importFailed(reason: "a") != .importFailed(reason: "b"))
        #expect(OpaliteError.importFailed(reason: "a") != .exportFailed(reason: "a"))
        #expect(OpaliteError.unknown("x") == .unknown("x"))
    }

    @Test func symbolFamilies() {
        #expect(OpaliteError.subscriptionLoadFailed.systemImage == "creditcard.fill")
        #expect(OpaliteError.communityOffline.systemImage == "icloud.slash.fill")
        #expect(OpaliteError.communityColorAlreadyExists.systemImage == "doc.on.doc.fill")
        #expect(OpaliteError.communityRateLimited.systemImage == "clock.fill")
    }

    @Test func persistenceErrors() {
        for error in [PersistenceError.fetchFailed("x"), .saveFailed("y"), .notFound] {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
        #expect(PersistenceError.fetchFailed("x") == .fetchFailed("x"))
        #expect(PersistenceError.fetchFailed("x") != .saveFailed("x"))
    }
}

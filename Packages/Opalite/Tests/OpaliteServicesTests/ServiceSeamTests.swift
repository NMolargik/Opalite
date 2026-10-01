//
//  ServiceSeamTests.swift
//  OpaliteServicesTests
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteServices

@Suite("ColorNameSuggestionService")
struct ColorNameSuggestionServiceTests {
    @Test func conformsToTheNamingSeam() {
        let service: any ColorNaming = ColorNameSuggestionService()
        _ = service.isAvailable
    }

    @Test func unavailableModelReturnsNoNames() async throws {
        let service = ColorNameSuggestionService()
        guard !service.isAvailable else { return }
        let names = try await service.suggestNames(for: RGBA(red: 0.2, green: 0.5, blue: 0.8), count: 3)
        #expect(names.isEmpty)
    }

    @Test func defaultCountMatchesThePrompt() {
        #expect(ColorNamePrompt.defaultCount == 5)
    }
}

@Suite("System seams")
struct SystemSeamTests {
    @Test func deviceInfoDescribesTheHost() {
        let device: any DeviceDescribing = DeviceInfo()
        #expect(!device.deviceName.isEmpty)
    }

    @Test func pasteboardAndWidgetReloaderConformToTheSeams() {
        let pasteboard: any Pasteboarding = SystemPasteboard()
        _ = pasteboard
        let reloader: any WidgetTimelineReloading = WidgetCenterReloader()
        _ = reloader
    }

    @Test func subscriptionManagerStartsWithoutEntitlements() {
        let manager = SubscriptionManager()
        #expect(!manager.hasOnyx)
        #expect(manager.currentSubscription == nil)
        #expect(manager.annualProduct == nil && manager.lifetimeProduct == nil)
        let entitlement: any EntitlementProviding = manager
        #expect(!entitlement.hasOnyx)
    }
}

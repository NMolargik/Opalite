//
//  OnyxSubscription.swift
//  OpaliteCore
//
//  The Onyx products and the free-tier limits they lift.
//

import Foundation

nonisolated public enum OnyxSubscription: String, CaseIterable, Identifiable, Sendable {
    case annual = "onyx_1yr_4.99"
    case lifetime = "onyx_lifetime_20"

    public var id: String { rawValue }

    /// Whether this is an auto-renewing subscription (vs a one-time purchase).
    public var isSubscription: Bool { self == .annual }

    /// Whether the plan is still sold. The annual subscription is legacy: existing
    /// subscribers keep Onyx, but it is no longer offered or shown anywhere.
    public var isPurchasable: Bool { self == .lifetime }

    /// The plans the paywall may offer.
    public static var purchasable: [OnyxSubscription] { allCases.filter(\.isPurchasable) }

    /// Every product ID that grants Onyx — entitlement checks include legacy plans.
    public static var productIDs: Set<String> { Set(allCases.map(\.rawValue)) }

    /// The product IDs the store loads for sale.
    public static var purchasableProductIDs: Set<String> { Set(purchasable.map(\.rawValue)) }
}

/// The free tier's limits and the gates Onyx unlocks. Pure, so the paywall rules are tested.
nonisolated public struct OnyxGate: Sendable, Equatable {
    public static let freePaletteLimit = 5
    public static let freeCanvasLimit = 1

    public let hasOnyx: Bool

    public init(hasOnyx: Bool) { self.hasOnyx = hasOnyx }

    public func canCreatePalette(currentCount: Int) -> Bool {
        hasOnyx || currentCount < Self.freePaletteLimit
    }

    public func canCreateCanvas(currentCount: Int) -> Bool {
        hasOnyx || currentCount < Self.freeCanvasLimit
    }

    /// Free users may open only the oldest canvas.
    public func canAccessCanvas(id: UUID, oldestCanvasID: UUID?) -> Bool {
        hasOnyx || id == oldestCanvasID
    }

    public var canSaveFromCommunity: Bool { hasOnyx }
    public var canExportProFormats: Bool { hasOnyx }
}

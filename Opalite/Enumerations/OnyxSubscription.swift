//
//  OnyxSubscription.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import Foundation

/// Defines the Onyx products available for purchase.
enum OnyxSubscription: String, CaseIterable, Identifiable {
    case annual = "onyx_1yr_4.99"
    case lifetime = "onyx_lifetime_20"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .annual: return "Onyx Annual"
        case .lifetime: return "Onyx Lifetime"
        }
    }

    var priceDescription: String {
        switch self {
        case .annual: return "per year"
        case .lifetime: return "one-time purchase"
        }
    }

    /// Whether this is a subscription (auto-renewing) or one-time purchase
    var isSubscription: Bool {
        switch self {
        case .annual: return true
        case .lifetime: return false
        }
    }

    /// Set of all product IDs for StoreKit queries
    static var productIDs: Set<String> {
        Set(allCases.map(\.rawValue))
    }
}

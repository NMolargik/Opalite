//
//  OnyxSubscription.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import StoreKit

/// Defines the Onyx subscription products available for purchase.
enum OnyxSubscription: String, CaseIterable, Identifiable {
    case monthly = "onyx_1m_0.99"
    case annual = "onyx_1yr_4.99"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Onyx Monthly"
        case .annual: return "Onyx Annual"
        }
    }

    var period: String {
        switch self {
        case .monthly: return "month"
        case .annual: return "year"
        }
    }

    /// Percentage savings compared to monthly (annual only)
    var savingsPercentage: Int? {
        switch self {
        case .monthly: return nil
        case .annual: return 58  // ($0.99 * 12 = $11.88) vs $4.99 = ~58% savings
        }
    }

    /// Set of all product IDs for StoreKit queries
    static var productIDs: Set<String> {
        Set(allCases.map(\.rawValue))
    }
}

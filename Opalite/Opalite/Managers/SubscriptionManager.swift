//
//  SubscriptionManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import StoreKit
import SwiftUI

/// Manages Onyx subscription state and StoreKit 2 purchases.
@MainActor
@Observable
final class SubscriptionManager {
    // MARK: - Published State
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading: Bool = false
    private(set) var error: OpaliteError?

    // MARK: - Private
    @ObservationIgnored
    private var transactionListener: Task<Void, Error>?

    // MARK: - Computed Properties

    /// Whether the user has an active Onyx entitlement (annual subscription or lifetime purchase).
    var hasOnyxEntitlement: Bool {
        !purchasedProductIDs.intersection(OnyxSubscription.productIDs).isEmpty
    }

    /// The current active subscription type, if any.
    var currentSubscription: OnyxSubscription? {
        for id in purchasedProductIDs {
            if let sub = OnyxSubscription(rawValue: id) {
                return sub
            }
        }
        return nil
    }

    /// The annual subscription product, if loaded.
    var annualProduct: Product? {
        products.first { $0.id == OnyxSubscription.annual.rawValue }
    }

    /// The lifetime purchase product, if loaded.
    var lifetimeProduct: Product? {
        products.first { $0.id == OnyxSubscription.lifetime.rawValue }
    }

    // MARK: - Initialization

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    /// Loads available subscription products from the App Store.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: OnyxSubscription.productIDs)
            // Sort by price (annual first, then lifetime)
            products = storeProducts.sorted { $0.price < $1.price }
            error = nil
        } catch {
            self.error = .subscriptionLoadFailed
        }
    }

    /// Purchases the specified product.
    /// - Returns: `true` if the purchase succeeded, `false` if cancelled or pending.
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            // Transaction requires approval (e.g., Ask to Buy)
            return false

        @unknown default:
            return false
        }
    }

    /// Restores previously purchased subscriptions.
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            error = nil
        } catch {
            self.error = .subscriptionRestoreFailed
        }
    }

    /// Checks if the user can create a new palette based on their subscription status.
    /// Free users are limited to 5 palettes.
    func canCreatePalette(currentCount: Int) -> Bool {
        hasOnyxEntitlement || currentCount < 5
    }

    /// Updates the set of purchased product IDs by checking current entitlements.
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // Only count if not revoked
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                // Skip unverified transactions
            }
        }

        purchasedProductIDs = purchased
    }

    // MARK: - Private Helpers

    /// Listens for transaction updates (renewals, revocations, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)
                    await self?.updatePurchasedProducts()
                    await transaction?.finish()
                } catch {
                    // Transaction verification failed, skip
                }
            }
        }
    }

    /// Verifies a StoreKit transaction result.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw OpaliteError.subscriptionVerificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

//
//  SubscriptionManager.swift
//  OpaliteServices
//
//  Onyx entitlement state and StoreKit 2 purchases. Conforms to `EntitlementProviding`
//  so use-cases gate on it without knowing StoreKit.
//

import Foundation
import Observation
import StoreKit
import OpaliteCore
import os
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class SubscriptionManager: EntitlementProviding {
    public private(set) var products: [Product] = []
    public private(set) var purchasedProductIDs: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var error: OpaliteError?

    @ObservationIgnored private var transactionListener: Task<Void, Never>?

    /// Whether the user has Onyx (annual subscription or lifetime purchase).
    public var hasOnyx: Bool { !purchasedProductIDs.intersection(OnyxSubscription.productIDs).isEmpty }

    public var currentSubscription: OnyxSubscription? {
        purchasedProductIDs.lazy.compactMap(OnyxSubscription.init(rawValue:)).first
    }

    public var annualProduct: Product? { products.first { $0.id == OnyxSubscription.annual.rawValue } }
    public var lifetimeProduct: Product? { products.first { $0.id == OnyxSubscription.lifetime.rawValue } }

    public init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await processUnfinishedTransactions()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: OnyxSubscription.productIDs).sorted { $0.price < $1.price }
            error = nil
        } catch {
            Log.subscription.error("Product load failed: \(error.localizedDescription)")
            self.error = .subscriptionLoadFailed
        }
    }

    /// Purchases a product. Returns true on success, false when cancelled or pending.
    public func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        #if os(visionOS)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            throw OpaliteError.subscriptionPurchaseFailed
        }
        let result = try await product.purchase(confirmIn: scene, options: [])
        #else
        let result = try await product.purchase()
        #endif

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    public func restorePurchases() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            self.error = .subscriptionRestoreFailed
        }
    }

    public func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    /// Finishes pending transactions so a lifetime purchase never stays invisible.
    public func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self?.updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw OpaliteError.subscriptionVerificationFailed
        case .verified(let safe): return safe
        }
    }
}

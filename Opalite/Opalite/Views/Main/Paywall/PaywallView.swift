//
//  PaywallView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import SwiftUI
import StoreKit

/// A polished paywall view for Onyx subscription purchases.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(ToastManager.self) private var toastManager

    @State private var selectedProduct: Product?
    @State private var isPurchasing: Bool = false

    /// Optional context explaining why the paywall was shown.
    let featureContext: String?

    init(featureContext: String? = nil) {
        self.featureContext = featureContext
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    featuresSection

                    productsSection

                    purchaseButton

                    restoreButton

                    legalSection
                }
                .padding()
            }
            .navigationTitle("Onyx")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Default to annual (best value)
            if let annual = subscriptionManager.annualProduct {
                selectedProduct = annual
            } else if let monthly = subscriptionManager.monthlyProduct {
                selectedProduct = monthly
            }
        }
        .onChange(of: subscriptionManager.hasOnyxEntitlement) { _, hasEntitlement in
            if hasEntitlement {
                dismiss()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("onyxgem")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150)
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .accessibilityHidden(true)

            Text("Unlock Onyx")
                .font(.largeTitle)
                .bold()
                .accessibilityAddTraits(.isHeader)

            if let context = featureContext {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.red)
                    )
            } else {
                Text("Unlock the full power of Opalite")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top)
    }

    @ViewBuilder
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "swatchpalette.fill", text: "Unlimited Palettes")
            FeatureRow(icon: "scribble", text: "Unlimited Canvas Access")
            FeatureRow(icon: "square.and.arrow.up", text: "Export Colors and Palettes to Data Files")
            FeatureRow(icon: "square.and.arrow.down", text: "Import Colors & Palettes from Files")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.fill.tertiary)
        )
    }

    @ViewBuilder
    private var productsSection: some View {
        if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
            ProgressView()
                .padding()
        } else if subscriptionManager.products.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Unable to load products")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await subscriptionManager.loadProducts()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else {
            VStack(spacing: 12) {
                if let annual = subscriptionManager.annualProduct {
                    ProductOptionView(
                        product: annual,
                        subscription: .annual,
                        isSelected: selectedProduct?.id == annual.id
                    ) {
                        selectedProduct = annual
                    }
                }

                if let monthly = subscriptionManager.monthlyProduct {
                    ProductOptionView(
                        product: monthly,
                        subscription: .monthly,
                        isSelected: selectedProduct?.id == monthly.id
                    ) {
                        selectedProduct = monthly
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedProduct == nil ? Color.gray : Color.blue)
            )
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .accessibilityLabel(isPurchasing ? "Subscribing" : "Subscribe")
        .accessibilityHint(selectedProduct != nil ? "Subscribes to \(selectedProduct?.displayName ?? "Onyx")" : "Select a subscription plan first")
    }

    @ViewBuilder
    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.hasOnyxEntitlement {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
        }
        .disabled(subscriptionManager.isLoading)
        .accessibilityHint("Restores previously purchased subscriptions")
    }

    @ViewBuilder
    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link("Privacy Policy", destination: URL(string: "https://molargiksoftware.com/#/privacy")!)
                .font(.caption)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let success = try await subscriptionManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            toastManager.show(error: .subscriptionPurchaseFailed)
        }
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.inverseTheme)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.inverseTheme)

            Spacer()

            Image(systemName: "checkmark")
                .foregroundStyle(.inverseTheme)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

private struct ProductOptionView: View {
    let product: Product
    let subscription: OnyxSubscription
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(subscription.displayName)
                            .font(.headline)

                        if let savings = subscription.savingsPercentage {
                            Text("Save \(savings)%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.blue))
                                .foregroundStyle(.white)
                        }
                    }

                    Text("\(product.displayPrice) / \(subscription.period)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.displayName), \(product.displayPrice) per \(subscription.period)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    PaywallView(featureContext: "Canvas access requires Onyx")
        .environment(SubscriptionManager())
        .environment(ToastManager())
}

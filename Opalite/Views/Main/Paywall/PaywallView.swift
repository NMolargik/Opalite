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

    // MARK: - Onyx Palette
    private let onyxBlack = Color(red: 0.06, green: 0.06, blue: 0.08)
    private let onyxSlate = Color(red: 0.14, green: 0.14, blue: 0.18)
    private let onyxCharcoal = Color(red: 0.22, green: 0.22, blue: 0.26)
    private let onyxSilver = Color(red: 0.72, green: 0.72, blue: 0.78)
    private let onyxAccent = Color(red: 0.38, green: 0.34, blue: 0.50)

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
            .scrollContentBackground(.hidden)
            .background {
                LinearGradient(
                    colors: [onyxBlack, onyxSlate, onyxBlack],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Onyx")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(onyxBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(onyxSilver)
                }
            }
        }
        .onAppear {
            // Default to annual subscription
            if let annual = subscriptionManager.annualProduct {
                selectedProduct = annual
            } else if let lifetime = subscriptionManager.lifetimeProduct {
                selectedProduct = lifetime
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
            ZStack {
                Image("onyxgem")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150)
                    .blur(radius: 24)
                    .opacity(0.5)

                Image("onyxgem")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150)
                    .shadow(color: onyxAccent.opacity(0.6), radius: 14)
            }
            .accessibilityHidden(true)

            Text("Unlock Onyx")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .accessibilityAddTraits(.isHeader)

            if let context = featureContext {
                Text(context)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(onyxSilver)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(onyxSlate)
                            .overlay(Capsule().stroke(onyxAccent.opacity(0.5), lineWidth: 0.75))
                    )
            } else {
                Text("Unlock the full power of Opalite")
                    .font(.subheadline)
                    .foregroundStyle(onyxSilver)
            }
        }
        .padding(.top)
    }

    @ViewBuilder
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "swatchpalette.fill", text: "Unlimited Palettes", tint: onyxSilver)
            FeatureRow(icon: "scribble", text: "Unlimited Canvas Access", tint: onyxSilver)
            FeatureRow(icon: "person.2", text: "Save From The Community", tint: onyxSilver)
            FeatureRow(icon: "square.and.arrow.up", text: "Share Colors and Palettes to Data Files", tint: onyxSilver)
            FeatureRow(icon: "square.and.arrow.down", text: "Import Colors & Palettes from Files", tint: onyxSilver)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(onyxSlate)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(onyxCharcoal, lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.45), radius: 10, y: 3)
        )
    }

    @ViewBuilder
    private var productsSection: some View {
        if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
            ProgressView()
                .tint(onyxSilver)
                .padding()
        } else if subscriptionManager.products.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(onyxSilver)
                Text("Unable to load products")
                    .font(.subheadline)
                    .foregroundStyle(onyxSilver)
                Button("Retry") {
                    Task {
                        await subscriptionManager.loadProducts()
                    }
                }
                .buttonStyle(.bordered)
                .tint(onyxAccent)
            }
            .padding()
        } else {
            VStack(spacing: 12) {
                if let annual = subscriptionManager.annualProduct {
                    ProductOptionView(
                        product: annual,
                        subscription: .annual,
                        isSelected: selectedProduct?.id == annual.id,
                        onyxSlate: onyxSlate,
                        onyxCharcoal: onyxCharcoal,
                        onyxSilver: onyxSilver,
                        onyxAccent: onyxAccent
                    ) {
                        selectedProduct = annual
                    }
                }

                if let lifetime = subscriptionManager.lifetimeProduct {
                    ProductOptionView(
                        product: lifetime,
                        subscription: .lifetime,
                        isSelected: selectedProduct?.id == lifetime.id,
                        onyxSlate: onyxSlate,
                        onyxCharcoal: onyxCharcoal,
                        onyxSilver: onyxSilver,
                        onyxAccent: onyxAccent
                    ) {
                        selectedProduct = lifetime
                    }
                }
            }
        }
    }

    private var selectedIsSubscription: Bool {
        guard let product = selectedProduct else { return true }
        return OnyxSubscription(rawValue: product.id)?.isSubscription ?? true
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
                    Text(selectedIsSubscription ? "Subscribe" : "Purchase")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: selectedProduct == nil
                                ? [onyxCharcoal, onyxSlate]
                                : [onyxAccent, onyxAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedProduct == nil ? onyxCharcoal : onyxAccent.opacity(0.8), lineWidth: 0.75)
                    )
                    .shadow(color: (selectedProduct == nil ? Color.black : onyxAccent).opacity(0.4), radius: 8, y: 3)
            )
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .accessibilityLabel(isPurchasing ? "Processing" : (selectedIsSubscription ? "Subscribe" : "Purchase"))
        .accessibilityHint(selectedProduct != nil ? "Purchases \(selectedProduct?.displayName ?? "Onyx")" : "Select a plan first")
    }

    @ViewBuilder
    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
                dismiss()
                
                if let error = subscriptionManager.error {
                    // Restore failed - show error
                    toastManager.show(error: error)
                } else if subscriptionManager.hasOnyxEntitlement {
                    // Restore succeeded and found purchases
                    toastManager.showSuccess("Purchases restored")
                } else {
                    // Restore succeeded but no purchases found
                    toastManager.show(message: "No purchases to restore", style: .error, icon: "info.circle.fill")
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(onyxSilver)
        }
        .disabled(subscriptionManager.isLoading)
        .accessibilityHint("Restores previously purchased subscriptions")
    }

    @ViewBuilder
    private var legalSection: some View {
        VStack(spacing: 8) {
            if selectedIsSubscription {
                Text("Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account.")
                    .font(.caption2)
                    .foregroundStyle(onyxSilver.opacity(0.8))
                    .multilineTextAlignment(.center)
            } else {
                Text("One-time purchase. Payment will be charged to your Apple ID account.")
                    .font(.caption2)
                    .foregroundStyle(onyxSilver.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Link("Privacy Policy", destination: URL(string: "https://molargiksoftware.com/#/privacy")!)
                .font(.caption)
                .foregroundStyle(onyxAccent)


            Link("Terms Of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.caption)
                .foregroundStyle(onyxAccent)

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
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "checkmark")
                .foregroundStyle(tint)
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
    let onyxSlate: Color
    let onyxCharcoal: Color
    let onyxSilver: Color
    let onyxAccent: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(subscription.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !subscription.isSubscription {
                            Text("Best Value")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(onyxAccent))
                                .foregroundStyle(.white)
                        }
                    }

                    Text("\(product.displayPrice) \(subscription.priceDescription)")
                        .font(.subheadline)
                        .foregroundStyle(onyxSilver)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? onyxAccent : onyxSilver.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(onyxSlate)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? onyxAccent : onyxCharcoal, lineWidth: isSelected ? 2 : 0.75)
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.5 : 0.3), radius: isSelected ? 10 : 6, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.displayName), \(product.displayPrice) \(subscription.priceDescription)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    PaywallView(featureContext: "Canvas access requires Onyx")
        .environment(SubscriptionManager())
        .environment(ToastManager())
}

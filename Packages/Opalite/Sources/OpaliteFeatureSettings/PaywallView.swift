//
//  PaywallView.swift
//  OpaliteFeatureSettings
//
//  The Onyx purchase screen the shell presents for `.paywall(context:)`: a dark hero,
//  the reason it was shown, what Onyx unlocks, the two plans from the StoreKit catalog,
//  one prominent purchase button, restore, and the App Store disclosures. Purchases go
//  through `SubscriptionManager`; `Product` is only read for display.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import StoreKit
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared
import os

public struct PaywallView: View {
    public let context: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(ToastManager.self) private var toast

    @State private var selectedPlanID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false

    public init(context: String) {
        self.context = context
    }

    // MARK: - Derived

    private var catalog: PaywallCatalog {
        PaywallCatalog(
            annual: subscription.annualProduct.map { PaywallPlan(subscription: .annual, displayPrice: $0.displayPrice) },
            lifetime: subscription.lifetimeProduct.map { PaywallPlan(subscription: .lifetime, displayPrice: $0.displayPrice) }
        )
    }

    private var selectedPlan: PaywallPlan? { catalog.plan(withID: selectedPlanID) }
    private var isBusy: Bool { isPurchasing || isRestoring }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.xl) {
                    ShowcaseHero(
                        systemImage: "diamond.fill",
                        gradient: LinearGradient.opalite,
                        glow: .opalitePurple,
                        title: String(localized: "Opalite Onyx"),
                        subtitle: String(localized: "Everything Opalite has to offer, unlocked.")
                    )

                    contextPill

                    if subscription.hasOnyx {
                        alreadyOnyx
                    } else {
                        features
                        plans
                        legal
                    }
                }
                .frame(maxWidth: Brand.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xl)
            }
            .scrollContentBackground(.hidden)
            .softScrollEdgesIfAvailable()
            .background(paywallBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if !subscription.hasOnyx {
                    purchaseBar
                }
            }
            .navigationTitle("Onyx")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isPurchasing)
                    .accessibilityIdentifier("paywall.close")
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(.opaliteBlue)
        .interactiveDismissDisabled(isPurchasing)
        .task {
            if subscription.products.isEmpty, !subscription.isLoading {
                await subscription.loadProducts()
            }
            selectedPlanID = catalog.resolvedSelection(current: selectedPlanID)
        }
        .onChange(of: subscription.products.count) {
            selectedPlanID = catalog.resolvedSelection(current: selectedPlanID)
        }
        .onChange(of: subscription.hasOnyx) { _, hasOnyx in
            if hasOnyx { dismiss() }
        }
        .sensoryFeedback(.selection, trigger: selectedPlanID)
    }

    // MARK: - Pieces

    private var paywallBackground: some View {
        ZStack {
            Color.onyx
            RadialGradient(colors: [Color.opalitePurple.opacity(0.45), .clear], center: .top, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Color.opaliteBlue.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 380)
        }
    }

    private var contextPill: some View {
        Label(context, systemImage: "lock.open.fill")
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.sm)
            .adaptiveGlassCapsule(tint: .opalitePurple)
            .accessibilityAddTraits(.isStaticText)
    }

    private var alreadyOnyx: some View {
        VStack(spacing: Brand.Space.lg) {
            Label("You have Onyx", systemImage: "checkmark.seal.fill")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text("Everything is unlocked on this device. Thank you for supporting Opalite.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .primaryActionButton()
        }
        .padding(.top, Brand.Space.lg)
    }

    private var features: some View {
        VStack(spacing: 0) {
            ForEach(Array(OnyxFeature.all.enumerated()), id: \.element.id) { index, feature in
                HStack(alignment: .top, spacing: Brand.Space.md) {
                    Image(systemName: feature.systemImage)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(LinearGradient.opaliteHorizontal)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.headline)
                        Text(feature.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.opaliteBlue)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Brand.Space.md)
                .accessibilityElement(children: .combine)
                if index < OnyxFeature.all.count - 1 {
                    Divider().overlay(.white.opacity(0.08))
                }
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .adaptiveGlass(cornerRadius: Brand.Radius.card)
    }

    @ContentBuilder
    private var plans: some View {
        if subscription.isLoading && catalog.isEmpty {
            ProgressView("Loading plans…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, Brand.Space.xl)
        } else if catalog.isEmpty {
            VStack(spacing: Brand.Space.md) {
                Label("Plans Unavailable", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                Text(subscription.error?.errorDescription ?? String(localized: "Check your connection and try again."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Haptics.selection()
                    Task { await subscription.loadProducts() }
                }
                .glassActionButton(tint: .opalitePurple, prominent: false)
                .accessibilityIdentifier("paywall.retry")
            }
            .frame(maxWidth: .infinity)
            .padding(Brand.Space.lg)
            .adaptiveGlass(cornerRadius: Brand.Radius.card)
        } else {
            VStack(spacing: Brand.Space.md) {
                ForEach(catalog.plans) { plan in
                    PlanCard(plan: plan, isSelected: plan.id == selectedPlanID) {
                        selectedPlanID = plan.id
                    }
                }
            }
        }
    }

    private var legal: some View {
        VStack(spacing: Brand.Space.sm) {
            Text(PaywallCatalog.legalText(for: selectedPlan))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .default, value: selectedPlanID)
            HStack(spacing: Brand.Space.md) {
                Link("Terms of Use", destination: SettingsLinks.terms)
                Text("·").foregroundStyle(.tertiary)
                Link("Privacy Policy", destination: SettingsLinks.privacy)
            }
            .font(.caption)
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: Brand.Space.sm) {
            Button {
                Haptics.mediumImpact()
                Task { await purchase() }
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    if isPurchasing {
                        ProgressView()
                    }
                    Text(PaywallCatalog.callToAction(for: selectedPlan))
                        .font(.headline)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity)
            }
            .primaryActionButton(tint: .opalitePurple)
            .disabled(selectedPlan == nil || isBusy)
            .accessibilityLabel(Text(isPurchasing ? "Processing" : PaywallCatalog.callToAction(for: selectedPlan)))
            .accessibilityHint(Text(selectedPlan == nil ? "Choose a plan first" : "Buys \(selectedPlan?.subscription.displayName ?? "")"))
            .accessibilityIdentifier("paywall.purchase")

            Button {
                Haptics.selection()
                Task { await restore() }
            } label: {
                HStack(spacing: Brand.Space.xs) {
                    if isRestoring { ProgressView().controlSize(.small) }
                    Text("Restore Purchases")
                }
                .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(isBusy || subscription.isLoading)
            .accessibilityHint(Text("Checks the App Store for a previous Onyx purchase"))
            .accessibilityIdentifier("paywall.restore")
        }
        .frame(maxWidth: Brand.readableWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Brand.Space.lg)
        .padding(.top, Brand.Space.md)
        .padding(.bottom, Brand.Space.sm)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func purchase() async {
        guard let plan = selectedPlan,
              let product = subscription.products.first(where: { $0.id == plan.id }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await subscription.purchase(product) {
                toast.showSuccess(String(localized: "Welcome to Onyx"), systemImage: "diamond.fill")
                dismiss()
            }
        } catch {
            Log.subscription.error("Purchase failed: \(error.localizedDescription)")
            toast.show(error: error)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        let hadOnyx = subscription.hasOnyx
        await subscription.restorePurchases()
        let outcome = RestoreOutcome.evaluate(hadOnyx: hadOnyx, hasOnyx: subscription.hasOnyx, failed: subscription.error != nil)
        switch outcome {
        case .failed:
            if let error = subscription.error { toast.show(error: error) }
        case .restored, .alreadyActive:
            toast.showSuccess(outcome.message ?? "", systemImage: "diamond.fill")
        case .nothingToRestore:
            toast.show(message: outcome.message ?? "", style: .info)
        }
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let plan: PaywallPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Brand.Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Brand.Space.sm) {
                        Text(plan.subscription.displayName)
                            .font(.headline)
                        if plan.isBestValue {
                            Text("Best Value")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule(style: .continuous).fill(LinearGradient.opaliteHorizontal))
                                .foregroundStyle(Color.onyx)
                        }
                    }
                    Text("\(plan.displayPrice) \(plan.subscription.priceDescription)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.opaliteBlue : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(Brand.Space.lg)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .adaptiveGlass(tint: isSelected ? .opalitePurple : nil, interactive: true, cornerRadius: Brand.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(LinearGradient.opaliteHorizontal) : AnyShapeStyle(Color.white.opacity(0.08)), lineWidth: isSelected ? 2 : 1)
        )
        .hoverLift()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(plan.subscription.displayName), \(plan.displayPrice) \(plan.subscription.priceDescription)"))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("paywall.plan.\(plan.subscription.rawValue)")
    }
}

#if DEBUG
#Preview("Paywall") {
    PaywallView(context: "Creating more palettes requires Onyx")
        .settingsPreviewEnvironment()
}
#endif
#endif

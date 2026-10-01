//
//  OnyxInfoSheet.swift
//  OpaliteFeatureSettings
//
//  "About Onyx": what it unlocks and the two ways to get it, with a hand-off to the
//  paywall through the router for users who don't have it yet.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct OnyxInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(\.onyxEntitlement) private var entitlement

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.xl) {
                    ShowcaseHero(
                        systemImage: "diamond.fill",
                        gradient: LinearGradient.opalite,
                        glow: .opalitePurple,
                        title: String(localized: "Opalite Onyx"),
                        subtitle: String(localized: "Unlock the full power of Opalite.")
                    )

                    VStack(spacing: Brand.Space.md) {
                        ForEach(OnyxFeature.all) { feature in
                            ShowcaseFeatureRow(systemImage: feature.systemImage, title: feature.title, detail: feature.detail, tint: .opaliteBlue)
                        }
                    }

                    VStack(alignment: .leading, spacing: Brand.Space.md) {
                        Text("Ways to Get Onyx")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        ShowcaseStepRow(number: 1, text: String(localized: "Annual — a yearly subscription, the best recurring value."), tint: .opalitePurple)
                        ShowcaseStepRow(number: 2, text: String(localized: "Lifetime — one purchase, keep Onyx forever."), tint: .opalitePurple)
                        Text("Either way, Onyx is shared with every device signed in with your Apple Account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: Brand.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xl)
            }
            .scrollContentBackground(.hidden)
            .softScrollEdgesIfAvailable()
            .background {
                ZStack {
                    Color.onyx
                    RadialGradient(colors: [Color.opalitePurple.opacity(0.4), .clear], center: .top, startRadius: 0, endRadius: 420)
                }
                .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom) {
                if !entitlement.hasOnyx {
                    Button {
                        Haptics.mediumImpact()
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            router.requestPaywall(context: String(localized: "Unlock everything Opalite has to offer"))
                        }
                    } label: {
                        Label("Get Onyx", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionButton(tint: .opalitePurple)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.md)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .accessibilityIdentifier("onyxInfo.getOnyx")
                }
            }
            .navigationTitle("About Onyx")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(.opaliteBlue)
    }
}

#if DEBUG
#Preview("About Onyx") {
    OnyxInfoSheet()
        .settingsPreviewEnvironment()
}
#endif
#endif

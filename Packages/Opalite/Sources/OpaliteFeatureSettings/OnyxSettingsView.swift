//
//  OnyxSettingsView.swift
//  OpaliteFeatureSettings
//
//  The Onyx page: status card, the one action that applies (get / manage), restore,
//  and what Onyx unlocks. The legal links live on the paywall.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import StoreKit
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared

struct OnyxSettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastManager.self) private var toast
    @Environment(SubscriptionManager.self) private var subscription

    @State private var isRestoring = false
    @State private var isShowingManageSubscriptions = false

    private var status: OnyxStatus {
        OnyxStatus(hasOnyx: subscription.hasOnyx, subscription: subscription.currentSubscription)
    }

    var body: some View {
        Form {
            Section {
                OnyxStatusCard(status: status)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                if status.showsUpgrade {
                    Button {
                        Haptics.selection()
                        router.requestPaywall(context: String(localized: "Unlock everything Opalite has to offer"))
                    } label: {
                        Label("Get Onyx", systemImage: "sparkles")
                            .labelStyle(.settingsIcon(.onyx))
                    }
                    .accessibilityHint(Text("Shows Onyx plans and prices"))
                    .accessibilityIdentifier("onyx.get")
                } else if status.canManageSubscription {
                    Button {
                        Haptics.selection()
                        isShowingManageSubscriptions = true
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard.fill")
                            .labelStyle(.settingsIcon(.onyx))
                    }
                    .accessibilityHint(Text("Opens your App Store subscription"))
                    .accessibilityIdentifier("onyx.manage")
                }

                Button {
                    Haptics.selection()
                    Task { await restore() }
                } label: {
                    HStack {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                            .labelStyle(.settingsIcon(.blue))
                        if isRestoring {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring || subscription.isLoading)
                .accessibilityHint(Text("Checks the App Store for a previous Onyx purchase"))
                .accessibilityIdentifier("onyx.restore")
            } footer: {
                if status.showsUpgrade {
                    Text("Already bought Onyx on another device? Restore Purchases brings it to this one.")
                }
            }

            Section {
                ForEach(OnyxFeature.all) { feature in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                            Text(feature.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: feature.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(LinearGradient.opaliteHorizontal)
                    }
                    .labelStyle(.alignedIcon)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("What Onyx Unlocks")
            }
        }
        .navigationTitle("Onyx")
        .navigationSubtitleIfAvailable(status.title)
        .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
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
        case .restored:
            toast.showSuccess(outcome.message ?? "", systemImage: "diamond.fill")
        case .alreadyActive:
            toast.showSuccess(outcome.message ?? "", systemImage: "diamond.fill")
        case .nothingToRestore:
            toast.show(message: outcome.message ?? "", style: .info)
        }
    }
}

#if DEBUG
#Preview("Onyx · Free") {
    NavigationStack { OnyxSettingsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

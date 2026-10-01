//
//  SettingsView.swift
//  OpaliteFeatureSettings
//
//  The Settings tab's root content: profile, Onyx, iCloud, preferences, Apple Watch,
//  SwatchBar, About, and (debug builds) developer tools. The shell owns the
//  NavigationStack and routes `SettingsDestination` values to `SettingsDestinationView`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import StoreKit
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared
#if canImport(UIKit)
import UIKit
#endif

public struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastManager.self) private var toast
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(CommunityModel.self) private var community
    @Environment(CloudSyncManager.self) private var cloudSync
    @Environment(SubscriptionManager.self) private var subscription
    #if os(iOS) && canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
    @Environment(PhoneConnectivityManager.self) private var connectivity
    #endif

    @AppStorage(AppStorageKeys.appTheme) private var themeRaw = AppThemeOption.system.rawValue
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessRaw = ColorBlindnessMode.off.rawValue
    @AppStorage(AppStorageKeys.includeHexPrefix) private var includeHexPrefix = true

    @State private var displayName = ""
    @State private var isSyncingNow = false
    @State private var isShowingManageSubscriptions = false
    @State private var isConfirmingSampleData = false
    @State private var isShowingCommunityAdmin = false
    @FocusState private var isNameFocused: Bool

    private let version = AppVersionInfo()

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            profileSection
            onyxSection
            cloudSection
            preferencesSection
            #if os(iOS) && canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
            watchSection
            #endif
            if supportsSwatchBar {
                swatchBarSection
            }
            aboutSection
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .onAppear { displayName = portfolio.authorName }
        .onChange(of: displayName) { _, newValue in
            ProfileName.commit(newValue, portfolio: portfolio, community: community)
        }
        .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
        .sheet(isPresented: $isShowingCommunityAdmin) { CommunityAdminSheet() }
        .confirmationDialog("Generate Sample Data?", isPresented: $isConfirmingSampleData, titleVisibility: .visible) {
            Button("Generate") {
                Haptics.selection()
                #if DEBUG
                portfolio.generateSampleData()
                #endif
                toast.showSuccess(String(localized: "Sample data added"), systemImage: "wand.and.stars")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Adds example colors and palettes to your portfolio. They sync like anything else.")
        }
    }

    // MARK: - Derived

    private var onyxStatus: OnyxStatus {
        OnyxStatus(hasOnyx: subscription.hasOnyx, subscription: subscription.currentSubscription)
    }

    private var theme: AppThemeOption { AppThemeOption(rawValue: themeRaw) ?? .system }
    private var colorBlindnessMode: ColorBlindnessMode { ColorBlindnessMode(rawValue: colorBlindnessRaw) ?? .off }

    private var supportsSwatchBar: Bool {
        #if canImport(UIKit)
        UIApplication.shared.supportsMultipleScenes
        #else
        false
        #endif
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: Brand.Space.md) {
                Label("Display Name", systemImage: "person.fill")
                    .labelStyle(.settingsIcon(.opalitePurple))
                    .accessibilityHidden(true)
                TextField("Your name", text: $displayName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false }
                    .accessibilityLabel(Text("Display name"))
                    .accessibilityIdentifier("settings.displayName")
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Stamped on the colors and palettes you create, and shown as your name on anything you publish to the Community.")
        }
    }

    // MARK: - Onyx

    private var onyxSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.onyx) {
                OnyxStatusCard(status: onyxStatus, showsChevronGutter: true)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("settings.onyx")

            if onyxStatus.showsUpgrade {
                Button {
                    Haptics.selection()
                    router.requestPaywall(context: String(localized: "Unlock everything Opalite has to offer"))
                } label: {
                    Label("Get Onyx", systemImage: "sparkles")
                        .labelStyle(.settingsIcon(.onyx))
                }
                .accessibilityHint(Text("Shows Onyx plans and prices"))
                .accessibilityIdentifier("settings.getOnyx")
            } else if onyxStatus.canManageSubscription {
                Button {
                    Haptics.selection()
                    isShowingManageSubscriptions = true
                } label: {
                    Label("Manage Subscription", systemImage: "creditcard.fill")
                        .labelStyle(.settingsIcon(.onyx))
                }
                .accessibilityHint(Text("Opens your App Store subscription"))
            }
        } header: {
            Text("Onyx")
        } footer: {
            if onyxStatus.showsUpgrade {
                Text("One purchase or subscription unlocks Onyx on every device signed in with your Apple Account.")
            }
        }
    }

    // MARK: - iCloud

    private var cloudSection: some View {
        Section {
            LabeledContent {
                Text(CloudSyncPresentation.title(for: cloudSync.syncStatus))
                    .foregroundStyle(cloudSync.syncStatus.isError ? .orange : .secondary)
                    .contentTransition(.opacity)
            } label: {
                Label {
                    Text("iCloud Sync")
                } icon: {
                    Image(systemName: cloudSync.syncStatus.systemImage)
                        .symbolEffect(.rotate, isActive: cloudSync.syncStatus == .syncing)
                }
                .labelStyle(.settingsIcon(.blue))
            }
            .animation(.default, value: cloudSync.syncStatus)
            .accessibilityElement(children: .combine)

            if let lastSync = cloudSync.lastSyncDate {
                LabeledContent("Last Synced") {
                    Text("\(Text(lastSync, style: .relative)) ago")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Haptics.selection()
                Task { await syncNow() }
            } label: {
                HStack {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.settingsIcon(.blue))
                    if isSyncingNow {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isSyncingNow || !CloudSyncPresentation.canSyncNow(cloudSync.syncStatus))
            .accessibilityHint(Text("Saves pending changes and syncs with iCloud"))
            .accessibilityIdentifier("settings.syncNow")
        } header: {
            Text("iCloud")
        } footer: {
            Text(CloudSyncPresentation.guidance(for: cloudSync.syncStatus))
        }
    }

    private func syncNow() async {
        isSyncingNow = true
        defer { isSyncingNow = false }
        await cloudSync.triggerSync()
        switch cloudSync.syncStatus {
        case .error(let message):
            toast.show(message: message, style: .error, systemImage: "exclamationmark.icloud")
        case .offline:
            toast.show(error: OpaliteError.communityOffline)
        case .unavailable:
            toast.show(error: OpaliteError.communityNotSignedIn)
        default:
            toast.showSuccess(String(localized: "Synced with iCloud"), systemImage: "checkmark.icloud")
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.appearance) {
                LabeledContent {
                    Text(theme.title)
                } label: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                        .labelStyle(.settingsIcon(.indigo))
                }
            }
            .accessibilityIdentifier("settings.appearance")

            NavigationLink(value: SettingsDestination.accessibility) {
                LabeledContent {
                    Text(colorBlindnessMode.isActive ? colorBlindnessMode.shortTitle : String(localized: "Off"))
                        .foregroundStyle(colorBlindnessMode.isActive ? .orange : .secondary)
                } label: {
                    Label("Color Vision", systemImage: colorBlindnessMode.systemImage)
                        .labelStyle(.settingsIcon(.orange))
                }
            }
            .accessibilityIdentifier("settings.accessibility")

            NavigationLink(value: SettingsDestination.hexCopying) {
                LabeledContent {
                    Text(includeHexPrefix ? "#3380CC" : "3380CC")
                        .font(.body.monospaced())
                } label: {
                    Label("Hex Codes", systemImage: "number")
                        .labelStyle(.settingsIcon(.green))
                }
            }
            .accessibilityIdentifier("settings.hexCopying")
        } header: {
            Text("Preferences")
        }
    }

    // MARK: - Apple Watch

    #if os(iOS) && canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
    private var watchSection: some View {
        let status = WatchStatusPresentation(
            isPaired: connectivity.isPaired,
            isWatchAppInstalled: connectivity.isWatchAppInstalled,
            isReachable: connectivity.isReachable
        )
        return Section {
            NavigationLink(value: SettingsDestination.watch) {
                LabeledContent {
                    Text(status.summary)
                } label: {
                    Label("Apple Watch", systemImage: status.systemImage)
                        .labelStyle(.settingsIcon(.pink))
                }
            }
            .accessibilityIdentifier("settings.watch")
        } header: {
            Text("Devices")
        }
    }
    #endif

    // MARK: - SwatchBar

    private var swatchBarSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.swatchBar) {
                Label("SwatchBar", systemImage: "square.stack.fill")
                    .labelStyle(.settingsIcon(.purple))
            }
            .accessibilityIdentifier("settings.swatchBar")
        } footer: {
            Text("A compact window with your colors, for working alongside other apps.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.about) {
                LabeledContent {
                    Text(version.formatted)
                } label: {
                    Label("About Opalite", systemImage: "info.circle.fill")
                        .labelStyle(.settingsIcon(.gray))
                }
            }
            .accessibilityIdentifier("settings.about")
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button {
                Haptics.selection()
                isConfirmingSampleData = true
            } label: {
                Label("Generate Sample Data", systemImage: "wand.and.stars")
                    .labelStyle(.settingsIcon(.teal))
            }
            .accessibilityHint(Text("Adds example colors and palettes to your portfolio"))

            Button {
                Haptics.selection()
                isShowingCommunityAdmin = true
            } label: {
                Label("Community Moderation", systemImage: "shield.checkered")
                    .labelStyle(.settingsIcon(.red))
            }
            .accessibilityHint(Text("Reviews reported Community content"))
        } header: {
            Text("Debug")
        } footer: {
            Text("Developer tools. Not included in App Store builds.")
        }
    }
    #endif
}

// MARK: - Previews

#if DEBUG
#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .navigationDestination(for: SettingsDestination.self) { SettingsDestinationView(destination: $0) }
    }
    .settingsPreviewEnvironment()
}

#Preview("Settings · Onyx") {
    NavigationStack {
        SettingsView()
            .navigationDestination(for: SettingsDestination.self) { SettingsDestinationView(destination: $0) }
    }
    .settingsPreviewEnvironment(hasOnyx: true)
}
#endif
#endif

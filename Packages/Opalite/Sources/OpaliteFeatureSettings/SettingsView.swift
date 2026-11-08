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
    @Environment(BackupManager.self) private var backups
    @Environment(SubscriptionManager.self) private var subscription
    #if os(iOS) && canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
    @Environment(PhoneConnectivityManager.self) private var connectivity
    #endif

    @Environment(HexCopyModel.self) private var hexCopy

    @AppStorage(AppStorageKeys.appTheme) private var themeRaw = AppThemeOption.system.rawValue
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessRaw = ColorBlindnessMode.off.rawValue

    @State private var displayName = ""
    @State private var isSyncingNow = false
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
            backupsSection
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
        .sharedSheet(isPresented: $isShowingCommunityAdmin) { CommunityAdminSheet() }
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

    private var supportsSwatchBar: Bool { SwatchBarSupport.isAvailable }

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

    /// The glossy card alone — it opens the Onyx page, which holds get/manage/restore.
    /// Row insets and background are cleared so the grouped background doesn't peek out
    /// around its corners.
    private var onyxSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.onyx) {
                OnyxStatusCard(status: onyxStatus, showsChevronGutter: true)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("settings.onyx")
        } header: {
            Text("Onyx")
        } footer: {
            if onyxStatus.showsUpgrade {
                Text("One purchase unlocks Onyx on every device signed in with your Apple Account.")
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

            syncHealthRows

            if cloudSync.isCloudAvailable {
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
            }
        } header: {
            Text("iCloud")
        } footer: {
            VStack(alignment: .leading, spacing: Brand.Space.sm) {
                Text(CloudSyncPresentation.guidance(for: cloudSync.syncStatus))
                if let note = SyncHealthPresentation.storageExplanation(cloudSync.storeMode) {
                    Text(note)
                }
                Text("Last Synced is the last time iCloud reported a finished sync since Opalite opened. iOS doesn't tell apps about earlier syncs.")
            }
        }
    }

    // MARK: - Backups

    private var backupsSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.backups) {
                LabeledContent {
                    Text(backups.lastBackupDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? String(localized: "None Yet"))
                } label: {
                    Label("Backups", systemImage: "clock.arrow.circlepath")
                        .labelStyle(.settingsIcon(.green))
                }
            }
            .accessibilityIdentifier("settings.backups")
        } footer: {
            Text("A copy of your colors and palettes is saved on this device every day.")
        }
    }

    /// What iCloud actually reported: account, where the library is stored, the last
    /// finished sync, and the last error. Nothing here is estimated.
    @ContentBuilder
    private var syncHealthRows: some View {
        LabeledContent("iCloud Account") {
            Text(SyncHealthPresentation.account(isAvailable: cloudSync.isCloudAvailable))
                .foregroundStyle(cloudSync.isCloudAvailable ? Color.secondary : Color.orange)
        }
        .accessibilityIdentifier("settings.sync.account")

        LabeledContent("Library Storage") {
            Text(SyncHealthPresentation.storage(cloudSync.storeMode))
                .foregroundStyle(cloudSync.storeMode == .cloudKit ? Color.secondary : Color.orange)
        }
        .accessibilityIdentifier("settings.sync.storage")

        LabeledContent("Last Synced") {
            Text(SyncHealthPresentation.lastSynced(cloudSync.lastSuccessfulSyncDate))
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("settings.sync.lastSynced")

        if let problem = cloudSync.lastSyncError {
            LabeledContent("Last Problem") {
                Text(SyncHealthPresentation.lastProblem(problem, lastSuccess: cloudSync.lastSuccessfulSyncDate))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityIdentifier("settings.sync.lastProblem")
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

            Toggle(isOn: Binding(get: { hexCopy.includesPrefix }, set: { newValue in
                guard hexCopy.includesPrefix != newValue else { return }
                Haptics.selection()
                hexCopy.includesPrefix = newValue
            })) {
                Label("Include # Prefix", systemImage: "number")
                    .labelStyle(.settingsIcon(.green))
            }
            .toggleStyle(.settingsRow)
            .tint(.green)
            .accessibilityIdentifier("settings.includesPrefix")
        } header: {
            Text("Preferences")
        } footer: {
            Text("CSS and most design tools expect the # prefix. Turn it off when you paste into code that adds its own.")
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

            @Bindable var subscription = subscription
            Toggle(isOn: $subscription.isSimulatingOnyx) {
                Label("Simulate Onyx", systemImage: "diamond")
                    .labelStyle(.settingsIcon(.indigo))
            }
            .toggleStyle(.settingsRow)
            .onChange(of: subscription.isSimulatingOnyx) { Haptics.selection() }
            .accessibilityHint(Text("Unlocks Onyx features in this debug build without a purchase"))
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

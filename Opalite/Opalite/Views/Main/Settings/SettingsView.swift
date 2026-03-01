//
//  SettingsView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(CanvasManager.self) private var canvasManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CommunityManager.self) private var communityManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw: String = AppThemeOption.system.rawValue
    @AppStorage(AppStorageKeys.appIcon) private var appIconRaw: String = AppIconOption.dark.rawValue
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue
    @AppStorage(AppStorageKeys.includeHexPrefix) private var includeHexPrefix: Bool = true
    @AppStorage(AppStorageKeys.skipSwatchBarConfirmation) private var skipSwatchBarConfirmation: Bool = false
    @AppStorage(AppStorageKeys.hasAttemptedUserNameFetch) private var hasAttemptedUserNameFetch: Bool = false
    @AppStorage(AppStorageKeys.hasUserEditedDisplayName) private var hasUserEditedDisplayName: Bool = false

    @State private var isShowingDeleteAllColorsAlert: Bool = false
    @State private var isShowingDeleteAllCanvasesAlert: Bool = false
    @State private var isShowingInsertSamplesAlert: Bool = false
    @State private var isShowingPaywall: Bool = false
    @State private var isRestoringPurchases: Bool = false
    @State private var isShowingWatchAppInfo: Bool = false
    @State private var isShowingCommunityAdmin: Bool = false

    @State private var exportPDFURL: IdentifiableURL?
    @State private var isShowingExportSelection: Bool = false
    @State private var isSettingNameProgrammatically: Bool = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "—"
        return "\(version) (Build \(build))"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }

    private var isColorBlindnessActive: Bool {
        (ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off) != .off
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Display Name", systemImage: "person")
                                .foregroundStyle(.primary)

                            Spacer()
                            TextField("Your name", text: $userName)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .accessibilityLabel("Display name")
                                .onChange(of: userName) { _, _ in
                                    // Mark that user has manually edited their display name
                                    // Skip if we're setting the name programmatically (e.g., from iCloud)
                                    if !isSettingNameProgrammatically && !hasUserEditedDisplayName {
                                        hasUserEditedDisplayName = true
                                    }
                                }
                        }
                        Text("Your display name appears in the metadata of each color you create and on content you publish to Community. The initial value may be pulled from your Apple Account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    #if !os(visionOS)
                    Picker(selection: Binding<AppThemeOption>(
                        get: { AppThemeOption(rawValue: appThemeRaw) ?? .system },
                        set: { appThemeRaw = $0.rawValue }
                    )) {
                        ForEach(AppThemeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Label("App Theme", systemImage: "circle.lefthalf.filled")
                            .foregroundStyle(.primary)
                    }
                    #endif

                    #if canImport(UIKit) && !os(visionOS)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("App Icon", systemImage: "app")
                            .foregroundStyle(.primary)

                        Picker("App Icon", selection: Binding<AppIconOption>(
                            get: { AppIconOption(rawValue: appIconRaw) ?? .dark },
                            set: { newValue in
                                appIconRaw = newValue.rawValue
                                setAppIcon(newValue)
                            }
                        )) {
                            ForEach(AppIconOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    #endif

                    Toggle(isOn: $includeHexPrefix) {
                        Label("Include # in Copied Codes", systemImage: "number")
                            .foregroundStyle(.primary)
                    }
                    .tint(.green)

                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom != .phone {
                        swatchBarConfirmationToggle
                    }
                    #else
                    swatchBarConfirmationToggle
                    #endif
                }
                
                Section {
                    Picker(selection: Binding<ColorBlindnessMode>(
                        get: { ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off },
                        set: { colorBlindnessModeRaw = $0.rawValue }
                    )) {
                        ForEach(ColorBlindnessMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Label("Color Vision", systemImage: isColorBlindnessActive ? "eye.trianglebadge.exclamationmark" : "eye")
                                .foregroundStyle(isColorBlindnessActive ? .orange : .primary)

                            if isColorBlindnessActive {
                                Text("Active")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.orange))
                            }
                        }
                    }
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Simulate how colors appear to people with color vision deficiencies. The Settings tab icon will change when simulation is active.")
                }

                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Section {
                        Text("On iPad Pro, colors may appear more accurate by enabling Settings → Display & Brightness → Advanced → Reference Mode, if available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("iPad Tip")
                    }
                }
                #endif

                Section {
                    if subscriptionManager.hasOnyxEntitlement {
                        HStack {
                            Label("Onyx", systemImage: "inset.filled.oval")
                                .foregroundStyle(colorScheme == .dark ? .gray : .black)

                            Spacer()
                            if let subscription = subscriptionManager.currentSubscription {
                                Text(subscription.displayName)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Active")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "inset.filled.oval")
                                    .foregroundStyle(.black, colorScheme == .dark ? .white : .black)
                                    .padding(.trailing, 8)

                                Text("Upgrade to Onyx")
                                    .foregroundStyle(.inverseTheme)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.inverseTheme)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel("Upgrade to Onyx")
                        .accessibilityHint("Opens subscription options for unlimited features")
                    }

                    Button {
                        HapticsManager.shared.selection()
                        Task {
                            isRestoringPurchases = true
                            let hadOnyxBefore = subscriptionManager.hasOnyxEntitlement
                            await subscriptionManager.restorePurchases()
                            isRestoringPurchases = false

                            if let error = subscriptionManager.error {
                                toastManager.show(error: error)
                            } else if subscriptionManager.hasOnyxEntitlement && !hadOnyxBefore {
                                toastManager.showSuccess("Onyx subscription restored!")
                            } else if subscriptionManager.hasOnyxEntitlement {
                                toastManager.showSuccess("Onyx is already active")
                            } else {
                                toastManager.show(message: "No purchases to restore", style: .info)
                            }
                        }
                    } label: {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                                .foregroundStyle(.blue)
                            if isRestoringPurchases {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)
                    .accessibilityLabel("Restore Purchases")
                    .accessibilityHint("Checks for previously purchased subscriptions")
                } header: {
                    Text("Subscription")
                }

                if communityManager.isAdmin {
                    Section {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingCommunityAdmin = true
                        } label: {
                            Label("Community Admin", systemImage: "shield.checkered")
                                .foregroundStyle(.blue)
                        }
                    } header: {
                        Text("Administration")
                    }
                }

                #if os(iOS)
                // Apple Watch section - iPhone only
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Section {
                        // Sync status
                        HStack {
                            Label("Watch Paired", systemImage: "applewatch")
                                .foregroundStyle(.primary)
                            Spacer()
                            if PhoneSessionManager.shared.isPaired {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("No")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)

                        if PhoneSessionManager.shared.isPaired {
                            HStack {
                                Label("Watch App Installed", systemImage: "app.badge.checkmark")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if PhoneSessionManager.shared.isWatchAppInstalled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Text("No")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }

                        if PhoneSessionManager.shared.isWatchAppInstalled {
                            if let lastSync = PhoneSessionManager.shared.lastSyncToWatch {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(lastSync, style: .relative)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(PhoneSessionManager.shared.lastSyncColorCount) colors, \(PhoneSessionManager.shared.lastSyncPaletteCount) palettes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                HStack {
                                    Label("Last Synced", systemImage: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("Never")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Button {
                            HapticsManager.shared.selection()
                            isShowingWatchAppInfo = true
                        } label: {
                            Label("About the Watch App", systemImage: "info.circle")
                                .foregroundStyle(.blue)
                        }
                    } header: {
                        Text("Apple Watch")
                    } footer: {
                        if PhoneSessionManager.shared.isPaired && PhoneSessionManager.shared.isWatchAppInstalled {
                            Text("Colors and palettes sync automatically when the app is active.")
                        } else if PhoneSessionManager.shared.isPaired {
                            Text("Install the Opalite Watch app from the Watch app on your iPhone.")
                        } else {
                            Text("Pair an Apple Watch to sync your colors to your wrist.")
                        }
                    }
                }
                #endif

                Section {
                    Button {
                        HapticsManager.shared.selection()
                        isShowingInsertSamplesAlert = true
                    } label: {
                        Label("Insert Sample Data", systemImage: "tray.and.arrow.down")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityHint("Adds example colors and palettes to your portfolio")

                    Button {
                        HapticsManager.shared.selection()
                        isShowingExportSelection = true
                    } label: {
                        Label("Export Portfolio to PDF", systemImage: "doc.richtext")
                            .foregroundStyle(.blue)
                    }
                    .disabled(colorManager.colors.isEmpty && colorManager.palettes.isEmpty)
                    .accessibilityHint("Opens selection to choose which palettes and colors to export")
                } header: {
                    Text("Data")
                } footer: {
                    Text("Choose which palettes and colors to include in the PDF export.")
                }

                Section {
                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        isShowingDeleteAllCanvasesAlert = true
                    } label: {
                        Label("Delete All Canvases", systemImage: "scribble")
                            .foregroundStyle(.red)
                    }
                    .accessibilityHint("Permanently removes all drawing canvases")

                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        isShowingDeleteAllColorsAlert = true
                    } label: {
                        Label("Delete All Colors & Palettes", systemImage: "trash.fill")
                            .foregroundStyle(.red)
                    }
                    .accessibilityHint("Permanently removes all colors and palettes from your portfolio")
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("These actions cannot be undone.")
                }

                Section {
                    LabeledContent("Version") {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Developer") {
                        Link("Nick Molargik", destination: URL(string: "https://www.linkedin.com/in/nicholas-molargik/")!)
                            .foregroundStyle(.blue)
                    }

                    LabeledContent("Publisher") {
                        Link("Molargik Software LLC", destination: URL(string: "https://www.molargiksoftware.com")!)
                            .foregroundStyle(.blue)
                    }
                } header :{
                    Text("Opalite")
                } footer: {
                   Text("Thank you to all of our amazing TestFlight testers!")
               }

                #if DEBUG
                Section {
                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        UserDefaults.standard.set(false, forKey: AppStorageKeys.isOnboardingComplete)
                        exit(0)
                    } label: {
                        Label("Reset Onboarding & Restart", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Resets the onboarding flag and terminates the app. Relaunch to see the splash screen.")
                }
                #endif
            }
            .navigationTitle("Settings")
        }
        .alert("Insert Sample Data?", isPresented: $isShowingInsertSamplesAlert) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
                Button("Continue", role: .confirm) {
                    HapticsManager.shared.selection()
                    do {
                        try colorManager.loadSamples()
                        try canvasManager.loadSamples()
                    } catch {
                        print("Failed to load samples: \(error)")
                    }
                }
            } else {
                Button("Continue") {
                    HapticsManager.shared.selection()
                    do {
                        try colorManager.loadSamples()
                        try canvasManager.loadSamples()
                    } catch {
                        print("Failed to load samples: \(error)")
                    }
                }
            }
        } message: {
            Text("This will insert sample colors and palettes into your portfolio.")
        }
        .alert("Delete All Colors & Palettes?", isPresented: $isShowingDeleteAllColorsAlert) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            Button("Delete", role: .destructive) {
                HapticsManager.shared.selection()
                deleteAllColorsAndPalettes()
            }
        } message: {
            Text("This will permanently delete all Opalite colors and palettes. This action cannot be undone.")
        }
        .alert("Delete All Canvases?", isPresented: $isShowingDeleteAllCanvasesAlert) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            Button("Delete", role: .destructive) {
                HapticsManager.shared.selection()
                deleteAllCanvases()
            }
        } message: {
            Text("This will permanently delete all canvases. This action cannot be undone.")
        }
        .sheet(item: $exportPDFURL) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $isShowingExportSelection) {
            PaletteOrderSheet(isForExport: true) { palettes, looseColors in
                exportColorsToPDF(palettes: palettes, looseColors: looseColors)
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Loads of additional features!")
        }
        .sheet(isPresented: $isShowingWatchAppInfo) {
            WatchAppInfoSheet()
        }
        .sheet(isPresented: $isShowingCommunityAdmin) {
            CommunityAdminSheet()
        }
        .task {
            await communityManager.checkAdminStatus()

            // Attempt to fetch user's name from iCloud on first Settings visit
            // Never overwrite if user has manually edited their display name
            if !hasAttemptedUserNameFetch && !hasUserEditedDisplayName {
                hasAttemptedUserNameFetch = true

                // Only attempt if userName is still the default
                if userName == "User" {
                    if let discoveredName = await communityManager.discoverCurrentUserName() {
                        isSettingNameProgrammatically = true
                        userName = discoveredName
                        isSettingNameProgrammatically = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var swatchBarConfirmationToggle: some View {
        Toggle(isOn: $skipSwatchBarConfirmation) {
            Label("Skip SwatchBar Confirmation", systemImage: "square.stack")
                .foregroundStyle(.primary)
        }
        .tint(.green)
    }

    // MARK: - Actions

    #if canImport(UIKit) && !os(visionOS)
    private func setAppIcon(_ option: AppIconOption) {
        let iconName: String? = option == .dark ? nil : "AppIcon-Light"

        guard UIApplication.shared.supportsAlternateIcons else { return }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error {
                print("Failed to set app icon: \(error.localizedDescription)")
            }
        }
    }
    #endif

    private func deleteAllColorsAndPalettes() {
        do {
            _ = try colorManager.fetchColors()
            _ = try colorManager.fetchPalettes()

            // Delete colors first (relationships), then palettes.
            for color in colorManager.colors {
                try colorManager.deleteColor(color)
            }
            for palette in colorManager.palettes {
                try colorManager.deletePalette(palette)
            }
        } catch {
            print("Failed to delete all colors/palettes: \(error)")
        }
    }

    private func deleteAllCanvases() {
        do {
            _ = try canvasManager.fetchCanvases()
            for canvas in canvasManager.canvases {
                try canvasManager.deleteCanvas(canvas)
            }
        } catch {
            print("Failed to delete all canvases: \(error)")
        }
    }

    #if canImport(UIKit)
    private func exportColorsToPDF(palettes: [OpalitePalette], looseColors: [OpaliteColor]) {
        do {
            let url = try PortfolioPDFExporter.export(
                palettes: palettes,
                looseColors: looseColors,
                userName: userName
            )
            exportPDFURL = IdentifiableURL(url: url)
        } catch {
            print("Failed to export PDF: \(error)")
        }
    }
    #endif
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Settings") {
    // In-memory container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpaliteColor.self,
            OpalitePalette.self,
            CanvasFile.self,
        configurations: config
    )

    let context = container.mainContext

    return SettingsView()
        .modelContainer(container)
        .environment(ColorManager(context: context))
        .environment(CanvasManager(context: context))
        .environment(SubscriptionManager())
        .environment(CommunityManager())
        .environment(ToastManager())
}

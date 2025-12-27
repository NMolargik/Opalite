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
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw: String = AppThemeOption.system.rawValue
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue
    @AppStorage(AppStorageKeys.includeHexPrefix) private var includeHexPrefix: Bool = true

    @State private var isShowingDeleteAllColorsAlert: Bool = false
    @State private var isShowingDeleteAllCanvasesAlert: Bool = false
    @State private var isShowingInsertSamplesAlert: Bool = false
    @State private var isShowingPaywall: Bool = false
    @State private var isRestoringPurchases: Bool = false

    @State private var exportPDFURL: IdentifiableURL? = nil
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "—"
        return "\(version) (Build \(build))"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
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
                        }
                        Text("Your display name appears in the metadata of each color you create.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

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
                        Label("Color Vision", systemImage: "eye")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Simulate how colors appear to people with color vision deficiencies. A banner will appear when simulation is active.")
                }

                Section {
                    Toggle(isOn: $includeHexPrefix) {
                        Label("Include # in Hex Codes", systemImage: "number")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Copying")
                } footer: {
                    Text("When enabled, copied hex codes will include the \"#\" prefix (e.g., #FF5733). When disabled, only the hex value is copied (e.g., FF5733).")
                }

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
                            }
                        }
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
                } header: {
                    Text("Subscription")
                }

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
                        exportColorsToPDF()
                    } label: {
                        Label("Export Portfolio to PDF", systemImage: "doc.richtext")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityHint("Creates a PDF document of all your colors and palettes")
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export includes your current colors and palettes.")
                }

                Section {
                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        isShowingDeleteAllCanvasesAlert = true
                    } label: {
                        Label("Delete All Canvases", systemImage: "document.on.trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityHint("Permanently removes all drawing canvases")

                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        isShowingDeleteAllColorsAlert = true
                    } label: {
                        Label("Delete All Colors & Palettes", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityHint("Permanently removes all colors and palettes from your portfolio")
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("These actions cannot be undone.")
                }

                Section {
                    Text("On iPad Pro, colors may appear more accurate by enabling Settings → Display & Brightness → Advanced → Reference Mode, if available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("iPad Tip")
                }
                
                Section("Opalite") {
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
                }
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
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Loads of additional features!")
        }
    }

    // MARK: - Actions

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

    private func exportColorsToPDF() {
        #if canImport(UIKit)
        do {
            _ = try colorManager.fetchColors()
            _ = try colorManager.fetchPalettes()
            let url = try PortfolioPDFExporter.export(
                palettes: colorManager.palettes,
                looseColors: colorManager.looseColors,
                userName: userName
            )
            exportPDFURL = IdentifiableURL(url: url)
        } catch {
            print("Failed to export PDF: \(error)")
        }
        #else
        // PDF export requires UIKit.
        #endif
    }
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
        .environment(ToastManager())
}

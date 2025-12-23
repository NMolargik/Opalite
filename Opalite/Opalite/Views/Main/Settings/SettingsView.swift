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

    @AppStorage("userName") private var userName: String = "User"
    @AppStorage("appTheme") private var appThemeRaw: String = AppThemeOption.system.rawValue

    @State private var isShowingDeleteAllColorsAlert: Bool = false
    @State private var isShowingDeleteAllCanvasesAlert: Bool = false
    @State private var isShowingInsertSamplesAlert: Bool = false
    @State private var isShowingPaywall: Bool = false

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
                    if subscriptionManager.hasOnyxEntitlement {
                        HStack {
                            Label("Onyx", systemImage: "inset.filled.oval")
                                .foregroundStyle(.primary)
                            
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
                            isShowingPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to Onyx", systemImage: "inset.filled.oval")
                                    .foregroundStyle(.inverseTheme)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.inverseTheme)
                            }
                        }
                    }

                    Button {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Subscription")
                }

                Section {
                    Button {
                        isShowingInsertSamplesAlert = true
                    } label: {
                        Label("Insert Sample Data", systemImage: "tray.and.arrow.down")
                            .foregroundStyle(.blue)
                    }

                    Button {
                        if subscriptionManager.hasOnyxEntitlement {
                            exportColorsToPDF()
                        } else {
                            isShowingPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Export Portfolio to PDF", systemImage: "doc.richtext")
                                .foregroundStyle(.blue)
                            if !subscriptionManager.hasOnyxEntitlement {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export includes your current colors and palettes.")
                }

                Section {
                    Button(role: .destructive) {
                        isShowingDeleteAllCanvasesAlert = true
                    } label: {
                        Label("Delete All Canvases", systemImage: "document.on.trash")
                            .foregroundStyle(.red)
                    }
                    
                    Button(role: .destructive) {
                        isShowingDeleteAllColorsAlert = true
                    } label: {
                        Label("Delete All Colors & Palettes", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("These actions cannot be undone.")
                }

                Section {
                    Text("On iPad Pro, colors may appear more accurate by enabling Settings → Display & Brightness → Advanced → Reference Mode")
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
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .confirm) {
                do {
                    try colorManager.loadSamples()
                    try canvasManager.loadSamples()
                } catch {
                    print("Failed to load samples: \(error)")
                }
            }
        } message: {
            Text("This will insert sample colors and palettes into your portfolio.")
        }
        .alert("Delete All Colors & Palettes?", isPresented: $isShowingDeleteAllColorsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAllColorsAndPalettes()
            }
        } message: {
            Text("This will permanently delete all Opalite colors and palettes. This action cannot be undone.")
        }
        .alert("Delete All Canvases?", isPresented: $isShowingDeleteAllCanvasesAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
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

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

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppThemeOption.system.rawValue

    @State private var isShowingDeleteAllColorsAlert: Bool = false
    @State private var isShowingDeleteAllCanvasesAlert: Bool = false

    @State private var exportPDFURL: URL? = nil
    @State private var isShowingExportSheet: Bool = false
    
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
                    HStack {
                        Label("Display Name", systemImage: "person")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
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
                    Button {
                        do {
                            try colorManager.loadSamples()
                            try canvasManager.loadSamples()
                        } catch {
                            print("Failed to load samples: \(error)")
                        }
                    } label: {
                        Label("Insert Sample Data", systemImage: "tray.and.arrow.down")
                            .foregroundStyle(.blue)
                    }

                    Button {
                        exportColorsToPDF()
                    } label: {
                        Label("Export Colors to PDF", systemImage: "doc.richtext")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export includes your current colors.")
                }

                Section {
                    Button(role: .destructive) {
                        isShowingDeleteAllColorsAlert = true
                    } label: {
                        Label("Delete All Colors & Palettes", systemImage: "trash")
                            .foregroundStyle(.red)
                    }

                    Button(role: .destructive) {
                        isShowingDeleteAllCanvasesAlert = true
                    } label: {
                        Label("Delete All Canvases", systemImage: "trash.slash")
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
        .sheet(isPresented: $isShowingExportSheet) {
            if let url = exportPDFURL {
                ShareSheet(items: [url])
            }
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
            let url = try ColorsPDFExporter.export(colors: colorManager.colors)
            exportPDFURL = url
            isShowingExportSheet = true
        } catch {
            print("Failed to export PDF: \(error)")
        }
        #else
        // PDF export requires UIKit.
        #endif
    }
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
}

// MARK: - PDF Export
#if canImport(UIKit)
enum ColorsPDFExporter {
    enum ExportError: Error {
        case couldNotWrite
    }

    static func export(colors: [OpaliteColor]) throws -> URL {
        let filename = "Opalite Colors \(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @ 72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            // Title
            let title = "Opalite Colors"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22)
            ]
            title.draw(at: CGPoint(x: 36, y: 28), withAttributes: titleAttrs)

            // Layout
            var y: CGFloat = 70
            let rowHeight: CGFloat = 30
            let swatchSize: CGFloat = 18
            let leftX: CGFloat = 36

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.secondaryLabel
            ]

            let sorted = colors.sorted { (a, b) in
                let an = (a.name ?? "Untitled")
                let bn = (b.name ?? "Untitled")
                return an.localizedCaseInsensitiveCompare(bn) == .orderedAscending
            }

            for c in sorted {
                if y + rowHeight > pageRect.height - 36 {
                    ctx.beginPage()
                    y = 36
                }

                // Swatch
                let swatchRect = CGRect(x: leftX, y: y + 6, width: swatchSize, height: swatchSize)
                let ui = c.swiftUIColor.uiColor
                ui.setFill()
                UIBezierPath(roundedRect: swatchRect, cornerRadius: 4).fill()
                UIColor.separator.setStroke()
                UIBezierPath(roundedRect: swatchRect, cornerRadius: 4).stroke()

                // Name
                let name = c.name ?? "Untitled"
                name.draw(at: CGPoint(x: leftX + swatchSize + 10, y: y + 6), withAttributes: nameAttrs)

                // RGBA
                let rgba = String(format: "R %.0f  G %.0f  B %.0f  A %.0f",
                                  c.red * 255, c.green * 255, c.blue * 255, c.alpha * 255)
                rgba.draw(at: CGPoint(x: leftX + swatchSize + 10, y: y + 18), withAttributes: metaAttrs)

                y += rowHeight
            }
        }

        do {
            try data.write(to: url)
            return url
        } catch {
            throw ExportError.couldNotWrite
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif

// MARK: - UIKit bridging for SwiftUI Color

#if canImport(UIKit)
private extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}
#endif

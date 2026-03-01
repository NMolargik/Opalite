//
//  ColorExportSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

struct ColorExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CommunityManager.self) private var communityManager

    let color: OpaliteColor

    @State private var selectedFormat: ColorExportFormat?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareFileURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingFileSave = false
    @State private var isShowingPaywall = false
    @State private var isShowingPublishSheet = false

    private var shareFormats: [ColorExportFormat] {
        [.image, .ase, .procreate, .gpl, .css, .swiftui]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SwatchView(
                        color: color,
                        height: 100,
                        badgeText: color.name ?? color.hexString,
                        showOverlays: true
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Choose Share Format")
                        .font(.headline)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 12) {
                        // Save To File
                        SaveToFileButton(
                            description: "Save as a native Opalite color file.",
                            isExporting: isExporting && selectedFormat == .opalite
                        ) {
                            exportOpaliteFile()
                        }

                        // Publish to Community
                        PublishToCommunityButton(isOffline: !communityManager.isConnectedToNetwork) {
                            isShowingPublishSheet = true
                        }

                        // Share formats
                        ForEach(shareFormats) { format in
                            ExportFormatButton(
                                format: format,
                                hasOnyx: subscriptionManager.hasOnyxEntitlement,
                                isExporting: isExporting,
                                selectedFormat: selectedFormat
                            ) {
                                if !format.isFreeFormat && !subscriptionManager.hasOnyxEntitlement {
                                    isShowingPaywall = true
                                } else {
                                    exportColor(in: format)
                                }
                            }
                        }
                    }

                    if let error = exportError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Share Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
                }
            }
        }
        .background(
            FileShareSheetPresenter(fileURL: shareFileURL, isPresented: $isShowingShareSheet)
        )
        .background(
            FileSavePresenter(fileURL: shareFileURL, isPresented: $isShowingFileSave) {
                dismiss()
            }
        )
        .onChange(of: isShowingShareSheet) { _, isShowing in
            if !isShowing && shareFileURL != nil {
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Data file export requires Onyx")
        }
        .sheet(isPresented: $isShowingPublishSheet) {
            PublishColorSheet(color: color)
        }
    }

    // MARK: - Export Actions

    private func exportOpaliteFile() {
        selectedFormat = .opalite
        isExporting = true
        exportError = nil

        Task {
            do {
                let url = try SharingService.exportColor(color, format: .opalite)
                await MainActor.run {
                    shareFileURL = url
                    #if targetEnvironment(macCatalyst)
                    isShowingFileSave = true
                    #else
                    isShowingShareSheet = true
                    #endif
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }

    private func exportColor(in format: ColorExportFormat) {
        selectedFormat = format
        isExporting = true
        exportError = nil

        Task {
            do {
                let url = try SharingService.exportColor(color, format: format)
                await MainActor.run {
                    shareFileURL = url
                    isShowingShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
}

#Preview("Export Sheet") {
    ColorExportSheet(
        color: OpaliteColor(
            name: "Ocean Blue",
            red: 0.2,
            green: 0.5,
            blue: 0.8,
            alpha: 1.0
        )
    )
    .environment(SubscriptionManager())
    .environment(CommunityManager())
}

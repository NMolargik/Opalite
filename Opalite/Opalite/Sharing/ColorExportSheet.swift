//
//  ColorExportSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

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
    @State private var isShowingPaywall = false
    @State private var isShowingPublishSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview of the color being exported
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

                    VStack(spacing: 12) {
                        // Publish to Community option
                        publishToCommunityButton

                        Divider()
                            .padding(.vertical, 4)

                        ForEach(ColorExportFormat.allCases) { format in
                            formatButton(for: format)
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
        .onChange(of: isShowingShareSheet) { _, isShowing in
            if !isShowing && shareFileURL != nil {
                // Share sheet was dismissed, close the export sheet
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

    // MARK: - Publish to Community Button

    @ViewBuilder
    private var publishToCommunityButton: some View {
        let isOffline = !communityManager.isConnectedToNetwork

        Button {
            HapticsManager.shared.selection()
            isShowingPublishSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOffline ? "wifi.slash" : "person.2")
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(isOffline ? Color.secondary : Color.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Publish to Community")
                        .font(.headline)
                        .foregroundStyle(isOffline ? Color.secondary : Color.primary)

                    Text(isOffline ? "Requires internet connection" : "Share with the Opalite community")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isOffline)
    }

    @ViewBuilder
    private func formatButton(for format: ColorExportFormat) -> some View {
        let isFreeFormat = format == .opalite || format == .image
        let requiresOnyx = !isFreeFormat && !subscriptionManager.hasOnyxEntitlement

        Button {
            HapticsManager.shared.selection()
            if requiresOnyx {
                isShowingPaywall = true
            } else {
                exportColor(in: format)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: format.icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(iconColor(for: format))

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(format.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if requiresOnyx {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(format.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isExporting && selectedFormat == format {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .accessibilityLabel(format.displayName)
        .accessibilityHint(requiresOnyx ? "Requires Onyx subscription" : format.description)
    }

    private func iconColor(for format: ColorExportFormat) -> Color {
        switch format {
        case .image: return .cyan
        case .opalite: return .purple
        case .ase: return .red
        case .procreate: return .orange
        case .gpl: return .green
        case .css: return .blue
        case .swiftui: return .orange
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

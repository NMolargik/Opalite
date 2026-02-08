//
//  PaletteExportSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

struct PaletteExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(CommunityManager.self) private var communityManager

    let palette: OpalitePalette

    @State private var selectedFormat: PaletteExportFormat?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareFileURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingPaywall = false
    @State private var isShowingPublishSheet = false

    private var currentBackground: PreviewBackground {
        palette.previewBackground ?? PreviewBackground.defaultFor(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview of the palette being exported
                    palettePreview

                    // Color count
                    Text("\(palette.colors?.count ?? 0) colors")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Choose Share Format")
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        // Publish to Community option
                        publishToCommunityButton

                        Divider()
                            .padding(.vertical, 4)

                        ForEach(PaletteExportFormat.allCases) { format in
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
            .navigationTitle("Share Palette")
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
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Data file export requires Onyx")
        }
        .sheet(isPresented: $isShowingPublishSheet) {
            PublishPaletteSheet(palette: palette)
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
    private func formatButton(for format: PaletteExportFormat) -> some View {
        let isFreeFormat = format == .opalite || format == .image || format == .pdf
        let requiresOnyx = !isFreeFormat && !subscriptionManager.hasOnyxEntitlement

        Button {
            HapticsManager.shared.selection()
            if requiresOnyx {
                isShowingPaywall = true
            } else {
                exportPalette(in: format)
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

    private func iconColor(for format: PaletteExportFormat) -> Color {
        switch format {
        case .image: return .cyan
        case .pdf: return .red
        case .opalite: return .purple
        case .ase: return .red
        case .procreate: return .orange
        case .gpl: return .green
        case .css: return .blue
        case .swiftui: return .orange
        }
    }

    private func exportPalette(in format: PaletteExportFormat) {
        selectedFormat = format
        isExporting = true
        exportError = nil

        Task {
            do {
                let url = try SharingService.exportPalette(palette, format: format)
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

    // MARK: - Palette Preview

    private let previewHeight: CGFloat = 140
    private let previewPadding: CGFloat = 12

    @ViewBuilder
    private var palettePreview: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (previewPadding * 2)
            let availableHeight = previewHeight - (previewPadding * 2) - 44 // Account for name badge
            let colors = palette.sortedColors
            let layout = PalettePreviewLayoutInfo.calculate(
                colorCount: colors.count,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentBackground.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.thinMaterial, lineWidth: 3)
                    )

                // Color swatches grid
                if colors.isEmpty {
                    Text("This palette is empty")
                        .foregroundStyle(currentBackground.idealTextColor.opacity(0.6))
                        .font(.subheadline)
                } else {
                    VStack(spacing: layout.verticalSpacing) {
                        ForEach(0..<layout.rows, id: \.self) { row in
                            HStack(spacing: layout.horizontalSpacing) {
                                ForEach(0..<layout.columns, id: \.self) { col in
                                    let index = row * layout.columns + col
                                    if index < colors.count {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(colors[index].swiftUIColor)
                                            .frame(width: layout.swatchSize, height: layout.swatchSize)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .strokeBorder(.black.opacity(0.1), lineWidth: 1)
                                            )
                                    } else {
                                        Color.clear
                                            .frame(width: layout.swatchSize, height: layout.swatchSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Text(palette.name)
                .bold()
                .foregroundStyle(currentBackground.idealTextColor)
                .padding(8)
                .glassIfAvailable(GlassConfiguration(style: .clear))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(8)
        }
        .frame(height: previewHeight)
    }

}

#Preview("Export Palette Sheet") {
    PaletteExportSheet(palette: OpalitePalette.sample)
        .environment(SubscriptionManager())
        .environment(CommunityManager())
}

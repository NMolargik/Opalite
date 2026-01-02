//
//  PaletteExportSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

struct PaletteExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    let palette: OpalitePalette

    @State private var selectedFormat: PaletteExportFormat?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareFileURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview of the palette being exported
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: (palette.colors ?? []).map { $0.swiftUIColor }),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 100)
                        .overlay(alignment: .topLeading) {
                            Text(palette.name)
                                .bold()
                                .foregroundStyle((palette.colors?.first)?.idealTextColor() ?? .black)
                                .padding(12)
                                .glassIfAvailable(GlassConfiguration(style: .clear))
                                .padding(8)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.thinMaterial, lineWidth: 3)
                        )

                    // Color count
                    Text("\(palette.colors?.count ?? 0) colors")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Choose Export Format")
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
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
            .navigationTitle("Export Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
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
    }

    @ViewBuilder
    private func formatButton(for format: PaletteExportFormat) -> some View {
        let isFreeFormat = format == .opalite || format == .image
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
}

#Preview("Export Palette Sheet") {
    PaletteExportSheet(palette: OpalitePalette.sample)
        .environment(SubscriptionManager())
}

//
//  CommunityPaletteDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct CommunityPaletteDetailView: View {
    let initialPalette: CommunityPalette

    @Environment(CommunityManager.self) private var communityManager

    /// Returns the current palette from the manager (with loaded colors) or falls back to initial
    private var palette: CommunityPalette {
        communityManager.palettes.first(where: { $0.id == initialPalette.id }) ?? initialPalette
    }
    @Environment(ColorManager.self) private var colorManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingPaywall = false
    @State private var isShowingReportSheet = false
    @State private var isShowingRemoveConfirmation = false

    private var isOwnContent: Bool {
        communityManager.currentUserRecordID != nil &&
        palette.publisherUserRecordID == communityManager.currentUserRecordID
    }

    // Color blindness simulation
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var colorBlindnessMode: ColorBlindnessMode {
        ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Hero Preview (PalettePreviewView-style)
                heroPalettePreview
                    .padding(.horizontal)
                    .padding(.top)
                    .overlay(alignment: .bottom) {
                        CommunityPaletteInfoTilesRow(palette: palette)
                            .padding(.horizontal, 30)
                            .offset(y: 45)
                            .zIndex(1)
                    }

                Spacer(minLength: 80)

                // MARK: - Content Sections
                VStack(spacing: 20) {
                    // Notes section (read-only)
                    if let notes = palette.notes, !notes.isEmpty {
                        CommunityNotesSectionView(notes: notes)
                    }

                    // Publisher section
                    publisherSection
                }
                .padding(.horizontal)
                .padding(.top, -20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Palette")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Save to Portfolio button
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticsManager.shared.selection()
                    saveToPortfolio()
                } label: {
                    Label("Save to Portfolio", systemImage: "square.and.arrow.down")
                }
                .tint(.teal)
                .disabled(palette.colors.isEmpty)
                .accessibilityLabel("Save palette to portfolio")
                .accessibilityHint("Saves this palette from Community to your portfolio")
            }

            // More menu
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Palette info section
                    Section("Palette Info") {
                        Label("\(palette.colorCount) colors", systemImage: "swatchpalette")
                        Label("Published \(formattedDate(palette.publishedAt))", systemImage: "globe")
                        Label("By \(palette.publisherName)", systemImage: "person")
                    }

                    if !palette.tags.isEmpty {
                        Section("Tags") {
                            ForEach(palette.tags, id: \.self) { tag in
                                Label(tag, systemImage: "tag")
                            }
                        }
                    }

                    if isOwnContent {
                        Section {
                            Button(role: .destructive) {
                                HapticsManager.shared.selection()
                                isShowingRemoveConfirmation = true
                            } label: {
                                Label("Remove From Community", systemImage: "trash")
                            }
                        }
                    } else {
                        Section {
                            Button(role: .destructive) {
                                HapticsManager.shared.selection()
                                isShowingReportSheet = true
                            } label: {
                                Label("Report", systemImage: "flag")
                            }
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .toolbarButtonTint()
            }
        }
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Save palettes from the community to your portfolio!")
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportItemSheet(recordID: palette.id, itemType: .palette)
        }
        .alert("Remove From Community", isPresented: $isShowingRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                removeFromCommunity()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This palette will be permanently removed from the Community. This action cannot be undone.")
        }
    }

    // MARK: - Hero Palette Preview

    private var heroPalettePreview: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 32
            let availableHeight: CGFloat = 250
            let colors = palette.colors
            let layout = calculateLayout(
                colorCount: colors.count,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.thinMaterial, lineWidth: 3)
                    )

                // Color swatches grid
                if colors.isEmpty {
                    Text("Mixing Colors...")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    VStack(spacing: layout.verticalSpacing) {
                        ForEach(0..<layout.rows, id: \.self) { row in
                            let startIndex = row * layout.columns
                            let endIndex = min(startIndex + layout.columns, colors.count)

                            HStack {
                                Spacer(minLength: 0)
                                HStack(spacing: layout.horizontalSpacing) {
                                    ForEach(startIndex..<endIndex, id: \.self) { index in
                                        let color = colors[index]
                                        communitySwatchCell(for: color, size: layout.swatchSize, showBadge: layout.showBadges)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                // Name badge
                Text(palette.name)
                    .foregroundStyle(.primary)
                    .bold()
                    .frame(height: 20)
                    .padding(8)
                    .glassIfAvailable(GlassConfiguration(style: .clear))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(10)
            }
        }
        .frame(height: 300)
    }

    @ViewBuilder
    private func communitySwatchCell(for color: CommunityColor, size: CGFloat, showBadge: Bool) -> some View {
        // Create a temporary OpaliteColor for SwatchView display
        let opaliteColor = OpaliteColor(
            name: color.name,
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )

        NavigationLink(value: CommunityNavigationNode.colorDetail(color)) {
            SwatchView(
                color: opaliteColor,
                width: size,
                height: size,
                badgeText: showBadge ? (color.name ?? color.hexString) : "",
                showOverlays: showBadge
            )
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }


    // MARK: - Publisher Section

    private var publisherSection: some View {
        SectionCard(title: "Publisher", systemImage: "person") {
            NavigationLink(value: CommunityNavigationNode.publisherProfile(palette.publisherUserRecordID, palette.publisherName)) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(palette.publisherName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("View profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func saveToPortfolio() {
        guard subscriptionManager.hasOnyxEntitlement else {
            isShowingPaywall = true
            return
        }

        Task {
            do {
                try await communityManager.savePaletteToPortfolio(palette, colorManager: colorManager, subscriptionManager: subscriptionManager)
                await MainActor.run {
                    toastManager.showSuccess("Saved to Portfolio")
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    toastManager.show(error: error)
                }
            } catch {
                await MainActor.run {
                    toastManager.show(error: .unknownError(error.localizedDescription))
                }
            }
        }
    }

    private func removeFromCommunity() {
        Task {
            do {
                try await communityManager.unpublishPalette(recordID: palette.id)
                await MainActor.run {
                    toastManager.showSuccess("Removed from Community")
                    dismiss()
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    toastManager.show(error: error)
                }
            } catch {
                await MainActor.run {
                    toastManager.show(error: .unknownError(error.localizedDescription))
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Layout Calculation

    private struct LayoutInfo {
        let rows: Int
        let columns: Int
        let swatchSize: CGFloat
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat
        let showBadges: Bool
    }

    private func calculateLayout(
        colorCount: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> LayoutInfo {
        guard colorCount > 0 else {
            return LayoutInfo(rows: 0, columns: 0, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0, showBadges: false)
        }

        let minSpacing: CGFloat = 8
        let maxSpacing: CGFloat = 16
        let extraVerticalPadding: CGFloat = 44

        let adjustedHeight = availableHeight - (extraVerticalPadding * 2)

        var bestLayout = LayoutInfo(rows: 1, columns: 1, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0, showBadges: false)

        for rows in 1...3 {
            let columns = Int(ceil(Double(colorCount) / Double(rows)))

            let verticalSpacing: CGFloat = rows > 1 ? minSpacing : 0
            let totalVerticalSpacing = CGFloat(rows - 1) * verticalSpacing

            let horizontalSpacing: CGFloat = columns > 1 ? minSpacing : 0
            let totalHorizontalSpacing = CGFloat(columns - 1) * maxSpacing

            let maxHeightPerSwatch = (adjustedHeight - totalVerticalSpacing) / CGFloat(rows)
            let maxWidthPerSwatch = (availableWidth - totalHorizontalSpacing) / CGFloat(columns)

            let swatchSize = min(maxWidthPerSwatch, maxHeightPerSwatch)

            var actualHorizontalSpacing = horizontalSpacing
            if columns > 1 {
                let usedWidth = CGFloat(columns) * swatchSize
                actualHorizontalSpacing = (availableWidth - usedWidth) / CGFloat(columns - 1)
                actualHorizontalSpacing = min(actualHorizontalSpacing, maxSpacing)
            }

            if swatchSize > bestLayout.swatchSize {
                bestLayout = LayoutInfo(
                    rows: rows,
                    columns: columns,
                    swatchSize: swatchSize,
                    horizontalSpacing: actualHorizontalSpacing,
                    verticalSpacing: verticalSpacing,
                    showBadges: swatchSize >= 110 && horizontalSizeClass != .compact
                )
            }
        }

        return bestLayout
    }
}

// MARK: - Palette Info Tiles Row

private struct CommunityPaletteInfoTilesRow: View {
    let palette: CommunityPalette

    var body: some View {
        HStack(spacing: 12) {
            InfoTileView(
                icon: "swatchpalette.fill",
                value: "\(palette.colorCount)",
                label: "Colors",
                maxWidth: 200,
                glassStyle: .regular,
                lineLimit: 2,
                minimumScaleFactor: 0.7
            )

            InfoTileView(
                icon: "person.fill",
                value: palette.publisherName,
                label: "Publisher",
                maxWidth: 200,
                glassStyle: .regular
            )

            InfoTileView(
                icon: "person.2",
                value: palette.publishedAt.formattedShortDate,
                label: "Published",
                maxWidth: 200,
                glassStyle: .regular,
                lineLimit: 2,
                minimumScaleFactor: 0.7
            )
        }
    }
}

#Preview {
    NavigationStack {
        CommunityPaletteDetailView(initialPalette: CommunityPalette.sample)
    }
    .environment(CommunityManager())
    .environment(ColorManager(context: try! ModelContainer(for: OpaliteColor.self, OpalitePalette.self, CanvasFile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
    .environment(SubscriptionManager())
    .environment(ToastManager())
}

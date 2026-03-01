//
//  TVPaletteDetailView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Read-only palette detail view for tvOS.
/// Displays palette colors in a grid with navigation to individual color details.
struct TVPaletteDetailView: View {
    let palette: OpalitePalette

    @State private var selectedTab: PaletteDetailTab = .colors

    /// Fixed swatch size for tvOS
    private let swatchSize: SwatchSize = .medium

    private var gridColumns: [GridItem] {
        // Fixed 4-column grid for tvOS
        return Array(repeating: GridItem(.flexible(), spacing: 60), count: 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with palette preview (tap strip to present)
            HStack(spacing: 24) {
                // Palette color strip preview - tappable to present
                if let colors = palette.colors, !colors.isEmpty {
                    NavigationLink(destination: TVPresentationModeView(colors: palette.sortedColors, startIndex: 0)) {
                        HStack(spacing: 3) {
                            ForEach(palette.sortedColors.prefix(8)) { color in
                                Rectangle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 24, height: 60)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    }
                    .accessibilityLabel("Present \(palette.name) as slideshow")
                    .accessibilityHint("Displays palette colors in full screen presentation mode")
                } else {
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 24, height: 60)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(palette.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Text("\(palette.colors?.count ?? 0) colors")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)

            // Tab Selector
            Picker("Tab", selection: $selectedTab) {
                ForEach(PaletteDetailTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
            .padding(.horizontal, 48)
            .accessibilityLabel("Detail section")
            .accessibilityValue(selectedTab.title)

            Divider()
                .padding(.horizontal, 48)
                .accessibilityHidden(true)

            // Tab Content
            ScrollView {
                switch selectedTab {
                case .colors:
                    colorsGridContent
                case .info:
                    paletteInfoContent
                case .notes:
                    paletteNotesContent
                }
            }
        }
    }

    // MARK: - Colors Grid

    @ViewBuilder
    private var colorsGridContent: some View {
        if let colors = palette.colors, !colors.isEmpty {
            LazyVGrid(columns: gridColumns, spacing: 60) {
                ForEach(palette.sortedColors) { color in
                    TVSwatchView(color: color, size: swatchSize)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
        } else {
            ContentUnavailableView(
                "No Colors",
                systemImage: "paintpalette",
                description: Text("This palette doesn't have any colors yet.")
            )
            .padding(.top, 60)
        }
    }

    // MARK: - Info Tab

    @ViewBuilder
    private var paletteInfoContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            TVInfoRowView(label: "Name", value: palette.name)
            TVInfoRowView(label: "Colors", value: "\(palette.colors?.count ?? 0)")

            if let author = palette.createdByDisplayName {
                TVInfoRowView(label: "Created By", value: author)
            }

            TVInfoRowView(label: "Created", value: palette.createdAt.formatted(date: .abbreviated, time: .omitted))
            TVInfoRowView(label: "Updated", value: palette.updatedAt.formatted(date: .abbreviated, time: .omitted))

            if !palette.tags.isEmpty {
                TVInfoRowView(label: "Tags", value: palette.tags.joined(separator: ", "))
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 40)
    }

    // MARK: - Notes Tab

    @ViewBuilder
    private var paletteNotesContent: some View {
        if let notes = palette.notes, !notes.isEmpty {
            Text(notes)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 48)
        } else {
            Text("No notes for this palette.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 48)
        }
    }
}

// MARK: - Tab Enum

enum PaletteDetailTab: CaseIterable {
    case colors
    case info
    case notes

    var title: String {
        switch self {
        case .colors: return "Colors"
        case .info: return "Info"
        case .notes: return "Notes"
        }
    }
}

#Preview {
    NavigationStack {
        TVPaletteDetailView(palette: OpalitePalette.sample)
    }
}

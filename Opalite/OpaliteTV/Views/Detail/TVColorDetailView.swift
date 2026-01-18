//
//  TVColorDetailView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Read-only color detail view for tvOS.
/// Displays color info, harmonies, and notes in a TV-optimized layout.
struct TVColorDetailView: View {
    let color: OpaliteColor

    @State private var selectedTab: ColorDetailTab = .info

    var body: some View {
        HStack(alignment: .top, spacing: 60) {
            // Left: Large Color Swatch (tap to present)
            VStack(spacing: 24) {
                NavigationLink(destination: TVPresentationModeView(colors: [color], startIndex: 0)) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(color.swiftUIColor)
                        .frame(width: 400, height: 400)
                        .shadow(color: color.swiftUIColor.opacity(0.4), radius: 30)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundStyle(color.idealTextColor().opacity(0.6))
                                        .padding(16)
                                }
                            }
                        )
                }

                VStack(spacing: 8) {
                    if let name = color.name, !name.isEmpty {
                        Text(name)
                            .font(.title)
                            .fontWeight(.bold)
                    }

                    Text(color.hexString)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 60)

            // Right: Tab Content
            VStack(alignment: .leading, spacing: 24) {
                // Tab Selector
                Picker("Tab", selection: $selectedTab) {
                    ForEach(ColorDetailTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)

                Divider()

                // Tab Content
                ScrollView {
                    switch selectedTab {
                    case .info:
                        colorInfoContent
                    case .harmonies:
                        colorHarmoniesContent
                    case .notes:
                        colorNotesContent
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 60)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Info Tab

    @ViewBuilder
    private var colorInfoContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            TVInfoRowView(label: "Hex", value: color.hexString)
            TVInfoRowView(label: "RGB", value: color.rgbString)
            TVInfoRowView(label: "HSL", value: color.hslString)

            Divider()
                .padding(.vertical, 8)

            if let author = color.createdByDisplayName {
                TVInfoRowView(label: "Created By", value: author)
            }

            TVInfoRowView(label: "Created", value: color.createdAt.formatted(date: .abbreviated, time: .omitted))
            TVInfoRowView(label: "Updated", value: color.updatedAt.formatted(date: .abbreviated, time: .omitted))

            if let device = color.createdOnDeviceName {
                TVInfoRowView(label: "Created On", value: device)
            }
        }
        .padding(.trailing, 40)
    }

    // MARK: - Harmonies Tab

    @ViewBuilder
    private var colorHarmoniesContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            TVColorHarmonyRowView(
                title: "Complementary",
                colors: [color.complementaryColor()]
            )

            TVColorHarmonyRowView(
                title: "Analogous",
                colors: color.analogousColors()
            )

            TVColorHarmonyRowView(
                title: "Triadic",
                colors: color.triadicColors()
            )

            TVColorHarmonyRowView(
                title: "Split-Complementary",
                colors: color.splitComplementaryColors()
            )

            TVColorHarmonyRowView(
                title: "Tetradic",
                colors: color.tetradicColors()
            )
        }
        .padding(.trailing, 40)
    }

    // MARK: - Notes Tab

    @ViewBuilder
    private var colorNotesContent: some View {
        if let notes = color.notes, !notes.isEmpty {
            Text(notes)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        } else {
            Text("No notes for this color.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Tab Enum

enum ColorDetailTab: CaseIterable {
    case info
    case harmonies
    case notes

    var title: String {
        switch self {
        case .info: return "Info"
        case .harmonies: return "Other"
        case .notes: return "Notes"
        }
    }
}

// MARK: - Color Harmony Row

struct TVColorHarmonyRowView: View {
    let title: String
    let colors: [OpaliteColor]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                ForEach(colors.indices, id: \.self) { index in
                    let harmonyColor = colors[index]
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(harmonyColor.swiftUIColor)
                            .frame(width: 80, height: 80)
                            .shadow(color: harmonyColor.swiftUIColor.opacity(0.3), radius: 8)

                        Text(harmonyColor.hexString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TVColorDetailView(color: OpaliteColor.sample)
    }
}

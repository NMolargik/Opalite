//
//  ColorDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct ColorDetailView: View {
    let color: OpaliteColor

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isDetailsExpanded: Bool = true

    // MARK: - Derived Properties
    private var displayTitle: String {
        if let name = color.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return color.hexString
    }

    private var swatchColor: Color { color.swiftUIColor }

    private var createdAtText: String {
        color.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var updatedAtText: String {
        color.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var createdByText: String { color.createdByDisplayName ?? "—" }
    private var createdOnDeviceText: String { color.createdOnDeviceName ?? "—" }
    private var updatedOnDeviceText: String { color.updatedOnDeviceName ?? "—" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Large Swatch
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(swatchColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay(alignment: .bottomTrailing) {
                        // Hex overlay chip
                        Text(color.hexString)
                            .font(.headline)
                            .monospaced()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThickMaterial, in: Capsule())
                            .padding(12)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)

                // Details Section
                Group {
                    if horizontalSizeClass == .compact {
                        DisclosureGroup(isExpanded: $isDetailsExpanded) {
                            VStack(alignment: .leading, spacing: 12) {
                                DetailRow(label: "Created By", systemImage: "person", value: createdByText)
                                DetailRow(label: "Created On", systemImage: "desktopcomputer", value: createdOnDeviceText)
                                DetailRow(label: "Created At", systemImage: "calendar", value: createdAtText)

                                Divider().padding(.vertical, 4)

                                DetailRow(label: "Updated At", systemImage: "clock.arrow.circlepath", value: updatedAtText)
                                DetailRow(label: "Updated On", systemImage: "laptopcomputer", value: updatedOnDeviceText)
                            }
                        } label: {
                            SectionHeader(title: "Details", systemImage: "info.circle")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Details", systemImage: "info.circle")

                            DetailRow(label: "Created By", systemImage: "person", value: createdByText)
                            DetailRow(label: "Created On", systemImage: "desktopcomputer", value: createdOnDeviceText)
                            DetailRow(label: "Created At", systemImage: "calendar", value: createdAtText)

                            Divider().padding(.vertical, 4)

                            DetailRow(label: "Updated At", systemImage: "clock.arrow.circlepath", value: updatedAtText)
                            DetailRow(label: "Updated On", systemImage: "laptopcomputer", value: updatedOnDeviceText)
                        }
                    }
                }
                .padding(16)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                )
                
                // Complementary Colors
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Complementary", systemImage: "arrow.triangle.2.circlepath")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach([color.complementaryColor()], id: \.id) { comp in
                                ColorTile(color: comp)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                )

                // Harmonious Colors
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Harmonious", systemImage: "heart.fill")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(color.harmoniousColors(), id: \.id) { harm in
                                ColorTile(color: harm)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                )

                Spacer(minLength: 8)
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    // TODO: Edit action
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.titleOnly)
                }
                
                Button {
                    // TODO: Name action
                } label: {
                    Label("Name", systemImage: "character.cursor.ibeam")
                }
                
                Button {
                    // TODO: Hashtag action
                } label: {
                    Label("Hashtag", systemImage: "number")
                }
                
                Button {
                    // TODO: Share action
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Subviews
private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.bottom, 4)
    }
}

private struct DetailRow: View {
    let label: String
    let systemImage: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct ColorTile: View {
    let color: OpaliteColor

    private var title: String {
        if let name = color.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return color.hexString
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(color.swiftUIColor)
            .frame(width: 130, height: 130)
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.caption).bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThickMaterial, in: Capsule())
                    .padding(8)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 6)
    }
}

#Preview {
    ColorDetailView(color: OpaliteColor.sample)
}

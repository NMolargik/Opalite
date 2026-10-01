//
//  PublishPaletteSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

struct PublishPaletteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CommunityManager.self) private var communityManager
    @Environment(ToastManager.self) private var toastManager

    let palette: OpalitePalette

    @State private var isPublishing = false
    @State private var publishError: String?

    private var currentBackground: PreviewBackground {
        palette.previewBackground ?? PreviewBackground.defaultFor(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Palette Preview
                    palettePreview
                        .padding(.horizontal)

                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share this palette with the Opalite community!")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(icon: "person.fill", title: "Publisher Name", value: communityManager.publisherName)
                            InfoRow(icon: "paintpalette.fill", title: "Colors", value: "\(palette.colors?.count ?? 0)")
                            InfoRow(icon: "calendar", title: "Created", value: palette.createdAt.formatted(date: .abbreviated, time: .omitted))
                            if !palette.tags.isEmpty {
                                InfoRow(icon: "tag.fill", title: "Tags", value: palette.tags.joined(separator: ", "))
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Guidelines
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Community Guidelines")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Please ensure your content follows our community guidelines. All colors in this palette will also be published. Inappropriate content may be removed and your account may be restricted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Publish Button
                    Button {
                        HapticsManager.shared.selection()
                        publishPalette()
                    } label: {
                        HStack {
                            if isPublishing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.2")
                            }
                            Text(isPublishing ? "Publishing..." : "Publish to Community")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPublishing ? Color.gray : Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isPublishing || !communityManager.isUserSignedIn)
                    .padding(.horizontal)

                    if let error = publishError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if !communityManager.isUserSignedIn {
                        Text("Sign in to iCloud in Settings to publish")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Publish Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
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
            let availableHeight = previewHeight - (previewPadding * 2) - 44
            let colors = palette.sortedColors
            let layout = calculatePreviewLayout(
                colorCount: colors.count,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentBackground.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.thinMaterial, lineWidth: 3)
                    )

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

    private struct PreviewLayoutInfo {
        let rows: Int
        let columns: Int
        let swatchSize: CGFloat
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat
    }

    private func calculatePreviewLayout(
        colorCount: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> PreviewLayoutInfo {
        guard colorCount > 0 else {
            return PreviewLayoutInfo(rows: 0, columns: 0, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0)
        }

        let minSpacing: CGFloat = 6
        let maxSpacing: CGFloat = 12

        var bestLayout = PreviewLayoutInfo(rows: 1, columns: 1, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0)

        for rows in 1...2 {
            let columns = Int(ceil(Double(colorCount) / Double(rows)))

            let verticalSpacing: CGFloat = rows > 1 ? minSpacing : 0
            let totalVerticalSpacing = CGFloat(rows - 1) * verticalSpacing

            let horizontalSpacing: CGFloat = columns > 1 ? minSpacing : 0
            let totalHorizontalSpacing = CGFloat(columns - 1) * maxSpacing

            let maxHeightPerSwatch = (availableHeight - totalVerticalSpacing) / CGFloat(rows)
            let maxWidthPerSwatch = (availableWidth - totalHorizontalSpacing) / CGFloat(columns)

            let swatchSize = min(maxWidthPerSwatch, maxHeightPerSwatch)

            var actualHorizontalSpacing = horizontalSpacing
            if columns > 1 {
                let usedWidth = CGFloat(columns) * swatchSize
                actualHorizontalSpacing = (availableWidth - usedWidth) / CGFloat(columns - 1)
                actualHorizontalSpacing = min(actualHorizontalSpacing, maxSpacing)
            }

            if swatchSize > bestLayout.swatchSize {
                bestLayout = PreviewLayoutInfo(
                    rows: rows,
                    columns: columns,
                    swatchSize: swatchSize,
                    horizontalSpacing: actualHorizontalSpacing,
                    verticalSpacing: verticalSpacing
                )
            }
        }

        return bestLayout
    }

    private func publishPalette() {
        isPublishing = true
        publishError = nil

        Task {
            do {
                _ = try await communityManager.publishPalette(palette)
                await MainActor.run {
                    toastManager.showSuccess("Published to Community!")
                    dismiss()
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    publishError = error.errorDescription
                    isPublishing = false
                }
            } catch {
                await MainActor.run {
                    publishError = error.localizedDescription
                    isPublishing = false
                }
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .font(.subheadline)
    }
}

#Preview {
    PublishPaletteSheet(palette: OpalitePalette.sample)
        .environment(CommunityManager())
        .environment(ToastManager())
}

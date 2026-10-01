//
//  CommunityCards.swift
//  OpaliteFeatureCommunity
//
//  The feed's cards. A color card is a large swatch with its name badge and a publisher
//  chip; a palette card is a multi-swatch preview with name, count, and tags. Both are
//  plain content — the grid wraps them in `NavigationLink`s and context menus. Skeleton
//  variants stand in while the first page loads.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

// MARK: - Color card

struct CommunityColorCard: View {
    let color: CommunityColor

    @ScaledMetric(relativeTo: .body) private var swatchHeight: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommunitySwatch(color: color, badgeFont: .subheadline.weight(.semibold))
                .frame(height: swatchHeight)
                .padding(Brand.Space.xs)

            VStack(alignment: .leading, spacing: 2) {
                Text(color.hexString)
                    .font(.footnote.monospaced().weight(.medium))
                    .foregroundStyle(.primary)
                CommunityPublisherChip(name: color.publisherName)
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.top, Brand.Space.sm)
            .padding(.bottom, Brand.Space.md)
        }
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(color.displayName), \(color.hexString), by \(color.publisherName)"))
        .accessibilityHint(Text("Opens the color"))
    }
}

// MARK: - Palette card

struct CommunityPaletteCard: View {
    let palette: CommunityPalette

    @ScaledMetric(relativeTo: .body) private var previewHeight: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            CommunityPalettePreview(colors: palette.colors, colorCount: palette.colorCount, hasLoadedColors: palette.hasLoadedColors, maxRows: 1)
                .frame(height: previewHeight)
                .padding(.horizontal, Brand.Space.md)
                .padding(.top, Brand.Space.md)

            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
                    Text(palette.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Label {
                        Text("\(palette.colorCount)")
                            .contentTransition(.numericText())
                    } icon: {
                        Image(systemName: "swatchpalette")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("\(palette.colorCount) colors"))
                }

                CommunityPublisherChip(name: palette.publisherName)

                if !palette.tags.isEmpty {
                    CommunityTagRow(tags: palette.tags, limit: 4)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.bottom, Brand.Space.lg)
        }
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(palette.name), \(palette.colorCount) colors, by \(palette.publisherName)"))
        .accessibilityHint(Text("Opens the palette"))
    }
}

// MARK: - Publisher chip & tags

struct CommunityPublisherChip: View {
    let name: String

    var body: some View {
        Label(name, systemImage: "person.crop.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .symbolRenderingMode(.hierarchical)
    }
}

struct CommunityTagRow: View {
    let tags: [String]
    var limit = 4

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.xs) {
                ForEach(tags.prefix(limit), id: \.self) { tag in
                    CommunityTagChip(tag: tag)
                }
                if tags.count > limit {
                    Text("+\(tags.count - limit)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Tags: \(tags.joined(separator: ", "))"))
    }
}

struct CommunityTagChip: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, Brand.Space.sm)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Color.opalitePurple.opacity(0.18)))
            .foregroundStyle(.primary)
    }
}

// MARK: - Skeletons

struct CommunitySkeletonCard: View {
    let segment: CommunitySegment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var colorHeight: CGFloat = 132
    @ScaledMetric(relativeTo: .body) private var paletteHeight: CGFloat = 112
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous)
                .fill(.quaternary)
                .frame(height: segment == .colors ? colorHeight : paletteHeight)
            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Capsule().fill(.quaternary).frame(width: 90, height: 12)
                Capsule().fill(.quaternary).frame(width: 60, height: 10)
            }
            .padding(.horizontal, Brand.Space.sm)
            .padding(.bottom, Brand.Space.sm)
        }
        .padding(Brand.Space.xs)
        .cardSurface()
        .opacity(pulse ? 0.55 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { if !reduceMotion { pulse = true } }
        .accessibilityHidden(true)
    }
}

// MARK: - Loading footer

/// The tasteful end-of-list loader: a spinner with a caption, which asks for the next
/// page as soon as it scrolls into view.
struct CommunityLoadingFooter: View {
    let onAppear: () async -> Void

    var body: some View {
        HStack(spacing: Brand.Space.md) {
            ProgressView()
                .controlSize(.small)
            Text("Loading more…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.Space.xl)
        .task { await onAppear() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Loading more"))
    }
}

#if DEBUG
#Preview("Cards") {
    ScrollView {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                CommunityColorCard(color: .sample)
                CommunityColorCard(color: .sample2)
            }
            CommunityPaletteCard(palette: .sample)
            HStack(spacing: 16) {
                CommunitySkeletonCard(segment: .colors)
                CommunitySkeletonCard(segment: .colors)
            }
            CommunityLoadingFooter {}
        }
        .padding()
    }
    .background(groupedBackground)
}
#endif
#endif

//
//  Components.swift
//  OpaliteDesignSystem
//
//  Reusable content components shared across features: the collapsible section card,
//  detail rows, info tiles, hex badges, the checkerboard for translucent colors, the
//  Onyx badge, empty states, and a flow layout for tags.
//

import SwiftUI
import OpaliteCore

// MARK: - SectionCard

/// A titled, collapsible card on the secondary grouped background. Detail screens are
/// built from stacks of these; collapsed state persists per section via `isExpanded`.
public struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    let systemImage: String?
    let tint: Color
    @Binding var isExpanded: Bool
    let trailing: () -> Trailing
    let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ title: String,
        systemImage: String? = nil,
        tint: Color = .opalitePurple,
        isExpanded: Binding<Bool>,
        @ContentBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ContentBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self._isExpanded = isExpanded
        self.trailing = trailing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 22)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    trailing()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Brand.Space.lg)
                .padding(.vertical, Brand.Space.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
            .accessibilityHint(Text("Double-tap to \(isExpanded ? "collapse" : "expand")"))

            if isExpanded {
                content()
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.bottom, Brand.Space.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }
}

// MARK: - DetailRow

/// A labeled row with a copyable value and an optional icon.
public struct DetailRow: View {
    let title: String
    let value: String
    let systemImage: String?
    let monospaced: Bool
    let onCopy: (() -> Void)?

    public init(_ title: String, value: String, systemImage: String? = nil, monospaced: Bool = false, onCopy: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.monospaced = monospaced
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
            }
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: Brand.Space.sm)
            Text(value)
                .font(monospaced ? .body.monospaced() : .body)
                .multilineTextAlignment(.trailing)
                .selectableText()
            if let onCopy {
                Button {
                    Haptics.lightImpact()
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Copy \(title)"))
            }
        }
        .padding(.vertical, Brand.Space.xs)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - InfoTile

/// A compact stat tile: icon, caption, value. Bounces its icon when the value changes.
public struct InfoTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    @State private var bounce = false

    public init(title: String, value: String, systemImage: String, tint: Color = .opalitePurple) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint.gradient)
                    .symbolEffect(.bounce, options: .repeat(1), value: bounce)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Brand.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        .onChange(of: value) { bounce.toggle() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - HexBadge

/// The small capsule that labels a swatch with its name or hex, legible over any color.
public struct HexBadge: View {
    let text: String
    let onDark: Bool
    let font: Font

    public init(_ text: String, onDark: Bool, font: Font = .caption.weight(.semibold)) {
        self.text = text
        self.onDark = onDark
        self.font = font
    }

    public var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(onDark ? .white : .black)
            .padding(.horizontal, Brand.Space.sm)
            .padding(.vertical, Brand.Space.xs)
            .background(Capsule(style: .continuous).fill((onDark ? Color.black : Color.white).opacity(0.28)))
    }
}

// MARK: - Checkerboard

/// The transparency checkerboard shown behind translucent colors.
public struct Checkerboard: View {
    let squareSize: CGFloat

    public init(squareSize: CGFloat = 8) { self.squareSize = squareSize }

    public var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * squareSize, y: CGFloat(row) * squareSize, width: squareSize, height: squareSize)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.35)))
                }
            }
        }
        .background(Color.white.opacity(0.8))
        .accessibilityHidden(true)
    }
}

// MARK: - Onyx badge

/// The lock/gem marker on Onyx-gated features.
public struct OnyxBadge: View {
    let compact: Bool

    public init(compact: Bool = false) { self.compact = compact }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill")
                .font(.caption2)
            if !compact {
                Text("Onyx")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(LinearGradient.onyx))
        .accessibilityLabel(Text("Requires Onyx"))
    }
}

// MARK: - Empty state

/// `ContentUnavailableView` with the app's primary action treatment.
public struct EmptyStateView<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String
    let actions: () -> Actions

    public init(_ title: String, systemImage: String, description: String, @ContentBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .symbolRenderingMode(.hierarchical)
        } description: {
            Text(description)
        } actions: {
            actions()
        }
    }
}

// MARK: - FlowLayout

/// Wraps subviews onto new rows as they overflow (tag chips).
public struct FlowLayout: Layout {
    let spacing: CGFloat

    public init(spacing: CGFloat = Brand.Space.sm) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Color chip

/// A small rounded swatch of a raw color value (harmony rows, tints & shades, previews).
public struct ColorChip: View {
    let rgba: RGBA
    let size: CGFloat
    let cornerRadius: CGFloat
    let label: String?

    public init(_ rgba: RGBA, size: CGFloat = 44, cornerRadius: CGFloat = Brand.Radius.chip, label: String? = nil) {
        self.rgba = rgba
        self.size = size
        self.cornerRadius = cornerRadius
        self.label = label
    }

    public var body: some View {
        VStack(spacing: Brand.Space.xs) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(rgba.color)
                .frame(width: size, height: size)
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.quaternary))
            if let label {
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label ?? rgba.hexString))
    }
}

#if DEBUG && !os(watchOS)
#Preview("Components") {
    struct Preview: View {
        @State private var expanded = true
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCard("Details", systemImage: "info.circle", isExpanded: $expanded) {
                        DetailRow("Hex", value: "#3380CC", monospaced: true) {}
                        DetailRow("RGB", value: "rgb(51, 128, 204)", monospaced: true)
                    }
                    HStack {
                        InfoTile(title: "Colors", value: "24", systemImage: "paintpalette.fill")
                        InfoTile(title: "Palettes", value: "3", systemImage: "swatchpalette.fill", tint: .opaliteBlue)
                    }
                    HStack {
                        ColorChip(RGBA(red: 0.2, green: 0.5, blue: 0.8), label: "#3380CC")
                        OnyxBadge()
                        HexBadge("#3380CC", onDark: true)
                    }
                }
                .padding()
            }
            .background(groupedBackground)
        }
    }
    return Preview()
}
#endif


extension View {
    /// `textSelection(.enabled)` where the platform supports it.
    @ContentBuilder
    func selectableText() -> some View {
        #if os(tvOS) || os(watchOS)
        self
        #else
        textSelection(.enabled)
        #endif
    }
}

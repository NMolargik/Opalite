//
//  CanvasSwatchPickerView.swift
//  OpaliteFeatureCanvas
//
//  The ink strip: a horizontal row of the user's swatches (filterable to one palette,
//  defaulting to the canvas's linked palette) that sets the drawing color on tap.
//

import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct CanvasSwatchPickerView: View {
    private let preferredPaletteID: UUID?
    private let selected: RGBA?
    private let onPick: (RGBA) -> Void

    /// - Parameters:
    ///   - preferredPaletteID: The palette to show first (the canvas's linked palette).
    ///   - selected: The current ink, marked with a ring.
    ///   - onPick: Called with the tapped swatch's color.
    public init(preferredPaletteID: UUID? = nil, selected: RGBA? = nil, onPick: @escaping (RGBA) -> Void) {
        self.preferredPaletteID = preferredPaletteID
        self.selected = selected
        self.onPick = onPick
    }

    public var body: some View {
        #if os(iOS) || os(visionOS)
        SwatchStrip(preferredPaletteID: preferredPaletteID, selected: selected, onPick: onPick)
        #else
        EmptyView()
        #endif
    }
}

#if os(iOS) || os(visionOS)
private struct SwatchStrip: View {
    enum Filter: Hashable {
        case all
        case loose
        case palette(UUID)
    }

    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var swatchSide: CGFloat = 36

    let preferredPaletteID: UUID?
    let selected: RGBA?
    let onPick: (RGBA) -> Void

    @State private var filter: Filter?

    private var effectiveFilter: Filter {
        if let filter { return filter }
        if let preferredPaletteID, portfolio.palette(withID: preferredPaletteID) != nil { return .palette(preferredPaletteID) }
        return .all
    }

    private var colors: [OpaliteColor] {
        switch effectiveFilter {
        case .all: portfolio.looseColors + portfolio.orderedPalettes.flatMap(\.sortedColors)
        case .loose: portfolio.looseColors
        case .palette(let id): portfolio.palette(withID: id)?.sortedColors ?? []
        }
    }

    private var filterTitle: String {
        switch effectiveFilter {
        case .all: String(localized: "All Colors")
        case .loose: String(localized: "Loose Colors")
        case .palette(let id): portfolio.palette(withID: id)?.name ?? String(localized: "Palette")
        }
    }

    var body: some View {
        HStack(spacing: Brand.Space.sm) {
            filterMenu
            if colors.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: Brand.Space.sm) {
                        ForEach(colors) { color in
                            swatch(color)
                        }
                    }
                    .padding(.horizontal, Brand.Space.xs)
                    .padding(.vertical, Brand.Space.xs)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                // A horizontal scroll view still takes every point of height it's offered;
                // the strip is an overlay, so pin it to one row of swatches.
                .frame(height: swatchSide + Brand.Space.xs * 2)
            }
        }
        .padding(.horizontal, Brand.Space.sm)
        .padding(.vertical, Brand.Space.xs)
        .adaptiveGlassCapsule()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Ink colors"))
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: Binding(get: { effectiveFilter }, set: { filter = $0 })) {
                Label("All Colors", systemImage: "circle.hexagongrid").tag(Filter.all)
                if !portfolio.looseColors.isEmpty {
                    Label("Loose Colors", systemImage: "circle.dotted").tag(Filter.loose)
                }
                ForEach(portfolio.orderedPalettes) { palette in
                    Label(palette.name, systemImage: palette.id == preferredPaletteID ? "link" : "swatchpalette").tag(Filter.palette(palette.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .frame(width: swatchSide, height: swatchSide)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .toolbarButtonTint()
        .accessibilityLabel(Text("Filter swatches"))
        .accessibilityValue(Text(filterTitle))
        .hoverHighlight()
    }

    private var emptyState: some View {
        HStack(spacing: Brand.Space.sm) {
            Text("No colors yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Add Color") {
                Haptics.lightImpact()
                router.present(.colorEditor)
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, Brand.Space.sm)
        .frame(height: swatchSide)
    }

    private func swatch(_ color: OpaliteColor) -> some View {
        let isSelected = selected == color.rgba
        return Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { onPick(color.rgba) }
        } label: {
            ZStack {
                if color.alpha < 1 { Checkerboard(squareSize: 6) }
                RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                    .fill(color.swiftUIColor)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color.idealTextColor())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: swatchSide, height: swatchSide)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(isSelected ? Color.opalitePurple : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1))
            .scaleEffect(isSelected ? 1.08 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityLabel(Text("\(color.displayName), \(color.hexString)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("Sets the ink color"))
        .accessibilityIdentifier("canvas.swatch.\(color.hexString)")
    }
}

#if DEBUG
#Preview("Swatch picker") {
    CanvasSwatchPickerView(selected: RGBA(red: 0.35, green: 0.55, blue: 0.30)) { _ in }
        .padding()
        .previewEnvironment()
}
#endif
#endif

//
//  TVComponents.swift
//  OpaliteFeatureTV
//
//  Small building blocks shared by the TV screens: focusable readout tiles, the palette
//  strip, section headers, harmony rows and the color-blindness-aware swatch fill.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - Color-blindness simulation

/// The simulation mode the user chose in Settings; swatches everywhere render through it.
struct TVSimulation {
    let mode: ColorBlindnessMode

    init(raw: String) { mode = ColorBlindnessMode(rawValue: raw) ?? .off }

    func color(_ rgba: RGBA) -> Color { ColorBlindnessSimulator.simulate(rgba, mode: mode).color }
    func idealTextColor(_ rgba: RGBA) -> Color { ColorBlindnessSimulator.simulate(rgba, mode: mode).idealTextColor }
}

// MARK: - Swatch fill

/// A color fill with a checkerboard behind translucent colors and a hairline edge.
struct TVSwatchFill: View {
    let rgba: RGBA
    let cornerRadius: CGFloat
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var simulationRaw = ColorBlindnessMode.off.rawValue

    init(_ rgba: RGBA, cornerRadius: CGFloat = Brand.Radius.swatch) {
        self.rgba = rgba
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if rgba.alpha < 1 {
                Checkerboard(squareSize: 14).clipShape(shape)
            }
            shape.fill(TVSimulation(raw: simulationRaw).color(rgba))
            shape.strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Focus

extension View {
    /// Makes static content a focus stop so the Siri Remote can scroll to it, with the
    /// system highlight so the stop is visible.
    func tvFocusStop() -> some View {
        self
            .focusable()
            .hoverEffect(.highlight)
    }
}

// MARK: - Readout tile

/// A large-type label/value tile for hex, RGB, HSL and friends.
struct TVReadoutTile: View {
    let title: String
    let value: String
    var monospaced = true

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .title3.monospaced() : .title3)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Brand.Space.xl)
        .adaptiveGlass(cornerRadius: Brand.Radius.card)
        .tvFocusStop()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title), \(value)"))
    }
}

// MARK: - Palette strip

/// The compact run of a palette's colors used in headers.
struct TVPaletteStrip: View {
    let colors: [RGBA]
    var height: CGFloat = 36
    var segmentWidth: CGFloat = 16
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var simulationRaw = ColorBlindnessMode.off.rawValue

    var body: some View {
        let simulation = TVSimulation(raw: simulationRaw)
        HStack(spacing: 2) {
            if colors.isEmpty {
                Rectangle().fill(.quaternary).frame(width: segmentWidth, height: height)
            }
            ForEach(Array(colors.prefix(8).enumerated()), id: \.offset) { _, rgba in
                Rectangle()
                    .fill(simulation.color(rgba))
                    .frame(width: segmentWidth, height: height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Section header

struct TVSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.md) {
            Text(title)
                .font(.title2.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, TVLayout.gutter)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Harmony row

/// A titled row of derived colors (complementary, analogous…).
struct TVHarmonyRow: View {
    let title: String
    let colors: [RGBA]
    @Environment(HexCopyModel.self) private var hexCopy
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var simulationRaw = ColorBlindnessMode.off.rawValue

    var body: some View {
        let simulation = TVSimulation(raw: simulationRaw)
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(spacing: Brand.Space.lg) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, rgba in
                    VStack(spacing: Brand.Space.xs) {
                        RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                            .fill(simulation.color(rgba))
                            .frame(width: 96, height: 96)
                            .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                        Text(hexCopy.formatted(rgba.hexString))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(title) \(rgba.hexString)"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Brand.Space.xl)
        .adaptiveGlass(cornerRadius: Brand.Radius.card)
        .tvFocusStop()
    }
}

// MARK: - Layout constants

enum TVLayout {
    /// The safe horizontal inset for content on the TV canvas.
    static let gutter: CGFloat = 80
    /// Swatch card side in rows and grids.
    static let cardSide: CGFloat = 220
    /// The hero swatch on detail screens.
    static let heroSide: CGFloat = 440
}

// MARK: - Presentation request

/// A full-screen presentation to start, with a value snapshot of the colors.
struct TVPresentationRequest: Identifiable {
    let id = UUID()
    let deck: TVPresentationDeck

    init(colors: [OpaliteColor], startIndex: Int = 0) {
        deck = TVPresentationDeck(colors: colors.map(TVPresentedColor.init), startIndex: startIndex)
    }
}

extension TVPresentedColor {
    init(_ color: OpaliteColor) {
        self.init(id: color.id, name: color.name, rgba: color.rgba)
    }
}
#endif

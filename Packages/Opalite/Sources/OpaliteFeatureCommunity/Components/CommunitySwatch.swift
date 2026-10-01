//
//  CommunitySwatch.swift
//  OpaliteFeatureCommunity
//
//  The Community's swatch: a rounded fill of a published color with the active
//  color-vision simulation applied, a checkerboard behind translucent colors, and an
//  optional name/hex badge. Cards, palette previews, and detail heroes all build on it.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct CommunitySwatch: View {
    let color: CommunityColor
    var cornerRadius: CGFloat = Brand.Radius.swatch
    var showsBadge = true
    var badgeFont: Font = .caption.weight(.semibold)

    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var mode: ColorBlindnessMode { ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off }
    private var simulated: RGBA { ColorBlindnessSimulator.simulate(color.rgba, mode: mode) }
    private var onDark: Bool { !simulated.prefersDarkText }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if color.alpha < 1 {
                Checkerboard()
            }
            shape.fill(simulated.color)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.quaternary))
        .overlay(alignment: .topLeading) {
            if showsBadge {
                HexBadge(color.displayName, onDark: onDark, font: badgeFont)
                    .padding(Brand.Space.sm)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(color.displayName), \(color.hexString)"))
    }
}

#if DEBUG
#Preview("Swatches") {
    HStack(spacing: 16) {
        CommunitySwatch(color: .sample)
            .frame(width: 160, height: 120)
        CommunitySwatch(color: .sample2, showsBadge: false)
            .frame(width: 80, height: 80)
    }
    .padding()
}
#endif
#endif

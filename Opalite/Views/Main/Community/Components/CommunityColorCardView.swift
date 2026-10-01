//
//  CommunityColorCardView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

/// A color card that matches the SwatchView visual style for Community content
struct CommunityColorCardView: View {
    let color: CommunityColor

    // Color blindness simulation
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var colorBlindnessMode: ColorBlindnessMode {
        ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
    }

    /// Color with color blindness simulation applied (if active)
    private var displayColor: Color {
        color.simulatedSwiftUIColor(colorBlindnessMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // SwatchView-style color swatch
            RoundedRectangle(cornerRadius: 16)
                .fill(displayColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.thinMaterial, lineWidth: 5)
                )
                .frame(height: 120)
                .overlay(alignment: .topLeading) {
                    // Badge with name/hex
                    Text(color.name ?? color.hexString)
                        .foregroundStyle(color.idealTextColor())
                        .bold()
                        .lineLimit(1)
                        .frame(height: 20)
                        .padding(8)
                        .glassIfAvailable(GlassConfiguration(style: .clear))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(8)
                }
                .padding(4)

            // Publisher info below
            HStack {
                Text("by \(color.publisherName)")
                    .font(.caption)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(color.name ?? color.hexString), by \(color.publisherName)")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    CommunityColorCardView(color: CommunityColor.sample)
        .frame(width: 180)
        .padding()
}

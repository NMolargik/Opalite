//
//  InfoTileView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/7/26.
//

import SwiftUI

struct InfoTileView: View {
    let icon: String
    let value: String
    let label: String
    var maxWidth: CGFloat = 220
    var glassStyle: GlassConfiguration.Style = .clear
    var lineLimit: Int = 1
    var minimumScaleFactor: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.inverseTheme)
                .frame(height: 30)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.inverseTheme)
                .lineLimit(lineLimit)
                .minimumScaleFactor(minimumScaleFactor)
                .multilineTextAlignment(.center)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: maxWidth, maxHeight: 85)
        .modifier(GlassTileBackground(style: glassStyle))
    }
}

struct GlassTileBackground: ViewModifier {
    var style: GlassConfiguration.Style = .clear

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            #if os(visionOS)
            // glassEffect is unavailable on visionOS, use material instead
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(radius: 5)
                )
            #else
            switch style {
            case .clear:
                content
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(radius: 5)
            case .regular:
                content
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(radius: 5)
            }
            #endif
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .shadow(radius: 5)
                )
        }
    }
}

#Preview("Info Tiles") {
    HStack {
        InfoTileView(icon: "paintpalette", value: "12", label: "Colors")
        InfoTileView(icon: "calendar", value: "Feb 8", label: "Created", glassStyle: .regular)
    }
    .padding()
}

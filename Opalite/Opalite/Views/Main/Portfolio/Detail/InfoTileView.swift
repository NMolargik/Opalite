//
//  InfoTileView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/7/26.
//

import SwiftUI

struct InfoTileView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var maxWidth: CGFloat = 220
    var glassStyle: GlassConfiguration.Style = .clear
    var lineLimit: Int = 1
    var minimumScaleFactor: CGFloat = 0.8
    var marquee: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(height: 30)

            if marquee {
                MarqueeText(value, font: .subheadline.bold())
                    .foregroundStyle(.primary)
            } else {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.center)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: maxWidth, maxHeight: 85)
        .modifier(GlassTileBackground(style: glassStyle))
    }
}

// MARK: - Marquee Text

/// Scrolling text that loops edge-to-edge when content overflows.
/// Shows two copies of the text side by side so the scroll wraps seamlessly.
struct MarqueeText: View {
    let text: String
    let font: Font

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private let scrollSpeed: Double = 30 // points per second
    private let pauseDuration: Double = 1.5
    private let gap: CGFloat = 40 // space between the two copies

    init(_ text: String, font: Font = .caption.bold()) {
        self.text = text
        self.font = font
    }

    private var overflows: Bool {
        textWidth > containerWidth
    }

    /// Total distance for one loop: text width + gap (so copy B lands where copy A started)
    private var loopDistance: CGFloat {
        textWidth + gap
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: gap) {
                Text(text).font(font).fixedSize()
                if overflows {
                    Text(text).font(font).fixedSize()
                }
            }
            .offset(x: offset)
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .onAppear {
                containerWidth = geo.size.width
            }
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
                resetAnimation()
            }
        }
        .frame(height: 20)
        .background(
            Text(text)
                .font(font)
                .fixedSize()
                .hidden()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    textWidth = newWidth
                    resetAnimation()
                }
        )
        .onChange(of: text) {
            resetAnimation()
        }
    }

    private func resetAnimation() {
        animating = false
        offset = 0

        guard overflows else { return }
        startScrollCycle()
    }

    private func startScrollCycle() {
        guard overflows else { return }
        animating = true

        let duration = loopDistance / scrollSpeed

        // Pause, then scroll left by one full loop distance
        withAnimation(.linear(duration: duration).delay(pauseDuration)) {
            offset = -loopDistance
        } completion: {
            guard animating else { return }
            // Snap back instantly (copy B is now where copy A was)
            offset = 0
            // Continue looping
            startScrollCycle()
        }
    }
}

struct GlassTileBackground: ViewModifier {
    var style: GlassConfiguration.Style = .clear

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
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

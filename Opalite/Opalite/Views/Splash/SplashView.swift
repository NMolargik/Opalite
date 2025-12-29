//
//  SplashView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

// MARK: - Splash View

struct SplashView: View {
    var onContinue: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var showContent: Bool = false
    @State private var showButton: Bool = false
    @State private var pulse: Bool = false

    // Generate row configurations once
    private let rowConfigs: [SwatchRowConfig] = (0..<7).map { index in
        SwatchRowConfig(
            colors: generateRowColors(seed: index),
            scrollsRight: Bool.random(),
            speed: Double.random(in: 18...35),
            swatchHeight: CGFloat.random(in: 60...90)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Scrolling swatch rows
                VStack(spacing: 12) {
                    ForEach(Array(rowConfigs.enumerated()), id: \.offset) { index, config in
                        InfiniteSwatchRow(
                            colors: config.colors,
                            scrollsRight: config.scrollsRight,
                            speed: config.speed,
                            swatchHeight: config.swatchHeight,
                            isAnimating: hasAppeared
                        )
                        .frame(height: config.swatchHeight)
                    }
                }
                .blur(radius: 2)
                .opacity(hasAppeared ? 1 : 0)
                .accessibilityHidden(true)

                // Material overlay
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .ignoresSafeArea()
                    .opacity(showContent ? 0.85 : 0)
                    .accessibilityHidden(true)

                // Content
                VStack(spacing: 32) {
                    Spacer()

                    // App icon / logo area
                    ZStack {
                        // Glow
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue, .green, .yellow, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 40)
                            .opacity(showContent ? 0.8 : 0)
                            .accessibilityHidden(true)

                        // Gem icon
                        Image("gemstone")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .accessibilityLabel("Opalite gemstone")
                            .scaleEffect(pulse ? 1.06 : 0.94)
                            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
                    }
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)

                    // Title and subtitle
                    VStack(spacing: 12) {
                        Text("Opalite")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .accessibilityAddTraits(.isHeader)

                        Text("Color management for all")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.95)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
                    .opacity(showContent ? 1 : 0)
                    .accessibilityElement(children: .combine)

                    Spacer()

                    // Continue button
                    Button {
                        HapticsManager.shared.impact(.medium)
                        onContinue()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.headline)

                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: .white.opacity(0.3), radius: 20, y: 5)
                    }
                    .accessibilityLabel("Continue")
                    .accessibilityHint("Proceeds to app introduction")
                    .scaleEffect(showButton ? 1 : 0.8)
                    .opacity(showButton ? 1 : 0)

                    Spacer()
                        .frame(height: geometry.safeAreaInsets.bottom > 0 ? 40 : 60)
                }
            }
        }
        .onAppear {
            // Start scrolling animation
            withAnimation(.easeOut(duration: 0.8)) {
                hasAppeared = true
            }

            // Show content with delay
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                showContent = true
            }

            // Show button last
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.8)) {
                showButton = true
            }

            // Start pulsing the gemstone once content is shown
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                pulse = true
            }
        }
    }

    // Generate diverse colors for a row with wide variety
    private static func generateRowColors(seed: Int) -> [OpaliteColor] {
        var colors: [OpaliteColor] = []

        for _ in 0..<12 {
            let color = generateRandomColor()
            colors.append(color)
        }

        return colors.shuffled()
    }

    private static func generateRandomColor() -> OpaliteColor {
        // Pick a random color style
        let style = Int.random(in: 0..<10)

        switch style {
        case 0:
            // Neon / Electric - high saturation, high brightness
            let hue = Double.random(in: 0...1)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.9...1.0), b: Double.random(in: 0.95...1.0))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case 1:
            // Pastel / Light - low saturation, high brightness
            let hue = Double.random(in: 0...1)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.15...0.35), b: Double.random(in: 0.9...1.0))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case 2:
            // Dark / Deep - high saturation, low brightness
            let hue = Double.random(in: 0...1)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.6...0.9), b: Double.random(in: 0.25...0.45))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case 3:
            // Earth tones - browns, tans, olives
            let earthHues: [Double] = [0.05, 0.08, 0.1, 0.12, 0.15, 0.25, 0.3] // oranges, yellows, greens
            let hue = earthHues.randomElement()!
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.3...0.6), b: Double.random(in: 0.3...0.6))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case 4:
            // Jewel tones - rich, deep saturated colors
            let jewelHues: [Double] = [0.0, 0.08, 0.45, 0.55, 0.75, 0.85] // ruby, amber, emerald, teal, amethyst, magenta
            let hue = jewelHues.randomElement()!
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.7...0.9), b: Double.random(in: 0.5...0.7))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case 5:
            // Grayscale - pure neutrals
            let gray = Double.random(in: 0.1...0.9)
            return OpaliteColor(red: gray, green: gray, blue: gray, alpha: 1.0)

        case 6:
            // Warm neutrals - off-whites, creams, taupes
            let base = Double.random(in: 0.7...0.95)
            let r = base
            let g = base - Double.random(in: 0.02...0.08)
            let b = base - Double.random(in: 0.05...0.15)
            return OpaliteColor(red: r, green: max(0, g), blue: max(0, b), alpha: 1.0)

        case 7:
            // Cool neutrals - blue-grays, slate
            let base = Double.random(in: 0.3...0.7)
            let r = base - Double.random(in: 0.02...0.08)
            let g = base
            let b = base + Double.random(in: 0.02...0.1)
            return OpaliteColor(red: max(0, r), green: g, blue: min(1, b), alpha: 1.0)

        case 8:
            // Muted / Dusty - medium saturation, medium brightness
            let hue = Double.random(in: 0...1)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.25...0.45), b: Double.random(in: 0.5...0.7))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        default:
            // Vivid / Standard - good saturation and brightness
            let hue = Double.random(in: 0...1)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.6...0.85), b: Double.random(in: 0.7...0.9))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }

    private static func hsbToRGB(h: Double, s: Double, b: Double) -> (Double, Double, Double) {
        let c = b * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c

        var r: Double = 0, g: Double = 0, bl: Double = 0

        switch h * 6 {
        case 0..<1: (r, g, bl) = (c, x, 0)
        case 1..<2: (r, g, bl) = (x, c, 0)
        case 2..<3: (r, g, bl) = (0, c, x)
        case 3..<4: (r, g, bl) = (0, x, c)
        case 4..<5: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }

        return (r + m, g + m, bl + m)
    }
}

// MARK: - Row Configuration

private struct SwatchRowConfig {
    let colors: [OpaliteColor]
    let scrollsRight: Bool
    let speed: Double
    let swatchHeight: CGFloat
}

// MARK: - Infinite Swatch Row

private struct InfiniteSwatchRow: View {
    let colors: [OpaliteColor]
    let scrollsRight: Bool
    let speed: Double // pixels per second
    let swatchHeight: CGFloat
    let isAnimating: Bool

    // Calculate dimensions
    private var swatchWidth: CGFloat { swatchHeight * 1.3 }
    private var spacing: CGFloat { 12 }
    private var setWidth: CGFloat {
        CGFloat(colors.count) * (swatchWidth + spacing)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            // We need enough sets to cover screen + buffer on both sides
            let setsNeeded = Int(ceil(screenWidth / setWidth)) + 3

            TimelineView(.animation) { context in
                // Calculate offset based on elapsed time
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let pixelsPerSecond = setWidth / speed
                let totalOffset = elapsed * pixelsPerSecond

                // Use modulo to create seamless loop
                let normalizedOffset = totalOffset.truncatingRemainder(dividingBy: Double(setWidth))
                let offset: CGFloat = scrollsRight
                    ? CGFloat(normalizedOffset) - setWidth
                    : -CGFloat(normalizedOffset)

                HStack(spacing: spacing) {
                    ForEach(0..<setsNeeded, id: \.self) { _ in
                        HStack(spacing: spacing) {
                            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                                SwatchView(
                                    fill: [color],
                                    width: swatchWidth,
                                    height: swatchHeight,
                                    badgeText: "",
                                    showOverlays: false
                                )
                            }
                        }
                    }
                }
                .offset(x: offset)
            }
        }
        .clipped()
    }
}

#Preview {
    SplashView(
        onContinue: {}
    )
}


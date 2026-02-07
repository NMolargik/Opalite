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
    @State private var glowRotation: Double = 0
    @State private var startAnimations: Bool = false  // Delay heavy animations

    // Generate row configurations once
    private static let rowConfigs: [SwatchRowConfig] = makeRowConfigs()

    private static func makeRowConfigs() -> [SwatchRowConfig] {
        var result: [SwatchRowConfig] = []
        for index in 0..<7 {
            let colors: [OpaliteColor] = generateRowColors(seed: index)
            let scrollsRight: Bool = index.isMultiple(of: 2)
            let speed: Double = Double(18 + (index * 3))
            let swatchHeight: CGFloat = CGFloat(60 + (index % 3) * 15)
            let config = SwatchRowConfig(
                colors: colors,
                scrollsRight: scrollsRight,
                speed: speed,
                swatchHeight: swatchHeight
            )
            result.append(config)
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Scrolling swatch rows - single Canvas for all rows
                SwatchRowsCanvas(
                    configs: Self.rowConfigs,
                    isAnimating: startAnimations
                )
                .blur(radius: 2)
                .opacity(hasAppeared ? 1 : 0)
                .ignoresSafeArea()
                .accessibilityHidden(true)

                // Material overlay
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .ignoresSafeArea()
                    .opacity(showContent ? 0.2 : 0)
                    .accessibilityHidden(true)

                // Content
                VStack(spacing: 32) {
                    Spacer()

                    // App icon / logo area
                    ZStack {
                        // Rotating rainbow glow - opal shimmer effect
                        AngularGradient(
                            colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red, .purple],
                            center: .center,
                            angle: .degrees(glowRotation)
                        )
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .opacity(showContent ? 0.85 : 0)
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
                            .foregroundStyle(.white)
                            .accessibilityAddTraits(.isHeader)

                        Text("The Ultimate Color Manager")
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
            // Fade in the static background first
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }

            // Delay heavy swatch animations to avoid launch stutter
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                startAnimations = true
            }

            // Show content with delay
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showContent = true
            }

            // Show button last
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.7)) {
                showButton = true
            }

            // Start pulsing the gemstone and rotating glow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pulse = true

                // Continuous glow rotation
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    glowRotation = 360
                }
            }
        }
    }

    // Generate colors for a row with theme based on row index
    private static func generateRowColors(seed: Int) -> [OpaliteColor] {
        var colors: [OpaliteColor] = []

        // Each row gets a different color theme for variety
        let theme = RowColorTheme(rawValue: seed % RowColorTheme.allCases.count) ?? .vibrant

        for i in 0..<16 {
            let color = generateThemedColor(theme: theme, index: i)
            colors.append(color)
        }

        return colors.shuffled()
    }

    private enum RowColorTheme: Int, CaseIterable {
        case vibrant      // Bright, saturated rainbow
        case pastel       // Soft, light colors
        case warm         // Reds, oranges, yellows
        case cool         // Blues, greens, purples
        case earth        // Browns, tans, olives
        case jewel        // Deep, rich gemstone colors
        case neutral      // Grays and muted tones
    }

    private static func generateThemedColor(theme: RowColorTheme, index: Int) -> OpaliteColor {
        // Use index to spread hues evenly, with some randomness
        let baseHue = Double(index) / 16.0
        let hueVariation = Double.random(in: -0.05...0.05)

        switch theme {
        case .vibrant:
            // Full spectrum, high saturation
            let hue = (baseHue + hueVariation).truncatingRemainder(dividingBy: 1.0)
            let (r, g, b) = hsbToRGB(h: abs(hue), s: Double.random(in: 0.75...1.0), b: Double.random(in: 0.85...1.0))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case .pastel:
            // Full spectrum, low saturation, high brightness
            let hue = (baseHue + hueVariation).truncatingRemainder(dividingBy: 1.0)
            let (r, g, b) = hsbToRGB(h: abs(hue), s: Double.random(in: 0.2...0.4), b: Double.random(in: 0.9...1.0))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case .warm:
            // Reds, oranges, yellows (hue 0.0 - 0.15)
            let hue = Double.random(in: 0.0...0.12)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.6...1.0), b: Double.random(in: 0.7...1.0))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case .cool:
            // Blues, teals, purples (hue 0.5 - 0.85)
            let hue = Double.random(in: 0.5...0.85)
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.5...0.9), b: Double.random(in: 0.6...1.0))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case .earth:
            // Browns, tans, olives, greens
            let earthHues: [Double] = [0.05, 0.08, 0.1, 0.12, 0.2, 0.25, 0.3, 0.35]
            let hue = earthHues[index % earthHues.count]
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.3...0.7), b: Double.random(in: 0.25...0.65))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case .jewel:
            // Deep, rich colors - ruby, emerald, sapphire, amethyst
            let jewelHues: [Double] = [0.0, 0.08, 0.33, 0.45, 0.55, 0.65, 0.75, 0.85]
            let hue = jewelHues[index % jewelHues.count]
            let (r, g, b) = hsbToRGB(h: hue, s: Double.random(in: 0.7...0.95), b: Double.random(in: 0.4...0.7))
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)

        case .neutral:
            // Grays, warm grays, cool grays
            let style = index % 3
            switch style {
            case 0:
                // Pure gray
                let gray = Double.random(in: 0.2...0.85)
                return OpaliteColor(red: gray, green: gray, blue: gray, alpha: 1.0)
            case 1:
                // Warm gray
                let base = Double.random(in: 0.3...0.8)
                return OpaliteColor(red: base + 0.05, green: base, blue: base - 0.05, alpha: 1.0)
            default:
                // Cool gray
                let base = Double.random(in: 0.3...0.8)
                return OpaliteColor(red: base - 0.03, green: base, blue: base + 0.06, alpha: 1.0)
            }
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

// MARK: - Swatch Rows Canvas

/// Draws all scrolling swatch rows in a single Canvas — one GPU draw call per frame
/// instead of hundreds of individual SwiftUI views with expensive material effects.
private struct SwatchRowsCanvas: View {
    let configs: [SwatchRowConfig]
    let isAnimating: Bool

    private let rowSpacing: CGFloat = 12
    private let swatchSpacing: CGFloat = 12
    private let cornerRadius: CGFloat = 16
    private let borderWidth: CGFloat = 5

    var body: some View {
        if isAnimating {
            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    draw(in: ctx, size: size, date: context.date)
                }
            }
        } else {
            Canvas { ctx, size in
                draw(in: ctx, size: size, date: .now)
            }
        }
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, date: Date) {
        let elapsed = date.timeIntervalSinceReferenceDate
        var y: CGFloat = 0
        var rowIndex = 0

        // Cycle through configs repeatedly until the full height is filled
        while y < size.height {
            let config = configs[rowIndex % configs.count]
            let swatchSize = config.swatchHeight
            let setWidth = CGFloat(config.colors.count) * (swatchSize + swatchSpacing)
            let pixelsPerSecond = setWidth / config.speed

            let totalOffset = elapsed * pixelsPerSecond
            let normalizedOffset = CGFloat(totalOffset.truncatingRemainder(dividingBy: Double(setWidth)))
            let baseOffset = config.scrollsRight
                ? normalizedOffset - setWidth
                : -normalizedOffset

            // Draw enough sets to cover the width
            let setsNeeded = Int(ceil(size.width / setWidth)) + 3
            for setIndex in 0..<setsNeeded {
                let setOffset = CGFloat(setIndex) * setWidth
                for (colorIndex, color) in config.colors.enumerated() {
                    let x = baseOffset + setOffset + CGFloat(colorIndex) * (swatchSize + swatchSpacing)

                    // Skip swatches entirely off-screen
                    if x + swatchSize < 0 || x > size.width { continue }

                    let rect = CGRect(x: x, y: y, width: swatchSize, height: swatchSize)
                    let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

                    // Fill
                    ctx.fill(path, with: .color(Color(red: color.red, green: color.green, blue: color.blue)))

                    // Border
                    ctx.stroke(path, with: .color(.white.opacity(0.15)), lineWidth: borderWidth)
                }
            }

            y += swatchSize + rowSpacing
            rowIndex += 1
        }
    }
}

#Preview {
    SplashView(
        onContinue: {}
    )
}

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
        for index in 0..<12 {
            let colors: [OpaliteColor] = generateRowColors(seed: index)
            let scrollsRight: Bool = index.isMultiple(of: 2)
            let speed: Double = Double(28 + (index * 5))
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
//                // Background
//                Color.black.ignoresSafeArea()

                // Scrolling swatch rows - single Canvas for all rows
                SwatchRowsCanvas(
                    configs: Self.rowConfigs,
                    isAnimating: startAnimations
                )
                .opacity(hasAppeared ? 1 : 0)
                .ignoresSafeArea()
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
                        
                        Image("squares")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .accessibilityLabel("Opalite gemstone sqyaress")
                            .scaleEffect(pulse ? 1.06 : 0.94)
                            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: pulse)

                        // Gem icon
                        Image("gemstone")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .accessibilityLabel("Opalite gemstone")
                            .scaleEffect(pulse ? 1.06 : 0.94)
                            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: pulse)
                    }
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)

                    // Title and subtitle
                    VStack(spacing: 12) {
                        Text("Opalite")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
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
                        #if os(iOS)
                        HapticsManager.shared.impact(.medium)
                        #endif
                        onContinue()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Get Started")

                            Image(systemName: "arrow.right")
                        }
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .shadow(color: .white.opacity(0.3), radius: 20, y: 5)
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
        let theme = RowColorTheme(rawValue: seed % RowColorTheme.allCases.count) ?? .neons

        for i in 0..<16 {
            let color = generateThemedColor(theme: theme, index: i)
            colors.append(color)
        }

        // Don't shuffle - keep colors in gradient order for cohesive palette
        return colors
    }

    private enum RowColorTheme: Int, CaseIterable {
        case neons        // Bright neon colors
        case pinks        // Pink gradient palette
        case earthyGreens // Earth-y greens and browns
        case blues        // Blue gradient palette
        case sunset       // Warm sunset colors
        case purples      // Purple gradient palette
        case oceanic      // Teal, aqua, ocean blues
        case reds         // Red gradient palette
        case pastels      // Soft pastel rainbow
        case autumn       // Autumn oranges, reds, browns
        case mint         // Mint and sage greens
        case monochrome   // Black to white grayscale
    }

    private static func generateThemedColor(theme: RowColorTheme, index: Int) -> OpaliteColor {
        // Progress through the palette (0.0 to 1.0)
        let progress = Double(index) / 15.0
        
        switch theme {
        case .neons:
            // Bright neon colors - electric pinks, greens, yellows, oranges
            let hue = progress * 0.9  // Cycle through most of spectrum
            let (r, g, b) = hsbToRGB(h: hue, s: 1.0, b: 1.0)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .pinks:
            // Pink gradient - from magenta to light pink to coral
            let hue = 0.9 + (progress * 0.1)  // Magenta to red range
            let saturation = 0.95 - (progress * 0.3)  // Decrease saturation
            let brightness = 0.7 + (progress * 0.3)  // Increase brightness
            let (r, g, b) = hsbToRGB(h: hue.truncatingRemainder(dividingBy: 1.0), s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .earthyGreens:
            // Earth-y greens and browns - sage, olive, brown, tan
            let hueRange: [(h: Double, s: Double, b: Double)] = [
                (0.08, 0.45, 0.35),   // Deep brown
                (0.10, 0.40, 0.45),   // Medium brown
                (0.12, 0.35, 0.55),   // Tan
                (0.15, 0.38, 0.50),   // Olive
                (0.25, 0.42, 0.48),   // Moss green
                (0.28, 0.40, 0.52),   // Sage
                (0.30, 0.35, 0.60),   // Light sage
                (0.32, 0.30, 0.68)    // Pale green
            ]
            let segmentIndex = Int(progress * Double(hueRange.count - 1))
            let segmentProgress = (progress * Double(hueRange.count - 1)) - Double(segmentIndex)
            let nextIndex = min(segmentIndex + 1, hueRange.count - 1)
            
            let h = hueRange[segmentIndex].h + (hueRange[nextIndex].h - hueRange[segmentIndex].h) * segmentProgress
            let s = hueRange[segmentIndex].s + (hueRange[nextIndex].s - hueRange[segmentIndex].s) * segmentProgress
            let b = hueRange[segmentIndex].b + (hueRange[nextIndex].b - hueRange[segmentIndex].b) * segmentProgress
            let (r, g, bl) = hsbToRGB(h: h, s: s, b: b)
            return OpaliteColor(red: r, green: g, blue: bl, alpha: 1.0)
        
        case .blues:
            // Blue gradient - navy to sky blue to cyan
            let hue = 0.55 + (progress * 0.08)  // Blue to cyan range
            let saturation = 0.95 - (progress * 0.25)
            let brightness = 0.3 + (progress * 0.7)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .sunset:
            // Warm sunset - deep red to orange to yellow to pink
            let hueStops: [Double] = [0.95, 0.02, 0.08, 0.12, 0.15, 0.92]
            let stopProgress = progress * Double(hueStops.count - 1)
            let stopIndex = Int(stopProgress)
            let nextStopIndex = min(stopIndex + 1, hueStops.count - 1)
            let localProgress = stopProgress - Double(stopIndex)
            
            let hue = hueStops[stopIndex] + (hueStops[nextStopIndex] - hueStops[stopIndex]) * localProgress
            let saturation = 0.85 + (sin(progress * .pi) * 0.15)
            let brightness = 0.75 + (progress * 0.25)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .purples:
            // Purple gradient - deep purple to lavender to lilac
            let hue = 0.72 + (progress * 0.1)  // Purple to magenta range
            let saturation = 0.9 - (progress * 0.4)
            let brightness = 0.4 + (progress * 0.55)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .oceanic:
            // Teal, aqua, ocean blues - tropical ocean palette
            let hue = 0.48 + (progress * 0.12)  // Teal to cyan range
            let saturation = 0.65 + (sin(progress * .pi) * 0.25)
            let brightness = 0.55 + (progress * 0.35)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .reds:
            // Red gradient - burgundy to crimson to rose
            let hue = 0.97 + (progress * 0.06)  // Red to pink-red range
            let saturation = 0.9 - (progress * 0.3)
            let brightness = 0.35 + (progress * 0.55)
            let (r, g, b) = hsbToRGB(h: hue.truncatingRemainder(dividingBy: 1.0), s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .pastels:
            // Soft pastel rainbow - gentle colors across spectrum
            let hue = progress * 0.85  // Cycle through spectrum
            let saturation = 0.25 + (sin(progress * .pi * 2) * 0.1)
            let brightness = 0.92 - (sin(progress * .pi) * 0.05)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .autumn:
            // Autumn oranges, reds, browns - fall foliage
            let hueStops: [Double] = [0.02, 0.05, 0.08, 0.10, 0.06, 0.03]
            let stopProgress = progress * Double(hueStops.count - 1)
            let stopIndex = Int(stopProgress)
            let nextStopIndex = min(stopIndex + 1, hueStops.count - 1)
            let localProgress = stopProgress - Double(stopIndex)
            
            let hue = hueStops[stopIndex] + (hueStops[nextStopIndex] - hueStops[stopIndex]) * localProgress
            let saturation = 0.7 + (sin(progress * .pi) * 0.2)
            let brightness = 0.4 + (progress * 0.35)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .mint:
            // Mint and sage greens - fresh and cool
            let hue = 0.38 + (progress * 0.08)  // Green to cyan-green
            let saturation = 0.45 - (progress * 0.15)
            let brightness = 0.65 + (progress * 0.3)
            let (r, g, b) = hsbToRGB(h: hue, s: saturation, b: brightness)
            return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
        
        case .monochrome:
            // Black to white grayscale
            let gray = progress
            return OpaliteColor(red: gray, green: gray, blue: gray, alpha: 1.0)
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

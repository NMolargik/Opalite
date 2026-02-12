//
//  ColorShufflePickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

struct ColorShufflePickerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var color: OpaliteColor

    @State private var shuffleRotation: Double = 0
    @State private var shuffleScale: Double = 1.0
    @State private var recentColors: [OpaliteColor] = []
    @State private var recentHues: [Double] = []
    @State private var audioPlayer = AudioPlayer()
    @FocusState private var isFocused: Bool

    private let maxRecentColors = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "shuffle")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                Text("Shuffle")
                    .font(.headline)

                Spacer()
            }

            // Card container
            VStack(spacing: 20) {
                Spacer()

                // Main shuffle button
                Button {
                    performShuffle()
                } label: {
                    ZStack {
                        // Background circle with current color
                        shuffleButtonBackground

                        // Shuffle icon
                        Image(systemName: "shuffle")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .rotationEffect(.degrees(shuffleRotation))
                    }
                    .scaleEffect(shuffleScale)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Shuffle to a new random color")
                .accessibilityHint("Double tap to generate a new random color")

                Text(horizontalSizeClass == .regular ? "Tap or press arrow keys to shuffle" : "Tap to shuffle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Recent colors history
                if !recentColors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentColors.reversed()) { recentColor in
                                    Button {
                                        restoreColor(recentColor)
                                    } label: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: recentColor.red, green: recentColor.green, blue: recentColor.blue, opacity: recentColor.alpha))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Restore previous color")
                                }
                            }
                        }
                    }
                }

                // Opacity control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Opacity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Slider(value: $color.alpha, in: 0...1)
                            .accessibilityLabel("Opacity")
                            .accessibilityValue("\(Int(color.alpha * 100)) percent")

                        Text("\(Int(color.alpha * 100))%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(12)
            .frame(maxHeight: horizontalSizeClass == .regular ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(maxHeight: horizontalSizeClass == .regular ? .infinity : nil)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.upArrow) {
            performShuffle()
            return .handled
        }
        .onKeyPress(.downArrow) {
            performShuffle()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            performShuffle()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            performShuffle()
            return .handled
        }
        .onKeyPress(.space) {
            performShuffle()
            return .handled
        }
        .onAppear {
            // Auto-focus when view appears on iPad
            if horizontalSizeClass == .regular {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
        .onChange(of: horizontalSizeClass) { _, newValue in
            if newValue == .regular {
                isFocused = true
            }
        }
    }

    @ViewBuilder
    private var shuffleButtonBackground: some View {
        #if os(visionOS)
        // glassEffect is unavailable on visionOS
        Circle()
            .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
            .frame(width: 160, height: 160)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            Circle()
                .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                .frame(width: 160, height: 160)
                .glassEffect(.regular.interactive().tint(Color(red: color.red, green: color.green, blue: color.blue)))
        } else {
            Circle()
                .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                .frame(width: 160, height: 160)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        }
        #endif
    }

    private func performShuffle() {
        #if os(iOS)
        HapticsManager.shared.impact(.medium)
        #endif

        // Save current color to history before shuffling
        saveToRecent()

        // Animate the button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            shuffleRotation += 360
            shuffleScale = 1.15
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                shuffleScale = 1.0
            }
        }

        // Generate a new random color that's different from the current one
        let newColor = generateShuffledColor()

        withAnimation(.easeInOut(duration: 0.3)) {
            color.red = newColor.red
            color.green = newColor.green
            color.blue = newColor.blue
        }
    }

    private func generateShuffledColor() -> (red: Double, green: Double, blue: Double) {
        // Get current hue to avoid
        let currentHSB = rgbToHSB(r: color.red, g: color.green, b: color.blue)

        // Build list of hues to avoid (current + recent)
        var huesToAvoid = recentHues
        huesToAvoid.append(currentHSB.h)

        // Generate a completely random hue that's far from all recent hues
        var newHue: Double
        var attempts = 0
        repeat {
            newHue = Double.random(in: 0...1)
            attempts += 1
        } while attempts < 50 && huesToAvoid.contains(where: { hueDistance($0, newHue) < 0.15 })

        // Track this hue to avoid repeats
        recentHues.append(newHue)
        if recentHues.count > 5 {
            recentHues.removeFirst()
        }

        // Fully randomize saturation and brightness across wide ranges
        let newSaturation = Double.random(in: 0.6...1.0)
        let newBrightness = Double.random(in: 0.5...1.0)

        // Convert back to RGB
        return hsbToRGB(h: newHue, s: newSaturation, b: newBrightness)
    }

    /// Calculate the shortest distance between two hues on the color wheel (0-0.5)
    private func hueDistance(_ h1: Double, _ h2: Double) -> Double {
        let diff = abs(h1 - h2)
        return min(diff, 1.0 - diff)
    }

    private func saveToRecent() {
        let snapshot = OpaliteColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )

        recentColors.append(snapshot)

        // Keep only the most recent colors
        if recentColors.count > maxRecentColors {
            recentColors.removeFirst()
        }
    }

    private func restoreColor(_ recentColor: OpaliteColor) {
        HapticsManager.shared.impact()

        withAnimation(.easeInOut(duration: 0.2)) {
            color.red = recentColor.red
            color.green = recentColor.green
            color.blue = recentColor.blue
            color.alpha = recentColor.alpha
        }
    }

    // MARK: - Color Conversion Helpers

    private func rgbToHSB(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        var hue: Double = 0
        let saturation: Double = maxC == 0 ? 0 : delta / maxC
        let brightness: Double = maxC

        if delta != 0 {
            if maxC == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                hue = ((b - r) / delta) + 2
            } else {
                hue = ((r - g) / delta) + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }

        return (hue, saturation, brightness)
    }

    private func hsbToRGB(h: Double, s: Double, b: Double) -> (red: Double, green: Double, blue: Double) {
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

private struct ColorShufflePickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorShufflePickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorShufflePickerPreviewContainer()
}

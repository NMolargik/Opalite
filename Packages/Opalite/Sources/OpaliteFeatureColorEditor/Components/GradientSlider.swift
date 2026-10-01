//
//  GradientSlider.swift
//  OpaliteFeatureColorEditor
//
//  A slider whose track is a gradient of what the channel would produce (red from
//  "no red" to "full red" given the other channels, the hue wheel, opacity over a
//  checkerboard). Drag anywhere on the track; arrow keys nudge it on iPad/Mac; VoiceOver
//  gets an adjustable element with the channel's value.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct GradientSlider: View {
    let title: String
    @Binding var value: Double
    let stops: [Color]
    var thumbColor: Color
    var valueText: String
    var showsCheckerboard = false
    /// VoiceOver / keyboard nudge, in the slider's 0...1 space.
    var step: Double = 0.02
    var onEditingChanged: (Bool) -> Void = { _ in }

    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false
    @FocusState private var isFocused: Bool

    private var thumbSize: CGFloat { trackHeight - 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: Brand.Space.sm)
                Text(valueText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .default, value: valueText)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let travel = max(width - thumbSize, 1)
                let thumbX = thumbSize / 2 + ColorMath.clamp(value) * travel

                ZStack(alignment: .leading) {
                    if showsCheckerboard {
                        Checkerboard(squareSize: 6)
                            .clipShape(Capsule(style: .continuous))
                    }
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing))
                    Capsule(style: .continuous)
                        .strokeBorder(.quaternary)
                    if isFocused {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                    }

                    Circle()
                        .fill(thumbColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .frame(width: thumbSize, height: thumbSize)
                        .scaleEffect(isDragging && !reduceMotion ? 1.18 : 1)
                        .position(x: thumbX, y: proxy.size.height / 2)
                        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isDragging)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                onEditingChanged(true)
                            }
                            value = ColorMath.clamp((gesture.location.x - thumbSize / 2) / travel)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: trackHeight)
            .focusable()
            .focused($isFocused)
            .onKeyPress(.leftArrow) { nudge(-step); return .handled }
            .onKeyPress(.rightArrow) { nudge(step); return .handled }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(valueText))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(step)
            case .decrement: nudge(-step)
            @unknown default: break
            }
        }
    }

    private func nudge(_ delta: Double) {
        onEditingChanged(true)
        value = ColorMath.clamp(value + delta)
        onEditingChanged(false)
        Haptics.selection()
    }
}

#if DEBUG
#Preview("Gradient sliders") {
    struct Preview: View {
        @State private var red = 0.4
        @State private var alpha = 0.7
        var body: some View {
            VStack(spacing: 24) {
                GradientSlider(title: "Red", value: $red, stops: [Color(RGBA(red: 0, green: 0.5, blue: 0.8)), Color(RGBA(red: 1, green: 0.5, blue: 0.8))], thumbColor: Color(RGBA(red: red, green: 0.5, blue: 0.8)), valueText: "\(red.byte)")
                GradientSlider(title: "Opacity", value: $alpha, stops: [.blue.opacity(0), .blue], thumbColor: .blue.opacity(alpha), valueText: "\(Int(alpha * 100))%", showsCheckerboard: true)
            }
            .padding()
        }
    }
    return Preview()
}
#endif
#endif

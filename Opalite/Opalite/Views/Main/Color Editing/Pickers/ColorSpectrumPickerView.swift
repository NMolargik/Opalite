//
//  ColorSpectrumPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct ColorSpectrumPickerView: View {
    @Binding var color: OpaliteColor
    @State private var dragLocation: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var hasInitialized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightspectrum.horizontal")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                Text("Spectrum")
                    .font(.headline)

                Spacer()
            }

            // Card container
            VStack(alignment: .leading, spacing: 16) {
                GeometryReader { proxy in
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .red, location: 0.0),
                                .init(color: .yellow, location: 0.17),
                                .init(color: .green, location: 0.33),
                                .init(color: .cyan, location: 0.5),
                                .init(color: .blue, location: 0.67),
                                .init(color: Color(red: 1, green: 0, blue: 1), location: 0.83),
                                .init(color: .red, location: 1.0)
                            ]),
                            startPoint: .leading, endPoint: .trailing
                        )
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .blendMode(.multiply)
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateColor(with: value.location, in: proxy.size)
                                }
                                .onEnded { value in
                                    updateColor(with: value.location, in: proxy.size)
                                }
                        )

                        // Handle
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .background(Circle().fill(Color.clear))
                            .frame(width: 24, height: 24)
                            .position(
                                x: dragLocation.x * proxy.size.width,
                                y: dragLocation.y * proxy.size.height
                            )
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Color spectrum picker")
                .accessibilityValue(currentColorDescription)
                .accessibilityHint("Drag to select a color. Horizontal position changes hue, vertical changes brightness.")
                .accessibilityAdjustableAction { direction in
                    adjustColor(direction: direction)
                }

                // Opacity slider
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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            syncDragLocationFromColor()
        }
        .onChange(of: color.id) { _, _ in
            // Sync when the color binding changes to a different color
            syncDragLocationFromColor()
        }
    }

    private var currentColorDescription: String {
        let hueNames = ["Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Magenta", "Pink", "Red"]
        let hueIndex = Int(dragLocation.x * 9)
        let hueName = hueNames[min(hueIndex, hueNames.count - 1)]
        let brightness = Int((1.0 - dragLocation.y) * 100)
        return "\(hueName), \(brightness)% brightness"
    }

    private func adjustColor(direction: AccessibilityAdjustmentDirection) {
        let step: CGFloat = 0.05
        switch direction {
        case .increment:
            dragLocation.x = min(1.0, dragLocation.x + step)
        case .decrement:
            dragLocation.x = max(0.0, dragLocation.x - step)
        @unknown default:
            break
        }
        let hue = Double(dragLocation.x)
        let brightness = Double(1.0 - dragLocation.y)
        let newColor = Color(hue: hue, saturation: 1.0, brightness: brightness)
        if let rgba = newColor.rgbaComponents {
            color.red = rgba.red
            color.green = rgba.green
            color.blue = rgba.blue
        }
    }

    /// Synchronize dragLocation from the current color's HSB values
    private func syncDragLocationFromColor() {
        let swiftUIColor = color.swiftUIColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
        UIColor(swiftUIColor).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        #elseif canImport(AppKit)
        NSColor(swiftUIColor).usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        #endif

        // Map HSB to picker coordinates:
        // x (hue): 0..1 maps to left..right
        // y (brightness): 0..1 maps to top..bottom (1 - brightness because top is bright)
        dragLocation = CGPoint(x: hue, y: 1.0 - brightness)
    }
    
    private func updateColor(with location: CGPoint, in size: CGSize) {
        let clampedX = max(0, min(size.width, location.x))
        let clampedY = max(0, min(size.height, location.y))
        
        let u = clampedX / max(size.width, 1)
        let v = clampedY / max(size.height, 1)
        
        // Map horizontal position to hue, vertical to brightness
        let hue = Double(u)
        let saturation = 1.0
        let brightness = Double(1.0 - v)
        
        let newSwiftUIColor = Color(hue: hue,
                                    saturation: saturation,
                                    brightness: brightness)
        
        dragLocation = CGPoint(x: u, y: v)
        
        if let rgba = newSwiftUIColor.rgbaComponents {
            color.red = rgba.red
            color.green = rgba.green
            color.blue = rgba.blue
            color.alpha = rgba.alpha
        }
    }
}

private struct ColorSpectrumPickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorSpectrumPickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorSpectrumPickerPreviewContainer()
}

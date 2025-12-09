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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
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
                        // Base rainbow gradient (hue horizontally)
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

                // Opacity slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Opacity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Slider(value: $color.alpha, in: 0...1)

                        Text("\(Int(color.alpha * 100))%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                            .foregroundStyle(.secondary)
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

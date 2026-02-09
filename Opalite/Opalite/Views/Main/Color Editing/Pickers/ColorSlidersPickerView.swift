//
//  ColorChannelsPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct ColorChannelsPickerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var color: OpaliteColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if horizontalSizeClass == .regular {
                Spacer(minLength: 0)
            }

            // Header
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                Text("Color Channels")
                    .font(.headline)

                Spacer()
            }

            // Card container
            VStack(alignment: .leading, spacing: 16) {

                // Red slider
                channelSlider(
                    label: "Red",
                    value: $color.red,
                    tint: Color(
                        red: 1.0,
                        green: color.green,
                        blue: color.blue
                    )
                )

                // Green slider
                channelSlider(
                    label: "Green",
                    value: $color.green,
                    tint: Color(
                        red: color.red,
                        green: 1.0,
                        blue: color.blue
                    )
                )

                // Blue slider
                channelSlider(
                    label: "Blue",
                    value: $color.blue,
                    tint: Color(
                        red: color.red,
                        green: color.green,
                        blue: 1.0
                    )
                )

                // Alpha slider
                channelSlider(
                    label: "Alpha",
                    value: $color.alpha,
                    tint: .black.opacity(0.7)
                )
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

    private func channelSlider(label: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.0f", value.wrappedValue * 255))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: 0...1)
                .tint(tint)
                .accessibilityLabel("\(label) channel")
                .accessibilityValue("\(Int(value.wrappedValue * 255)) of 255")
        }
    }
}

private struct ColorChannelsPickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorChannelsPickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorChannelsPickerPreviewContainer()
}

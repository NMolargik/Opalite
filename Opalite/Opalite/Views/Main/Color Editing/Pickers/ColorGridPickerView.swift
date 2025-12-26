//
//  ColorGridPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct ColorGridPickerView: View {
    @Binding var color: OpaliteColor

    private let rows: Int = 13      // 1 grayscale row + 12 color rows
    private let columns: Int = 10   // more columns for a smoother hue sweep

    var body: some View {
        let gridItems: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                Text("Grid")
                    .font(.headline)

                Spacer()
            }

            // Card container
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: gridItems, spacing: 4) {
                    ForEach(0..<(rows * columns), id: \.self) { index in
                        let row = index / columns
                        let column = index % columns

                        let swatchColor: Color = colorFor(row: row, column: column, rows: rows, columns: columns)
                        let selected: Bool = isColorSelected(swatchColor)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(swatchColor)
                            .frame(height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(
                                        selected ? Color.white : Color.black.opacity(0.15),
                                        lineWidth: selected ? 2 : 1
                                    )
                            )
                            .shadow(color: selected ? Color.black.opacity(0.25) : .clear,
                                    radius: selected ? 2 : 0,
                                    x: 0, y: 0)
                            .onTapGesture {
                                if let rgba = swatchColor.rgbaComponents {
                                    color.red = rgba.red
                                    color.green = rgba.green
                                    color.blue = rgba.blue
                                    color.alpha = rgba.alpha
                                }
                            }
                            .accessibilityLabel(accessibilityLabelFor(row: row, column: column, rows: rows, columns: columns))
                            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint("Double tap to select this color")
                    }
                }

                // Opacity control, similar to system Grid picker
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
    }

    private func colorFor(row: Int, column: Int, rows: Int, columns: Int) -> Color {
        // Row 0: grayscale from white → black
        if row == 0 {
            let t = Double(column) / Double(max(columns - 1, 1))
            let brightness = 1.0 - t
            return Color(white: brightness)
        }

        // Remaining rows: hue across columns, with saturation increasing and brightness decreasing as you go down.
        // This yields multiple rows of distinct, usable colors similar to the system picker.
        let hue = Double(column) / Double(max(columns, 1))

        // Normalize row index into 0...1 across the color rows only (exclude grayscale row)
        let colorRow = Double(row - 1)
        let colorRowCount = Double(max(rows - 1, 1))
        let t = colorRow / colorRowCount // 0 at first color row → 1 at bottom

        // Tuned ranges: start less saturated and bright, get more saturated and darker down the rows
        let saturation = clamp(0.35 + t * 0.55, lower: 0.0, upper: 1.0)   // 0.35 → 0.90
        let brightness = clamp(0.95 - t * 0.45, lower: 0.0, upper: 1.0)   // 0.95 → 0.50

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    // Simple clamp helper for readability
    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        return min(max(value, lower), upper)
    }

    private func isColorSelected(_ swatchColor: Color) -> Bool {
        guard let rgba = swatchColor.rgbaComponents else { return false }
        let epsilon = 0.001
        return abs(rgba.red   - color.red)   < epsilon &&
               abs(rgba.green - color.green) < epsilon &&
               abs(rgba.blue  - color.blue)  < epsilon &&
               abs(rgba.alpha - color.alpha) < epsilon
    }

    private func accessibilityLabelFor(row: Int, column: Int, rows: Int, columns: Int) -> String {
        if row == 0 {
            let t = Double(column) / Double(max(columns - 1, 1))
            let brightness = Int((1.0 - t) * 100)
            return "Gray, \(brightness)% brightness"
        }

        let hueNames = ["Red", "Orange", "Yellow", "Yellow-Green", "Green", "Cyan", "Light Blue", "Blue", "Purple", "Magenta"]
        let hueIndex = column % hueNames.count
        let hueName = hueNames[hueIndex]

        let colorRow = Double(row - 1)
        let colorRowCount = Double(max(rows - 1, 1))
        let t = colorRow / colorRowCount

        let saturation = Int((0.35 + t * 0.55) * 100)
        let brightness = Int((0.95 - t * 0.45) * 100)

        return "\(hueName), \(saturation)% saturation, \(brightness)% brightness"
    }
}

private struct ColorGridPickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorGridPickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorGridPickerPreviewContainer()
}

//
//  TVQuickAddHexSheet.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Sheet for quickly adding a color by entering a hex code on tvOS.
struct TVQuickAddHexSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    @State private var hexInput: String = "#"
    @State private var colorName: String = ""

    private var parsedColor: Color? {
        parseHexColor(hexInput)
    }

    private var isValidHex: Bool {
        parsedColor != nil
    }

    var body: some View {
        VStack(spacing: 40) {
            // Header
            Text("Add Color")
                .font(.title2)
                .fontWeight(.bold)

            // Content
            HStack(spacing: 60) {
                // Left: Color Preview
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(parsedColor ?? Color.secondary.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                        )

                    if isValidHex {
                        Text(hexInput.uppercased())
                            .font(.title3.monospaced())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter hex code")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Right: Input Fields
                VStack(alignment: .leading, spacing: 32) {
                    // Hex Code Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hex Code")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        TextField("e.g. #FF5733", text: $hexInput)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: hexInput) { _, newValue in
                                // Auto-format: ensure # prefix
                                if newValue.isEmpty {
                                    hexInput = "#"
                                } else if !newValue.hasPrefix("#") {
                                    hexInput = "#" + newValue
                                }
                            }
                    }

                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name (Optional)")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        TextField("Color name", text: $colorName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(width: 350)
            }

            // Buttons
            HStack(spacing: 40) {
                Button("Cancel") {
                    dismiss()
                }

                Button("Save Color") {
                    addColor()
                }
                .disabled(!isValidHex)
            }
            .padding(.top, 20)
        }
        .padding(60)
    }

    // MARK: - Actions

    private func addColor() {
        guard let rgba = parseHexToRGBA(hexInput) else {
            toastManager.show(message: "Invalid hex code", style: .error)
            return
        }

        do {
            let name = colorName.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try colorManager.createColor(
                name: name.isEmpty ? nil : name,
                red: rgba.red,
                green: rgba.green,
                blue: rgba.blue,
                alpha: rgba.alpha
            )
            toastManager.showSuccess("Color added: \(hexInput.uppercased())")
            dismiss()
        } catch {
            toastManager.show(error: .colorCreationFailed)
        }
    }

    // MARK: - Hex Parsing

    private func parseHexColor(_ hex: String) -> Color? {
        guard let rgba = parseHexToRGBA(hex) else { return nil }
        return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private func parseHexToRGBA(_ hex: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Remove # prefix if present
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }

        // Need at least 3 characters
        guard hexString.count >= 3 else { return nil }

        // Handle 3-character shorthand (e.g., #FFF -> #FFFFFF)
        if hexString.count == 3 {
            hexString = hexString.map { "\($0)\($0)" }.joined()
        }

        // Handle 6-character hex (RGB)
        if hexString.count == 6 {
            hexString += "FF" // Add full alpha
        }

        // Must be 8 characters now (RRGGBBAA)
        guard hexString.count == 8 else { return nil }

        var rgbaValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbaValue) else { return nil }

        let red = Double((rgbaValue & 0xFF000000) >> 24) / 255.0
        let green = Double((rgbaValue & 0x00FF0000) >> 16) / 255.0
        let blue = Double((rgbaValue & 0x0000FF00) >> 8) / 255.0
        let alpha = Double(rgbaValue & 0x000000FF) / 255.0

        return (red, green, blue, alpha)
    }
}

#Preview {
    TVQuickAddHexSheet()
}

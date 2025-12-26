//
//  ColorCodesPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

struct ColorCodesPickerView: View {
    @Binding var color: OpaliteColor

    @State private var hexInput: String = ""
    @State private var rgbRInput: String = ""
    @State private var rgbGInput: String = ""
    @State private var rgbBInput: String = ""
    @State private var alphaInput: String = ""
    @State private var didCopyHex: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.slash.chevron.right")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Color Codes")
                        .font(.headline)

                    Text("Enter or copy values in common formats.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Card container
            VStack(spacing: 16) {
                // Hex
                VStack(alignment: .leading, spacing: 6) {
                    labelRow(title: "HEX", subtitle: "Copy & paste from design tools")

                    HStack(alignment: .center, spacing: 8) {
                        TextField("#RRGGBB or #RRGGBBAA", text: $hexInput)
                            #if os(iOS) || os(visionOS)
                            .textInputAutocapitalization(.characters)
                            .keyboardType(.asciiCapable)
                            #endif
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: hexInput) { _, newValue in
                                let sanitized = sanitizeHexInput(newValue)
                                if sanitized != newValue {
                                    hexInput = sanitized
                                }
                            }
                            .onSubmit {
                                applyHexInput()
                            }
                            #if os(iOS) || os(visionOS)
                            .submitLabel(.done)
                            #endif
                            .frame(minWidth: 100)
                            .accessibilityLabel("Hex color code")
                            .accessibilityHint("Enter a 6 or 8 character hex code")
                        
                        Spacer()

                        Button {
                            HapticsManager.shared.impact()
                            let hex = color.hexString
                            #if os(iOS) || os(visionOS)
                            UIPasteboard.general.string = hex
                            #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(hex, forType: .string)
                            #endif

                            withAnimation(.easeInOut(duration: 0.2)) {
                                didCopyHex = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    didCopyHex = false
                                }
                            }
                        } label: {
                            if didCopyHex {
                                Label("Copied", systemImage: "checkmark")
                                    .frame(height: 18)
                            } else {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .frame(height: 18)

                            }
                        }
                        .bold()
                        .tint(didCopyHex ? .green : .primary)
                        .buttonStyle(.bordered)
                        #if os(iOS) || os(visionOS)
                        .controlSize(.small)
                        #endif


                        Button("Apply") {
                            HapticsManager.shared.impact()
                            applyHexInput()
                        }
                        .bold()
                        
                        .buttonStyle(.borderedProminent)
                        #if os(iOS) || os(visionOS)
                        .controlSize(.small)
                        #endif
                    }
                }

                Divider().overlay(.white.opacity(0.1))

                // RGB
                VStack(alignment: .leading, spacing: 6) {
                    labelRow(title: "RGB", subtitle: "0–255 per channel")

                    HStack(alignment: .center, spacing: 8) {
                        channelField("R", text: $rgbRInput)
                            .onChange(of: rgbRInput) { _, newValue in
                                let sanitized = sanitizeRGBInput(newValue)
                                if sanitized != newValue {
                                    rgbRInput = sanitized
                                }
                            }
                            .onSubmit {
                                applyRGBInput()
                            }
                            #if os(iOS) || os(visionOS)
                            .submitLabel(.done)
                            #endif

                        channelField("G", text: $rgbGInput)
                            .onChange(of: rgbGInput) { _, newValue in
                                let sanitized = sanitizeRGBInput(newValue)
                                if sanitized != newValue {
                                    rgbGInput = sanitized
                                }
                            }
                            .onSubmit {
                                applyRGBInput()
                            }
                            #if os(iOS) || os(visionOS)
                            .submitLabel(.done)
                            #endif

                        channelField("B", text: $rgbBInput)
                            .onChange(of: rgbBInput) { _, newValue in
                                let sanitized = sanitizeRGBInput(newValue)
                                if sanitized != newValue {
                                    rgbBInput = sanitized
                                }
                            }
                            .onSubmit {
                                applyRGBInput()
                            }
                            #if os(iOS) || os(visionOS)
                            .submitLabel(.done)
                            #endif

                        Spacer()
                        
                        Button("Apply") {
                            HapticsManager.shared.impact()
                            applyRGBInput()
                        }
                        .bold()
                        .buttonStyle(.borderedProminent)
                        #if os(iOS) || os(visionOS)
                        .controlSize(.small)
                        #endif
                    }
                }

                Divider().overlay(.white.opacity(0.1))

                // Alpha (opacity as percentage)
                VStack(alignment: .leading, spacing: 6) {
                    labelRow(title: "OPACITY", subtitle: "0–100%")

                    HStack(alignment: .center, spacing: 8) {
                        TextField("0–100", text: $alphaInput)
                            #if os(iOS) || os(visionOS)
                            .keyboardType(.numberPad)
                            #endif
                            .onSubmit {
                                applyAlphaInput()
                            }
                            #if os(iOS) || os(visionOS)
                            .submitLabel(.done)
                            #endif
                            .multilineTextAlignment(.center)
                            .frame(minWidth: 80)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: alphaInput) { _, newValue in
                                let sanitized = sanitizeAlphaInput(newValue)
                                if sanitized != newValue {
                                    alphaInput = sanitized
                                }
                            }
                            .accessibilityLabel("Opacity percentage")
                            .accessibilityHint("Enter a value from 0 to 100")

                        Spacer()

                        Button("Apply") {
                            HapticsManager.shared.impact()
                            applyAlphaInput()
                        }
                        .bold()
                        .buttonStyle(.borderedProminent)
                        #if os(iOS) || os(visionOS)
                        .controlSize(.small)
                        #endif
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .onAppear {
            syncCodeFieldsFromColor()
        }
    }

    @ViewBuilder
    private func labelRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    private func channelField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField(label, text: text)
                #if os(iOS) || os(visionOS)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .accessibilityLabel("\(label) channel value")
                .accessibilityHint("Enter a value from 0 to 255")
        }
    }

    // MARK: - Input Sanitization

    private func sanitizeHexInput(_ value: String) -> String {
        let allowed = "0123456789ABCDEF"
        let upper = value.uppercased()
        let filtered = upper.filter { allowed.contains($0) }
        return String(filtered.prefix(6))
    }

    private func sanitizeRGBInput(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return String(digits.prefix(3))
    }

    private func sanitizeAlphaInput(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        let trimmed = String(digits.prefix(3))

        // Allow empty while editing
        guard !trimmed.isEmpty else { return "" }

        guard let intVal = Int(trimmed) else { return "" }
        let clamped = min(max(intVal, 0), 100)
        return String(clamped)
    }

    // Sync the code text fields from the current color
    private func syncCodeFieldsFromColor() {
        hexInput = color.hexString.replacingOccurrences(of: "#", with: "").uppercased()

        let r = Int(round(color.red * 255))
        let g = Int(round(color.green * 255))
        let b = Int(round(color.blue * 255))
        rgbRInput = "\(r)"
        rgbGInput = "\(g)"
        rgbBInput = "\(b)"

        let aPercent = Int(round(color.alpha * 100))
        alphaInput = "\(aPercent)"
    }

    // Apply hex text if valid
    private func applyHexInput() {
        let cleaned = hexInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard cleaned.count == 6 || cleaned.count == 8,
              cleaned.range(of: "^[0-9A-F]+$", options: .regularExpression) != nil,
              let value = UInt64(cleaned, radix: 16) else {
            // Invalid input; reset the field to the current color's hex
            hexInput = color.hexString.replacingOccurrences(of: "#", with: "").uppercased()
            return
        }

        let r, g, b, a: Double

        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = color.alpha // keep existing alpha
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }

        color.red = r
        color.green = g
        color.blue = b
        color.alpha = a

        syncCodeFieldsFromColor()
    }

    // Apply RGB text if valid
    private func applyRGBInput() {
        guard let rInt = Int(rgbRInput),
              let gInt = Int(rgbGInput),
              let bInt = Int(rgbBInput),
              (0...255).contains(rInt),
              (0...255).contains(gInt),
              (0...255).contains(bInt) else {
            return
        }

        color.red = Double(rInt) / 255.0
        color.green = Double(gInt) / 255.0
        color.blue = Double(bInt) / 255.0

        syncCodeFieldsFromColor()
    }

    // Apply alpha text if valid
    private func applyAlphaInput() {
        guard let aInt = Int(alphaInput),
              (0...100).contains(aInt) else {
            return
        }

        color.alpha = Double(aInt) / 100.0
        syncCodeFieldsFromColor()
    }
}

private struct ColorCodesPickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorCodesPickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorCodesPickerPreviewContainer()
}


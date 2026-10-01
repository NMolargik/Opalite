//
//  QuickAddHexSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/30/25.
//

import SwiftUI
import SwiftData

/// A compact sheet for quickly adding a color by pasting a hex code.
struct QuickAddHexSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    @State private var hexInput: String = ""
    @State private var previewColor: OpaliteColor?
    @FocusState private var isTextFieldFocused: Bool

    private var isValidHex: Bool {
        previewColor != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Color preview
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(previewColor?.swiftUIColor ?? Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay {
                        if previewColor == nil {
                            VStack(spacing: 8) {
                                Image(systemName: "number")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)

                                Text("Enter a hex code")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(previewColor != nil ? "Color preview, \(previewColor!.hexString)" : "Color preview, no color entered")

                // Hex input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEX CODE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text("#")
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.secondary)

                        TextField("RRGGBB", text: $hexInput)
                            .font(.system(.title2, design: .monospaced))
                            .textFieldStyle(.plain)
                            #if os(iOS) || os(visionOS)
                            .textInputAutocapitalization(.characters)
                            .keyboardType(.asciiCapable)
                            #endif
                            .focused($isTextFieldFocused)
                            .accessibilityLabel("Hex code input")
                            .onChange(of: hexInput) { _, newValue in
                                let sanitized = sanitizeHexInput(newValue)
                                if sanitized != newValue {
                                    hexInput = sanitized
                                }
                                updatePreview()
                            }
                            .onSubmit {
                                if isValidHex {
                                    importColor()
                                }
                            }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )

                    if !hexInput.isEmpty && previewColor == nil {
                        Text("Enter a valid 6 or 8 character hex code")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

                // Preview details
                if let color = previewColor {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(color.hexString)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("RGB")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(color.rgbString)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add By Hex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        HapticsManager.shared.impact()
                        importColor()
                    }
                    .tint(.blue)
                    .disabled(!isValidHex)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Private Methods

    private func sanitizeHexInput(_ value: String) -> String {
        let allowed = "0123456789ABCDEFabcdef"
        let filtered = value.filter { allowed.contains($0) }
        return String(filtered.prefix(8)).uppercased()
    }

    private func updatePreview() {
        let cleaned = hexInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard cleaned.count == 6 || cleaned.count == 8,
              cleaned.range(of: "^[0-9A-F]+$", options: .regularExpression) != nil,
              let value = UInt64(cleaned, radix: 16) else {
            previewColor = nil
            return
        }

        let r, g, b, a: Double

        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }

        previewColor = OpaliteColor(
            name: nil,
            red: r,
            green: g,
            blue: b,
            alpha: a
        )
    }

    private func importColor() {
        guard let color = previewColor else { return }

        do {
            _ = try colorManager.createColor(existing: color)
            dismiss()
        } catch {
            toastManager.show(error: .colorCreationFailed)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )
    let manager = ColorManager(context: container.mainContext)

    return QuickAddHexSheet()
        .environment(manager)
        .environment(ToastManager())
        .modelContainer(container)
}

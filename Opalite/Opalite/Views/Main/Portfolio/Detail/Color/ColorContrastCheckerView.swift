//
//  ColorContrastCheckerView.swift
//  Opalite
//
//  Created by Claude on 12/26/25.
//

import SwiftUI
import SwiftData

/// A view for checking WCAG contrast ratios between two colors.
///
/// Displays the source color alongside a user-selected comparison color,
/// calculating and presenting contrast ratio and WCAG compliance levels.
struct ColorContrastCheckerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager

    let sourceColor: OpaliteColor

    @State private var comparisonColor: OpaliteColor?
    @State private var hexInput: String = ""
    @State private var showingWCAGInfo: Bool = false

    // MARK: - WCAG Thresholds

    private enum WCAGLevel: String, CaseIterable {
        case aaNormal = "AA Normal"
        case aaLarge = "AA Large"
        case aaaNormal = "AAA Normal"
        case aaaLarge = "AAA Large"

        var threshold: Double {
            switch self {
            case .aaNormal: return 4.5
            case .aaLarge: return 3.0
            case .aaaNormal: return 7.0
            case .aaaLarge: return 4.5
            }
        }

        var description: String {
            switch self {
            case .aaNormal: return "Normal text (4.5:1)"
            case .aaLarge: return "Large text 18pt+ (3:1)"
            case .aaaNormal: return "Enhanced normal (7:1)"
            case .aaaLarge: return "Enhanced large (4.5:1)"
            }
        }
    }

    private var contrastRatio: Double? {
        guard let comparison = comparisonColor else { return nil }
        return sourceColor.contrastRatio(against: comparison)
    }

    private func passes(_ level: WCAGLevel) -> Bool {
        guard let ratio = contrastRatio else { return false }
        return ratio >= level.threshold
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    colorComparisonSection

                    if let ratio = contrastRatio {
                        contrastRatioSection(ratio: ratio)
                    }

                    colorSelectionSection
                }
                .padding()
            }
            .navigationTitle("Contrast Checker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Color Comparison Section

    @ViewBuilder
    private var colorComparisonSection: some View {
        SectionCard(title: "Comparison", systemImage: "circle.righthalf.filled") {
            HStack(spacing: 16) {
                // Source color
                VStack(spacing: 8) {
                    SwatchView(
                        fill: [sourceColor],
                        width: 100,
                        height: 100,
                        badgeText: "",
                        showOverlays: false
                    )

                    Text(sourceColor.name ?? sourceColor.hexString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("Source")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text("vs")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                // Comparison color
                VStack(spacing: 8) {
                    if let comparison = comparisonColor {
                        SwatchView(
                            fill: [comparison],
                            width: 100,
                            height: 100,
                            badgeText: "",
                            showOverlays: false
                        )

                        Text(comparison.name ?? comparison.hexString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.quaternary)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Text("Select")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        Text("Not selected")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text("Compare")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Contrast Ratio Section

    @ViewBuilder
    private func contrastRatioSection(ratio: Double) -> some View {
        SectionCard(title: "WCAG Compliance", systemImage: "checkmark.seal") {
            VStack(spacing: 16) {
                // Large ratio display
                Text(String(format: "%.2f:1", ratio))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(ratio >= 4.5 ? .green : (ratio >= 3.0 ? .orange : .red))
                    .accessibilityLabel("Contrast ratio \(String(format: "%.2f", ratio)) to 1")

                // Compliance badges grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(WCAGLevel.allCases, id: \.rawValue) { level in
                        complianceBadge(level: level)
                    }
                }
            }
            .padding(.horizontal, 16)
        } trailing: {
            Button {
                HapticsManager.shared.selection()
                showingWCAGInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Learn about WCAG")
        }
        .alert("About WCAG", isPresented: $showingWCAGInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("WCAG (Web Content Accessibility Guidelines) defines contrast ratio requirements to ensure text is readable for people with visual impairments.\n\nAA is the minimum recommended level for most content. AAA provides enhanced accessibility.\n\n\"Large\" text is 18pt (24px) or larger, or 14pt (18.5px) bold.")
        }
    }

    @ViewBuilder
    private func complianceBadge(level: WCAGLevel) -> some View {
        let isPassing = passes(level)

        HStack(spacing: 8) {
            Image(systemName: isPassing ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isPassing ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(level.rawValue)
                    .font(.caption.bold())

                Text(String(format: "%.1f:1", level.threshold))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isPassing ? .green.opacity(0.1) : .red.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.rawValue): \(isPassing ? "Pass" : "Fail")")
    }

    // MARK: - Color Selection Section

    @ViewBuilder
    private var colorSelectionSection: some View {
        SectionCard(title: "Select Comparison Color", systemImage: "paintpalette") {
            VStack(alignment: .leading, spacing: 16) {
                // Hex input
                HStack(spacing: 10) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)

                    TextField("Enter hex (e.g., FF5500)", text: $hexInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onSubmit {
                            applyHexInput()
                        }

                    Button {
                        HapticsManager.shared.selection()
                        applyHexInput()
                    } label: {
                        Text("Apply")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hexInput.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

                // Quick presets
                Text("Quick Presets")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    quickPresetButton(name: "White", r: 1, g: 1, b: 1)
                    quickPresetButton(name: "Black", r: 0, g: 0, b: 0)
                    quickPresetButton(name: "Gray", r: 0.5, g: 0.5, b: 0.5)
                }

                // Existing colors
                if !colorManager.colors.isEmpty {
                    Text("Your Colors")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(colorManager.colors.filter { $0.id != sourceColor.id }.prefix(20)) { color in
                                Button {
                                    HapticsManager.shared.selection()
                                    comparisonColor = color
                                } label: {
                                    SwatchView(
                                        fill: [color],
                                        width: 50,
                                        height: 50,
                                        badgeText: "",
                                        showOverlays: false
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(color.name ?? color.hexString)
                            }
                        }
                        .padding(12)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func quickPresetButton(name: String, r: Double, g: Double, b: Double) -> some View {
        Button {
            HapticsManager.shared.selection()
            comparisonColor = OpaliteColor(name: name, red: r, green: g, blue: b)
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(red: r, green: g, blue: b))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(name)")
    }

    // MARK: - Hex Input Handling

    private func applyHexInput() {
        let hex = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard hex.count == 6,
              let r = Int(hex.prefix(2), radix: 16),
              let g = Int(hex.dropFirst(2).prefix(2), radix: 16),
              let b = Int(hex.dropFirst(4).prefix(2), radix: 16) else {
            return
        }

        comparisonColor = OpaliteColor(
            name: "#\(hex.uppercased())",
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
        hexInput = ""
    }
}

// MARK: - Preview

#Preview("Contrast Checker") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)

    return ColorContrastCheckerView(sourceColor: OpaliteColor.sample)
        .environment(manager)
        .modelContainer(container)
}

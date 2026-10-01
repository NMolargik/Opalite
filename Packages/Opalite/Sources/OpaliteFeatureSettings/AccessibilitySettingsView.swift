//
//  AccessibilitySettingsView.swift
//  OpaliteFeatureSettings
//
//  The color-vision simulation picker with a live strip of example swatches so the
//  effect of each mode is visible before it's applied app-wide.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct AccessibilitySettingsView: View {
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var modeRaw = ColorBlindnessMode.off.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var mode: Binding<ColorBlindnessMode> {
        Binding(
            get: { ColorBlindnessMode(rawValue: modeRaw) ?? .off },
            set: { modeRaw = $0.rawValue }
        )
    }

    /// A spread of hues that makes each deficiency's effect obvious.
    private static let examples: [RGBA] = [
        RGBA(red: 0.90, green: 0.22, blue: 0.21),
        RGBA(red: 0.98, green: 0.58, blue: 0.14),
        RGBA(red: 0.98, green: 0.84, blue: 0.20),
        RGBA(red: 0.30, green: 0.72, blue: 0.34),
        RGBA(red: 0.16, green: 0.68, blue: 0.72),
        RGBA(red: 0.22, green: 0.47, blue: 0.90),
        RGBA(red: 0.56, green: 0.33, blue: 0.80),
        RGBA(red: 0.92, green: 0.38, blue: 0.62),
    ]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    SimulationStrip(colors: Self.examples, mode: mode.wrappedValue)
                    Text(mode.wrappedValue.modeDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .padding(.vertical, Brand.Space.xs)
                .animation(reduceMotion ? nil : .snappy, value: modeRaw)
            } header: {
                Text("Preview")
            }

            Section {
                Picker(selection: mode) {
                    ForEach(ColorBlindnessMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Label("Simulation", systemImage: "eye")
                        .labelStyle(.settingsIcon(.orange))
                }
                .pickerStyle(.inline)
                .onChange(of: modeRaw) { Haptics.selection() }
                .accessibilityIdentifier("accessibility.colorVision")
            } header: {
                Text("Color Vision")
            } footer: {
                Text("Simulates how your colors appear to people with color vision deficiencies. Swatches throughout Opalite follow this setting, and the Settings tab icon shows when a simulation is active.")
            }
        }
        .navigationTitle("Accessibility")
    }
}

/// A rounded strip of swatches with the simulation applied.
private struct SimulationStrip: View {
    let colors: [RGBA]
    let mode: ColorBlindnessMode

    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, rgba in
                Rectangle()
                    .fill(ColorBlindnessSimulator.simulate(rgba, mode: mode).color)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous).strokeBorder(.quaternary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Example swatches, \(mode.shortTitle)"))
    }
}

#if DEBUG
#Preview("Accessibility") {
    NavigationStack { AccessibilitySettingsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

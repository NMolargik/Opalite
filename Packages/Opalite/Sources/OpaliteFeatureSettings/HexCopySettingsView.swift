//
//  HexCopySettingsView.swift
//  OpaliteFeatureSettings
//
//  The "#" prefix preference for copied hex codes, with a live example and a one-tap
//  trial copy. Writes through `HexCopyModel` so every copy path agrees.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct HexCopySettingsView: View {
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var includesPrefix = true
    @State private var hasLoaded = false

    private static let example = RGBA(red: 0.20, green: 0.50, blue: 0.80)

    private var exampleText: String {
        HexFormat(includesPrefix: includesPrefix).format(Self.example.hexString)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Brand.Space.lg) {
                    ColorChip(Self.example, size: 56, cornerRadius: Brand.Radius.control)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Copied as")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(exampleText)
                            .font(.title3.monospaced().weight(.semibold))
                            .contentTransition(.opacity)
                            .animation(reduceMotion ? nil : .snappy, value: includesPrefix)
                    }
                    Spacer(minLength: 0)
                    Button {
                        hexCopy.copy(text: exampleText, label: exampleText)
                    } label: {
                        Label("Try It", systemImage: "doc.on.doc")
                    }
                    .glassActionButton(tint: .opalitePurple, prominent: false)
                    .controlSize(.small)
                    .accessibilityHint(Text("Copies the example hex code"))
                }
                .padding(.vertical, Brand.Space.xs)
                .accessibilityElement(children: .contain)
            } header: {
                Text("Example")
            }

            Section {
                Toggle(isOn: $includesPrefix) {
                    Label("Include # Prefix", systemImage: "number")
                        .labelStyle(.settingsIcon(.green))
                }
                .tint(.green)
                .accessibilityIdentifier("hex.includesPrefix")
            } footer: {
                Text("CSS and most design tools expect the # prefix. Turn it off when you paste into code that adds its own.")
            }
        }
        .navigationTitle("Hex Codes")
        .onAppear {
            guard !hasLoaded else { return }
            includesPrefix = hexCopy.includesPrefix
            hasLoaded = true
        }
        .onChange(of: includesPrefix) { _, newValue in
            guard hasLoaded, hexCopy.includesPrefix != newValue else { return }
            Haptics.selection()
            hexCopy.includesPrefix = newValue
        }
    }
}

#if DEBUG
#Preview("Hex Codes") {
    NavigationStack { HexCopySettingsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

//
//  CodesPickerView.swift
//  OpaliteFeatureColorEditor
//
//  Mode 5: typed values. The hex field validates as you type and applies at six or
//  eight digits (paste works too); RGB, HSL, and opacity fields apply on return or when
//  focus leaves them, and out-of-range entries snap back.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct CodesPickerView: View {
    let viewModel: ColorEditorViewModel

    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: Field?

    @State private var red = ""
    @State private var green = ""
    @State private var blue = ""
    @State private var hue = ""
    @State private var saturation = ""
    @State private var lightness = ""
    @State private var opacity = ""

    private enum Field: Hashable {
        case hex, red, green, blue, hue, saturation, lightness, opacity
        var group: Group {
            switch self {
            case .hex: .hex
            case .red, .green, .blue: .rgb
            case .hue, .saturation, .lightness: .hsl
            case .opacity: .opacity
            }
        }
        enum Group { case hex, rgb, hsl, opacity }
    }

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            section(String(localized: "Hex"), subtitle: String(localized: "Paste from any design tool")) {
                hexRow
            }
            section(String(localized: "RGB"), subtitle: String(localized: "0–255 per channel")) {
                HStack(spacing: Brand.Space.sm) {
                    numberField(String(localized: "R"), text: $red, field: .red)
                    numberField(String(localized: "G"), text: $green, field: .green)
                    numberField(String(localized: "B"), text: $blue, field: .blue)
                    copyButton(label: String(localized: "RGB"), text: viewModel.rgba.rgbString)
                }
            }
            section(String(localized: "HSL"), subtitle: String(localized: "Hue in degrees, saturation and lightness in percent")) {
                HStack(spacing: Brand.Space.sm) {
                    numberField(String(localized: "H"), text: $hue, field: .hue)
                    numberField(String(localized: "S"), text: $saturation, field: .saturation)
                    numberField(String(localized: "L"), text: $lightness, field: .lightness)
                    copyButton(label: String(localized: "HSL"), text: viewModel.rgba.hslString)
                }
            }
            section(String(localized: "Opacity"), subtitle: String(localized: "0–100%")) {
                HStack(spacing: Brand.Space.sm) {
                    numberField(String(localized: "Opacity"), text: $opacity, field: .opacity)
                        .frame(maxWidth: 120)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear(perform: syncFields)
        .onChange(of: viewModel.rgba) { syncFields() }
        .onChange(of: focus) { old, new in
            guard let old, old.group != new?.group else { return }
            commit(old.group)
        }
    }

    // MARK: Hex

    private var hexRow: some View {
        let state = viewModel.hexFieldState
        return HStack(spacing: Brand.Space.sm) {
            HStack(spacing: 4) {
                Text("#")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                TextField(String(localized: "RRGGBB"), text: Binding(get: { viewModel.hexField }, set: { viewModel.setHexField($0) }))
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($focus, equals: .hex)
                    .onSubmit { commit(.hex) }
                    .accessibilityLabel(Text("Hex color code"))
                    .accessibilityValue(Text(stateDescription(state)))
                    .accessibilityHint(Text("Enter a 3, 4, 6, or 8 digit hex code"))
                    .accessibilityIdentifier("colorEditor.hexField")
                Image(systemName: state == .invalid ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(state == .invalid ? Color.red : Color.green)
                    .opacity(state == .neutral ? 0 : 1)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm)
            .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                    .strokeBorder(state == .invalid ? Color.red.opacity(0.7) : (focus == .hex ? Color.opalitePurple.opacity(0.7) : Color.clear), lineWidth: 1.5)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: state)

            PasteButton(payloadType: String.self) { strings in
                guard let text = strings.first else { return }
                viewModel.setHexField(text)
                if viewModel.commitHexField() { Haptics.lightImpact() } else { Haptics.warning() }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(.opalitePurple)
            .accessibilityLabel(Text("Paste hex code"))

            copyButton(label: String(localized: "hex"), text: nil)
        }
    }

    private func stateDescription(_ state: ColorEditorViewModel.HexFieldState) -> String {
        switch state {
        case .neutral: viewModel.hexField.isEmpty ? String(localized: "Empty") : String(localized: "Incomplete")
        case .valid: String(localized: "Valid, \(viewModel.rgba.hexString)")
        case .invalid: String(localized: "Invalid")
        }
    }

    // MARK: Fields

    private func numberField(_ label: String, text: Binding<String>, field: Field) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .font(.body.monospacedDigit())
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .focused($focus, equals: field)
                .onSubmit { commit(field.group) }
                .onChange(of: text.wrappedValue) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(3))
                    if digits != value { text.wrappedValue = digits }
                }
                .padding(.vertical, Brand.Space.sm)
                .frame(maxWidth: .infinity)
                .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                        .strokeBorder(focus == field ? Color.opalitePurple.opacity(0.7) : Color.clear, lineWidth: 1.5)
                )
        }
        .frame(minWidth: 56)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label) value"))
        .accessibilityIdentifier("colorEditor.codes.\(label.lowercased())")
    }

    private func copyButton(label: String, text: String?) -> some View {
        Button {
            if let text {
                hexCopy.copy(text: text, label: label)
            } else {
                hexCopy.copy(hex: viewModel.rgba.hexString)
            }
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.opalitePurple)
        .accessibilityLabel(Text("Copy \(label)"))
    }

    private func section<Content: View>(_ title: String, subtitle: String, @ContentBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Sync / commit

    private func syncFields() {
        let rgba = viewModel.rgba
        red = "\(rgba.red.byte)"
        green = "\(rgba.green.byte)"
        blue = "\(rgba.blue.byte)"
        let hsl = rgba.hsl
        hue = "\(Int(hsl.hue.rounded()))"
        saturation = "\(Int((hsl.saturation * 100).rounded()))"
        lightness = "\(Int((hsl.lightness * 100).rounded()))"
        opacity = "\(Int((rgba.alpha * 100).rounded()))"
    }

    private func commit(_ group: Field.Group) {
        let accepted: Bool
        switch group {
        case .hex:
            accepted = viewModel.commitHexField()
        case .rgb:
            if let r = Int(red), let g = Int(green), let b = Int(blue) {
                accepted = viewModel.applyRGBBytes(red: r, green: g, blue: b)
            } else {
                accepted = false
            }
        case .hsl:
            if let h = Double(hue), let s = Double(saturation), let l = Double(lightness) {
                accepted = viewModel.applyHSL(hueDegrees: h, saturationPercent: s, lightnessPercent: l)
            } else {
                accepted = false
            }
        case .opacity:
            accepted = Int(opacity).map { viewModel.applyAlphaPercent($0) } ?? false
        }
        if accepted { Haptics.lightImpact() } else { Haptics.warning() }
        syncFields()
    }
}

#if DEBUG
#Preview("Codes") {
    CodesPickerView(viewModel: ColorEditorViewModel(mode: .create()))
        .padding()
        .previewEnvironment()
}
#endif
#endif

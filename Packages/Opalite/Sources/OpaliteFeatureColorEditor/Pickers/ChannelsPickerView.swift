//
//  ChannelsPickerView.swift
//  OpaliteFeatureColorEditor
//
//  Mode 4: RGB or HSL sliders whose tracks show what each channel would produce given
//  the other two, plus opacity.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct ChannelsPickerView: View {
    let viewModel: ColorEditorViewModel

    @AppStorage("colorEditor.channelSpace") private var spaceRaw = Space.rgb.rawValue

    enum Space: String, CaseIterable, Identifiable {
        case rgb, hsl
        var id: String { rawValue }
        var title: String {
            switch self {
            case .rgb: String(localized: "RGB")
            case .hsl: String(localized: "HSL")
            }
        }
    }

    private var space: Space { Space(rawValue: spaceRaw) ?? .rgb }

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            Picker("Color model", selection: $spaceRaw) {
                ForEach(Space.allCases) { space in
                    Text(space.title).tag(space.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .accessibilityIdentifier("colorEditor.channels.space")

            switch space {
            case .rgb: rgbSliders
            case .hsl: hslSliders
            }

            OpacitySlider(viewModel: viewModel)
        }
    }

    // MARK: RGB

    private var rgbSliders: some View {
        let r = viewModel.red, g = viewModel.green, b = viewModel.blue
        return Group {
            GradientSlider(
                title: String(localized: "Red"),
                value: Binding(get: { viewModel.red }, set: { viewModel.red = $0 }),
                stops: [RGBA(red: 0, green: g, blue: b).color, RGBA(red: 1, green: g, blue: b).color],
                thumbColor: RGBA(red: r, green: g, blue: b).color,
                valueText: "\(r.byte)",
                step: 1 / 255,
                onEditingChanged: editingChanged
            )
            .accessibilityIdentifier("colorEditor.channels.red")

            GradientSlider(
                title: String(localized: "Green"),
                value: Binding(get: { viewModel.green }, set: { viewModel.green = $0 }),
                stops: [RGBA(red: r, green: 0, blue: b).color, RGBA(red: r, green: 1, blue: b).color],
                thumbColor: RGBA(red: r, green: g, blue: b).color,
                valueText: "\(g.byte)",
                step: 1 / 255,
                onEditingChanged: editingChanged
            )
            .accessibilityIdentifier("colorEditor.channels.green")

            GradientSlider(
                title: String(localized: "Blue"),
                value: Binding(get: { viewModel.blue }, set: { viewModel.blue = $0 }),
                stops: [RGBA(red: r, green: g, blue: 0).color, RGBA(red: r, green: g, blue: 1).color],
                thumbColor: RGBA(red: r, green: g, blue: b).color,
                valueText: "\(b.byte)",
                step: 1 / 255,
                onEditingChanged: editingChanged
            )
            .accessibilityIdentifier("colorEditor.channels.blue")
        }
    }

    // MARK: HSL

    private var hslSliders: some View {
        let h = viewModel.hue, s = viewModel.hslSaturation, l = viewModel.lightness
        let opaque = RGBA(red: viewModel.red, green: viewModel.green, blue: viewModel.blue).color
        return Group {
            GradientSlider(
                title: String(localized: "Hue"),
                value: Binding(get: { viewModel.hue / 360 }, set: { viewModel.hue = $0 * 360 }),
                stops: SpectrumPickerView.hueStops,
                thumbColor: HSV(hue: h, saturation: 1, value: 1).rgba.color,
                valueText: String(localized: "\(Int(h.rounded()))°"),
                step: 5 / 360,
                onEditingChanged: editingChanged
            )
            .accessibilityIdentifier("colorEditor.channels.hue")

            GradientSlider(
                title: String(localized: "Saturation"),
                value: Binding(get: { viewModel.hslSaturation }, set: { viewModel.hslSaturation = $0 }),
                stops: [HSL(hue: h, saturation: 0, lightness: l).rgba.color, HSL(hue: h, saturation: 1, lightness: l).rgba.color],
                thumbColor: opaque,
                valueText: String(localized: "\(Int((s * 100).rounded()))%"),
                onEditingChanged: editingChanged
            )
            .accessibilityIdentifier("colorEditor.channels.saturation")

            GradientSlider(
                title: String(localized: "Lightness"),
                value: Binding(get: { viewModel.lightness }, set: { viewModel.lightness = $0 }),
                stops: [.black, HSL(hue: h, saturation: s, lightness: 0.5).rgba.color, .white],
                thumbColor: opaque,
                valueText: String(localized: "\(Int((l * 100).rounded()))%"),
                onEditingChanged: editingChanged
            )
            .accessibilityIdentifier("colorEditor.channels.lightness")
        }
    }

    private func editingChanged(_ editing: Bool) {
        if editing { viewModel.beginGesture() } else { viewModel.endGesture() }
    }
}

#if DEBUG
#Preview("Channels") {
    ChannelsPickerView(viewModel: ColorEditorViewModel(mode: .create()))
        .padding()
}
#endif
#endif

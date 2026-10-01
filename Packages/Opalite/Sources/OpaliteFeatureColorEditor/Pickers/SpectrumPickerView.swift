//
//  SpectrumPickerView.swift
//  OpaliteFeatureColorEditor
//
//  Mode 1: a hue bar and a saturation/brightness plane with a draggable loupe. The plane
//  is an adjustable VoiceOver element that reads hue, saturation, and brightness.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct SpectrumPickerView: View {
    let viewModel: ColorEditorViewModel
    var fillsHeight = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var loupeSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var planeMinHeight: CGFloat = 200
    @State private var isDragging = false
    @FocusState private var planeFocused: Bool

    private var hueColor: Color { HSV(hue: viewModel.hue, saturation: 1, value: 1).rgba.color }

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            plane
                .frame(minHeight: planeMinHeight)
                .frame(maxHeight: fillsHeight ? .infinity : planeMinHeight * 1.4)

            GradientSlider(
                title: String(localized: "Hue"),
                value: Binding(get: { viewModel.hue / 360 }, set: { viewModel.hue = $0 * 360 }),
                stops: Self.hueStops,
                thumbColor: hueColor,
                valueText: String(localized: "\(Int(viewModel.hue.rounded()))°"),
                step: 5 / 360,
                onEditingChanged: editingChanged
            )

            OpacitySlider(viewModel: viewModel)
        }
    }

    static let hueStops: [Color] = stride(from: 0.0, through: 360.0, by: 30).map { HSV(hue: $0, saturation: 1, value: 1).rgba.color }

    private var plane: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let x = viewModel.hsvSaturation * size.width
            let y = (1 - viewModel.brightness) * size.height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous)
                    .fill(hueColor)
                    .overlay(LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing))
                    .overlay(LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous).strokeBorder(.quaternary))
                    .overlay {
                        if planeFocused {
                            RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                        }
                    }

                Circle()
                    .fill(viewModel.rgba.color.opacity(1))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5).padding(-0.5))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .frame(width: loupeSize, height: loupeSize)
                    .scaleEffect(isDragging && !reduceMotion ? 1.5 : 1)
                    .offset(y: isDragging && !reduceMotion ? -loupeSize * 0.9 : 0)
                    .position(x: min(max(x, 0), size.width), y: min(max(y, 0), size.height))
                    .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isDragging)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            viewModel.beginGesture()
                        }
                        apply(location: gesture.location, in: size)
                    }
                    .onEnded { gesture in
                        apply(location: gesture.location, in: size)
                        isDragging = false
                        viewModel.endGesture()
                    }
            )
        }
        .focusable()
        .focused($planeFocused)
        .onKeyPress(.leftArrow) { nudge(saturation: -0.02, brightness: 0); return .handled }
        .onKeyPress(.rightArrow) { nudge(saturation: 0.02, brightness: 0); return .handled }
        .onKeyPress(.upArrow) { nudge(saturation: 0, brightness: 0.02); return .handled }
        .onKeyPress(.downArrow) { nudge(saturation: 0, brightness: -0.02); return .handled }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Saturation and brightness"))
        .accessibilityValue(Text(viewModel.hsvDescription))
        .accessibilityHint(Text("Swipe up or down to change brightness. Use the actions rotor to change saturation."))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(saturation: 0, brightness: 0.05)
            case .decrement: nudge(saturation: 0, brightness: -0.05)
            @unknown default: break
            }
        }
        .accessibilityAction(named: Text("More saturated")) { nudge(saturation: 0.05, brightness: 0) }
        .accessibilityAction(named: Text("Less saturated")) { nudge(saturation: -0.05, brightness: 0) }
        .accessibilityIdentifier("colorEditor.spectrum.plane")
    }

    private func apply(location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        viewModel.setSaturationAndBrightness(
            saturation: location.x / size.width,
            brightness: 1 - location.y / size.height
        )
    }

    private func nudge(saturation: Double, brightness: Double) {
        viewModel.beginGesture()
        viewModel.setSaturationAndBrightness(
            saturation: viewModel.hsvSaturation + saturation,
            brightness: viewModel.brightness + brightness
        )
        viewModel.endGesture()
        Haptics.selection()
    }

    private func editingChanged(_ editing: Bool) {
        if editing { viewModel.beginGesture() } else { viewModel.endGesture() }
    }
}

/// The opacity slider every mode ends with: the color over a checkerboard.
struct OpacitySlider: View {
    let viewModel: ColorEditorViewModel

    var body: some View {
        let opaque = RGBA(red: viewModel.red, green: viewModel.green, blue: viewModel.blue)
        GradientSlider(
            title: String(localized: "Opacity"),
            value: Binding(get: { viewModel.alpha }, set: { viewModel.alpha = $0 }),
            stops: [opaque.color.opacity(0), opaque.color],
            thumbColor: viewModel.rgba.color,
            valueText: String(localized: "\(Int((viewModel.alpha * 100).rounded()))%"),
            showsCheckerboard: true,
            step: 0.05
        ) { editing in
            if editing { viewModel.beginGesture() } else { viewModel.endGesture() }
        }
        .accessibilityIdentifier("colorEditor.opacity")
    }
}

#if DEBUG
#Preview("Spectrum") {
    SpectrumPickerView(viewModel: ColorEditorViewModel(mode: .create()))
        .padding()
}
#endif
#endif

//
//  ShufflePickerView.swift
//  OpaliteFeatureColorEditor
//
//  Mode 3: a big orb of the current color that shuffles to a clearly different one on
//  tap, Space, or an arrow key, with a strip of the colors it has passed through.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct ShufflePickerView: View {
    let viewModel: ColorEditorViewModel
    var fillsHeight = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var orbSize: CGFloat = 150
    @ScaledMetric(relativeTo: .body) private var historyChip: CGFloat = 44
    @State private var spin = 0.0
    @State private var shuffleCount = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Brand.Space.xl) {
            if fillsHeight { Spacer(minLength: 0) }

            Button(action: shuffle) {
                ZStack {
                    Circle()
                        .fill(viewModel.rgba.color)
                        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                        .shadow(color: viewModel.rgba.color.opacity(0.45), radius: 24, y: 10)
                    Image(systemName: "shuffle")
                        .font(.largeTitle.weight(.semibold))
                        .imageScale(.large)
                        .foregroundStyle(viewModel.rgba.idealTextColor)
                        .rotationEffect(.degrees(spin))
                        .symbolEffect(.bounce, value: shuffleCount)
                }
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    if isFocused {
                        Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 3).padding(-6)
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hoverLift()
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6), value: spin)
            .accessibilityLabel(Text("Shuffle"))
            .accessibilityValue(Text("\(viewModel.familyDescription), \(viewModel.rgba.hexString)"))
            .accessibilityHint(Text("Jumps to a random color"))
            .accessibilityIdentifier("colorEditor.shuffle")

            VStack(spacing: Brand.Space.xs) {
                Text(viewModel.familyDescription)
                    .font(.headline)
                    .contentTransition(.opacity)
                Text(horizontalSizeClass == .regular ? "Tap, or press Space or an arrow key" : "Tap to shuffle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: viewModel.familyDescription)

            if fillsHeight { Spacer(minLength: 0) }

            if !viewModel.shuffleHistory.isEmpty {
                history
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            OpacitySlider(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: viewModel.shuffleHistory.isEmpty)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) { shuffle(); return .handled }
        .onKeyPress(.upArrow) { shuffle(); return .handled }
        .onKeyPress(.downArrow) { shuffle(); return .handled }
        .onKeyPress(.leftArrow) { shuffle(); return .handled }
        .onKeyPress(.rightArrow) { shuffle(); return .handled }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text("Recent")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Brand.Space.sm) {
                    ForEach(Array(viewModel.shuffleHistory.enumerated()), id: \.offset) { index, rgba in
                        Button {
                            Haptics.lightImpact()
                            viewModel.restoreFromHistory(rgba)
                        } label: {
                            RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                .fill(rgba.color)
                                .frame(width: historyChip, height: historyChip)
                                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                        }
                        .buttonStyle(.plain)
                        .hoverLift()
                        .accessibilityLabel(Text("Recent color \(index + 1), \(rgba.hexString)"))
                        .accessibilityHint(Text("Returns to this color"))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 2)
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: viewModel.shuffleHistory)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shuffle() {
        Haptics.mediumImpact()
        shuffleCount += 1
        if !reduceMotion { spin += 180 }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            viewModel.shuffle()
        }
    }
}

#if DEBUG
#Preview("Shuffle") {
    ShufflePickerView(viewModel: ColorEditorViewModel(mode: .create()))
        .padding()
}
#endif
#endif

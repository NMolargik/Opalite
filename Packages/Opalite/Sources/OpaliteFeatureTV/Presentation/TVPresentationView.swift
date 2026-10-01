//
//  TVPresentationView.swift
//  OpaliteFeatureTV
//
//  Edge-to-edge color. A soft highlight orbits and the label wanders a few points so no
//  static frame burns in; the label hides after a few seconds and any remote input brings
//  it back. Left/right steps through a palette, Menu exits.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVPresentationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HexCopyModel.self) private var hexCopy
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var simulationRaw = ColorBlindnessMode.off.rawValue

    @State private var deck: TVPresentationDeck
    @State private var isLabelVisible = true
    @State private var interactionCount = 0
    @FocusState private var isFocused: Bool

    init(request: TVPresentationRequest) {
        _deck = State(initialValue: request.deck)
    }

    var body: some View {
        ZStack {
            if let color = deck.current {
                let simulation = TVSimulation(raw: simulationRaw)
                simulation.color(color.rgba)
                    .ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let center = TVDrift.highlightCenter(at: time)
                    let nudge = TVDrift.labelOffset(at: time)

                    ZStack {
                        RadialGradient(
                            colors: [.white.opacity(0.08), .clear],
                            center: UnitPoint(x: center.x, y: center.y),
                            startRadius: 0,
                            endRadius: 1100
                        )
                        .ignoresSafeArea()
                        .blendMode(.plusLighter)

                        label(for: color, textColor: simulation.idealTextColor(color.rgba))
                            .offset(x: reduceMotion ? 0 : nudge.x, y: reduceMotion ? 0 : nudge.y)
                    }
                }
            } else {
                ContentUnavailableView("Nothing to Show", systemImage: "tv")
            }
        }
        .overlay(alignment: .top) { positionPill }
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onMoveCommand { direction in
            switch direction {
            case .left: deck.previous()
            case .right: deck.next()
            default: break
            }
            reveal()
        }
        .onPlayPauseCommand {
            withAnimation(.easeInOut(duration: 0.4)) { isLabelVisible.toggle() }
            interactionCount += 1
        }
        .onExitCommand { dismiss() }
        .task(id: interactionCount) {
            try? await Task.sleep(for: TVDrift.labelTimeout)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1.2)) { isLabelVisible = false }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: deck.index)
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityDescription))
        .accessibilityHint(Text(deck.hasMultiple
            ? "Swipe left or right to change colors. Press Menu to exit."
            : "Press Menu to exit."))
        .accessibilityIdentifier("presentation")
    }

    // MARK: - Pieces

    private func label(for color: TVPresentedColor, textColor: Color) -> some View {
        VStack(spacing: Brand.Space.md) {
            Spacer()
            if color.hasName {
                Text(color.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            Text(hexCopy.formatted(color.rgba.hexString))
                .font(color.hasName ? .title.monospaced() : .largeTitle.monospaced().weight(.semibold))
            if deck.hasMultiple {
                HStack(spacing: Brand.Space.sm) {
                    ForEach(deck.colors.indices, id: \.self) { index in
                        Circle()
                            .fill(textColor.opacity(index == deck.index ? 0.9 : 0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, Brand.Space.lg)
            }
        }
        .foregroundStyle(textColor)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        .padding(.bottom, 120)
        .padding(.horizontal, TVLayout.gutter)
        .opacity(isLabelVisible ? 1 : 0)
        .accessibilityHidden(true)
    }

    @ContentBuilder
    private var positionPill: some View {
        if let position = deck.positionDescription, let color = deck.current {
            Text(position)
                .font(.callout.weight(.medium))
                .foregroundStyle(TVSimulation(raw: simulationRaw).idealTextColor(color.rgba).opacity(0.85))
                .padding(.horizontal, Brand.Space.lg)
                .padding(.vertical, Brand.Space.sm)
                .adaptiveGlassCapsule()
                .padding(.top, Brand.Space.xxl)
                .opacity(isLabelVisible ? 1 : 0)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityDescription: String {
        guard let color = deck.current else { return String(localized: "Nothing to show") }
        var parts = [color.title]
        if color.hasName { parts.append(color.rgba.hexString) }
        if let position = deck.positionDescription { parts.append(position) }
        return parts.joined(separator: ", ")
    }

    private func reveal() {
        withAnimation(.easeIn(duration: 0.25)) { isLabelVisible = true }
        interactionCount += 1
    }
}

#if DEBUG
#Preview("Palette") {
    TVPresentationView(request: TVPresentationRequest(colors: OpaliteColor.samples))
        .previewEnvironment()
}

#Preview("Single color") {
    TVPresentationView(request: TVPresentationRequest(colors: [.sample]))
        .previewEnvironment()
}
#endif
#endif

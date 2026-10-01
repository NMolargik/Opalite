//
//  TVOLEDRefreshView.swift
//  OpaliteFeatureTV
//
//  Cycles full-field colors to help clear temporary image retention. Menu exits.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVOLEDRefreshView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var isHintVisible = true
    @FocusState private var isFocused: Bool

    private let cycle = TVOLEDRefreshCycle.standard

    var body: some View {
        let step = cycle.step(at: index)
        ZStack(alignment: .bottom) {
            (step?.rgba.color ?? .black)
                .ignoresSafeArea()

            if isHintVisible {
                Text("Press Menu to exit")
                    .font(.callout)
                    .foregroundStyle(step?.rgba.idealTextColor.opacity(0.7) ?? .secondary)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.sm)
                    .adaptiveGlassCapsule()
                    .padding(.bottom, 60)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onExitCommand { dismiss() }
        .task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1)) { isHintVisible = false }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: cycle.interval)
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 1)) {
                    index = cycle.nextIndex(after: index)
                }
            }
        }
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("OLED refresh, showing \(step?.name ?? "")"))
        .accessibilityHint(Text("Press Menu to exit"))
        .accessibilityIdentifier("oledRefresh")
    }
}

#if DEBUG
#Preview {
    TVOLEDRefreshView()
}
#endif
#endif

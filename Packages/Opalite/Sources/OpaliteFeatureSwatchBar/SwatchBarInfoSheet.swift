//
//  SwatchBarInfoSheet.swift
//  OpaliteFeatureSwatchBar
//
//  Explains the SwatchBar the first time the user reaches for it (from Settings or the
//  menu bar) and offers to open it. "Don't show again" writes
//  `AppStorageKeys.skipSwatchBarConfirmation`, so the shell can open the window straight
//  away next time. The shell presents this for `PendingPresentation.swatchBarInfo` and
//  hands in `onOpen` (nil where the platform has no second window), which opens the
//  window directly — routing back through the shell would only re-present this sheet.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct SwatchBarInfoSheet: View {
    private let onOpen: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.skipSwatchBarConfirmation) private var skipConfirmation = false
    @State private var hasAppeared = false

    /// - Parameter onOpen: Opens the SwatchBar window; pass nil where multiple windows
    ///   are unsupported and the sheet is purely informational.
    public init(onOpen: (() -> Void)? = nil) {
        self.onOpen = onOpen
    }

    private struct Feature: Identifiable {
        let id: String
        let systemImage: String
        let title: String
        let detail: String
    }

    private var features: [Feature] {
        [
            Feature(
                id: "copy",
                systemImage: "doc.on.doc",
                title: String(localized: "Tap to copy"),
                detail: String(localized: "Every swatch copies its hex code the moment you tap it.")
            ),
            Feature(
                id: "ink",
                systemImage: "paintbrush.pointed",
                title: String(localized: "Paint with it"),
                detail: String(localized: "With a canvas open, the tapped color becomes your ink.")
            ),
            Feature(
                id: "quickAdd",
                systemImage: "number",
                title: String(localized: "Add by hex"),
                detail: String(localized: "Type a code at the bottom and press return to save a new color.")
            ),
            Feature(
                id: "window",
                systemImage: "macwindow.on.rectangle",
                title: String(localized: "Lives beside your work"),
                detail: String(localized: "A slim window you can park next to any app and resize as you like.")
            ),
        ]
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.xl) {
                    hero
                    featureList
                    Toggle(isOn: $skipConfirmation) {
                        Label("Don't show this again", systemImage: "eye.slash")
                            .labelStyle(.alignedIcon)
                    }
                    .tint(.opalitePurple)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.md)
                    .cardSurface()
                    .accessibilityIdentifier("swatchBarInfo.dontShowAgain")
                }
                .frame(maxWidth: Brand.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Brand.Space.lg)
                .padding(.top, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xl)
            }
            .softScrollEdgesIfAvailable()
            .background {
                ZStack {
                    groupedBackground
                    LinearGradient.opaliteWash
                }
                .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom) {
                if let onOpen {
                    Button {
                        Haptics.mediumImpact()
                        onOpen()
                        dismiss()
                    } label: {
                        Label("Open SwatchBar", systemImage: "arrow.up.forward.square")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionButton()
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.bottom, Brand.Space.md)
                    .accessibilityIdentifier("swatchBarInfo.open")
                }
            }
            .navigationTitle("SwatchBar")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .toolbarButtonTint()
                        .accessibilityIdentifier("swatchBarInfo.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Brand.Radius.sheet)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Brand.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .fill(LinearGradient.opalite)
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.opalitePurple.opacity(0.35), radius: 16, y: 8)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.7)
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .accessibilityHidden(true)

            Text("Your colors, always within reach")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("SwatchBar opens Opalite in a second, narrow window so your palettes stay one tap away while you design elsewhere.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: Brand.Space.sm) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                featureRow(feature)
                    .opacity(hasAppeared || reduceMotion ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.07 + 0.15),
                        value: hasAppeared
                    )
            }
        }
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            Image(systemName: feature.systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.opalitePurple)
                .frame(width: 36, height: 36)
                .background(Color.opalitePurple.opacity(0.14), in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Brand.Space.md)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("SwatchBar info") {
    Color.clear
        .sharedSheet(isPresented: .constant(true)) {
            SwatchBarInfoSheet(onOpen: {})
                .previewEnvironment()
        }
}
#endif
#endif

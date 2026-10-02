//
//  SplashView.swift
//  OpaliteFeatureOnboarding
//
//  The first screen on a fresh install: the app artwork, the name, one line of value,
//  and a single "Get Started" — on the plain grouped background, in the system text
//  colors. A short fade-and-settle entrance; Reduce Motion shows it at once.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

// MARK: - SplashView

public struct SplashView: View {
    private let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var appeared = false

    @ScaledMetric(relativeTo: .largeTitle) private var artworkSide: CGFloat = 148
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 96

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            groupedBackground.ignoresSafeArea()

            VStack(spacing: Brand.Space.xxl) {
                Spacer(minLength: 0)

                artwork
                    .frame(width: side, height: side)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .accessibilityHidden(true)

                VStack(spacing: Brand.Space.md) {
                    Text("Opalite")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Capture, organize, and share every color you love.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Brand.Space.lg)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 0)

                Button {
                    Haptics.mediumImpact()
                    onContinue()
                } label: {
                    HStack(spacing: Brand.Space.sm) {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                            .accessibilityHidden(true)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .primaryActionButton()
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("continueButton")
                .accessibilityHint("Continues to the introduction")
                .padding(.bottom, Brand.Space.lg)
            }
            .opacity(appeared ? 1 : 0)
            .padding(.horizontal, Brand.Space.xl)
            .padding(.vertical, Brand.Space.xxl)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: runEntrance)
    }

    // MARK: Artwork

    private var side: CGFloat {
        horizontalSizeClass == .regular ? artworkSide * 1.2 : artworkSide
    }

    /// The gem-and-squares artwork from the app's asset catalog when it is present (the
    /// app target), otherwise an SF Symbol gem in the brand purple (package previews).
    @ContentBuilder
    private var artwork: some View {
        if Self.hasBrandArtwork {
            ZStack {
                Image("squares", bundle: .main)
                    .resizable()
                    .scaledToFit()
                Image("gemstone", bundle: .main)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            Image(systemName: "diamond.fill")
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(.opalitePurpleInk)
        }
    }

    private static let hasBrandArtwork: Bool = {
        #if canImport(UIKit)
        UIImage(named: "gemstone", in: .main, compatibleWith: nil) != nil
            && UIImage(named: "squares", in: .main, compatibleWith: nil) != nil
        #else
        false
        #endif
    }()

    // MARK: Entrance

    private func runEntrance() {
        guard !reduceMotion else {
            appeared = true
            return
        }
        withAnimation(.easeOut(duration: 0.45)) { appeared = true }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Splash") {
    SplashView(onContinue: {})
}
#endif
#endif

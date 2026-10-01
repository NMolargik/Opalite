//
//  SplashView.swift
//  OpaliteFeatureOnboarding
//
//  The first screen on a fresh install: a quick, cinematic welcome — the brand wash,
//  a slowly turning hue ring around the gem motif, the app name in the brand gradient,
//  one line of value, and a single "Get Started". The entrance is staged with springs;
//  Reduce Motion shows the finished composition at once.
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

    @State private var showHero = false
    @State private var showTitle = false
    @State private var showButton = false
    @State private var breathe = false
    @State private var ringRotation: Double = 0

    @ScaledMetric(relativeTo: .largeTitle) private var heroDiameter: CGFloat = 220
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 84

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            background

            VStack(spacing: Brand.Space.xxl) {
                Spacer(minLength: 0)

                hero
                    .scaleEffect(showHero ? 1 : 0.6)
                    .opacity(showHero ? 1 : 0)

                titleBlock
                    .offset(y: showTitle ? 0 : 16)
                    .opacity(showTitle ? 1 : 0)

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
                .scaleEffect(showButton ? 1 : 0.9)
                .opacity(showButton ? 1 : 0)
                .padding(.bottom, Brand.Space.lg)
            }
            .padding(.horizontal, Brand.Space.xl)
            .padding(.vertical, Brand.Space.xxl)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("splashView")
        .onAppear(perform: runEntrance)
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            groupedBackground
            LinearGradient.opaliteWash

            // Soft drifting blobs of the brand colors.
            GeometryReader { proxy in
                let size = proxy.size
                let drift: CGFloat = breathe ? 24 : -24
                Circle()
                    .fill(Color.opaliteBlue)
                    .frame(width: size.width * 0.9)
                    .blur(radius: 90)
                    .offset(x: -size.width * 0.35 + drift, y: -size.height * 0.25)
                Circle()
                    .fill(Color.opalitePurple)
                    .frame(width: size.width * 0.8)
                    .blur(radius: 100)
                    .offset(x: size.width * 0.45 - drift, y: size.height * 0.15)
                Circle()
                    .fill(Color.opaliteTan)
                    .frame(width: size.width * 0.9)
                    .blur(radius: 100)
                    .offset(x: size.width * 0.05, y: size.height * 0.6 + drift)
            }
            .opacity(0.55)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Hero

    private var diameter: CGFloat {
        horizontalSizeClass == .regular ? heroDiameter * 1.2 : heroDiameter
    }

    private var hero: some View {
        let ringWidth = diameter * 0.055
        return ZStack {
            // Glow
            Circle()
                .fill(AngularGradient.hueWheel)
                .blur(radius: diameter * 0.2)
                .opacity(breathe ? 0.5 : 0.3)
                .scaleEffect(breathe ? 1.08 : 0.96)

            // Hue ring
            Circle()
                .strokeBorder(AngularGradient.hueWheel, lineWidth: ringWidth)
                .rotationEffect(.degrees(ringRotation))

            // Inner disc
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .padding(ringWidth + Brand.Space.sm)

            motif
                .scaleEffect(breathe ? 1.04 : 0.98)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Opalite gemstone")
    }

    /// The gem-and-squares artwork from the app's asset catalog when it is present (the
    /// app target), otherwise an SF Symbol gem in the brand gradient (package previews).
    @ContentBuilder
    private var motif: some View {
        if Self.hasBrandArtwork {
            ZStack {
                Image("squares", bundle: .main)
                    .resizable()
                    .scaledToFit()
                Image("gemstone", bundle: .main)
                    .resizable()
                    .scaledToFit()
            }
            .padding(diameter * 0.2)
        } else {
            Image(systemName: "diamond.fill")
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(LinearGradient.opalite)
                .symbolEffect(.breathe, isActive: !reduceMotion)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
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

    // MARK: Title

    private var titleBlock: some View {
        VStack(spacing: Brand.Space.md) {
            Text("Opalite")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.opaliteHorizontal)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                .accessibilityAddTraits(.isHeader)

            Text("Capture, organize, and share every color you love.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Brand.Space.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: Entrance

    private func runEntrance() {
        guard !reduceMotion else {
            showHero = true
            showTitle = true
            showButton = true
            return
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { showHero = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.25)) { showTitle = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) { showButton = true }
        withAnimation(.linear(duration: 36).repeatForever(autoreverses: false)) { ringRotation = 360 }
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathe = true }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Splash") {
    SplashView(onContinue: {})
}
#endif
#endif

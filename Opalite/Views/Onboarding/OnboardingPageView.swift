//
//  OnboardingPageView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/25/25.
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    let features: [OnboardingFeature]
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let geometry: GeometryProxy

    @State private var iconAnimated: Bool = false
    @State private var titleAnimated: Bool = false
    @State private var featuresAnimated: [Bool] = []
    @State private var mainIconBounce: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var glowPulse: Bool = false
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer()

                // Animated icon
                ZStack {
                    // Rotating gradient background
                    if page.iconColors.count >= 2 {
                        AngularGradient(
                            colors: page.iconColors + [page.iconColors.first!],
                            center: .center,
                            angle: .degrees(rotationAngle)
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)
                        .opacity(iconAnimated ? 0.5 : 0)
                        .accessibilityHidden(true)
                    }
                    
                    // Pulsing glow effect
                    iconImage(size: 84)
                        .blur(radius: 8)
                        .opacity(iconAnimated ? (glowPulse ? 0.7 : 0.5) : 0)
                        .accessibilityHidden(true)

                    // Main icon with floating animation
                    iconImage(size: 72)
                        .symbolEffect(.bounce, options: .nonRepeating.speed(1.1), value: mainIconBounce)
                        .offset(y: floatOffset)
                        .accessibilityHidden(true)
                }
                .scaleEffect(iconAnimated ? 1 : 0.5)
                .opacity(iconAnimated ? 1 : 0)
                .rotation3DEffect(
                    .degrees(iconAnimated ? 0 : 15),
                    axis: (x: 1, y: 1, z: 0)
                )

                // Title and subtitle
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(page.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
                .offset(y: titleAnimated ? 0 : 20)
                .opacity(titleAnimated ? 1 : 0)
                .accessibilityElement(children: .combine)

                Spacer()

                // Features list
                VStack(spacing: 6) {
                    ForEach(Array(page.features.enumerated()), id: \.element.id) { index, feature in
                        OnboardingFeatureRow(feature: feature)
                            .offset(x: index < featuresAnimated.count && featuresAnimated[index] ? 0 : -30)
                            .opacity(index < featuresAnimated.count && featuresAnimated[index] ? 1 : 0)
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 400)

                Spacer()
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    animateContent()
                } else {
                    resetAnimations()
                }
            }
            .onAppear {
                featuresAnimated = Array(repeating: false, count: page.features.count)
                if isActive {
                    animateContent()
                }
            }
        }
    }

    private func animateContent() {
        // Icon animation with 3D rotation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            iconAnimated = true
        }
        mainIconBounce.toggle()

        // Title animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
            titleAnimated = true
        }

        // Staggered feature animations
        for index in 0..<page.features.count {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.08)) {
                if index < featuresAnimated.count {
                    featuresAnimated[index] = true
                }
            }
        }
        
        // Start continuous animations
        startContinuousAnimations()
    }
    
    private func startContinuousAnimations() {
        // Rotating gradient
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulsing glow
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
        
        // Gentle floating motion
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            floatOffset = -8
        }
    }
    
    private func stopContinuousAnimations() {
        rotationAngle = 0
        glowPulse = false
        floatOffset = 0
    }

    private func resetAnimations() {
        stopContinuousAnimations()
        iconAnimated = false
        titleAnimated = false
        mainIconBounce = false
        featuresAnimated = Array(repeating: false, count: page.features.count)
    }

    @ViewBuilder
    private func iconImage(size: CGFloat) -> some View {
        let colors = page.iconColors
        let image = Image(systemName: page.icon)
            .font(.system(size: size, weight: .medium))

        switch colors.count {
        case 3...:
            image.foregroundStyle(colors[0], colors[1], colors[2])
        case 2:
            image.foregroundStyle(colors[0], colors[1])
        case 1:
            image.foregroundStyle(colors[0])
        default:
            image.foregroundStyle(.primary)
        }
    }
}

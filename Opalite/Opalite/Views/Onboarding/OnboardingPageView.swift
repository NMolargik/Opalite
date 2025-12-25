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

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated icon
            ZStack {
                // Glow effect
                iconImage(size: 80)
                    .blur(radius: 5)
                    .opacity(iconAnimated ? 0.6 : 0)

                // Main icon
                iconImage(size: 72)
                    .symbolEffect(.bounce, options: .nonRepeating, value: isActive)
            }
            .scaleEffect(iconAnimated ? 1 : 0.5)
            .opacity(iconAnimated ? 1 : 0)

            // Title and subtitle
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .offset(y: titleAnimated ? 0 : 20)
            .opacity(titleAnimated ? 1 : 0)

            Spacer()

            // Features list
            VStack(spacing: 12) {
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

    private func animateContent() {
        // Icon animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            iconAnimated = true
        }

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
    }

    private func resetAnimations() {
        iconAnimated = false
        titleAnimated = false
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

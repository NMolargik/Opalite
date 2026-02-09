//
//  SwatchBarInfoSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

struct SwatchBarInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var appearAnimation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    // Icon with glow
                    Spacer(minLength: 60)
                    
                    ZStack {
                        // Glow effect
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(.purple)
                            .blur(radius: 20)
                            .opacity(0.6)

                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(.white)
                            .shadow(color: .purple.opacity(0.5), radius: 10)
                    }
                    .scaleEffect(appearAnimation ? 1 : 0.5)
                    .opacity(appearAnimation ? 1 : 0)
                    .accessibilityHidden(true)

                    Text("SwatchBar")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.inverseTheme)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 10)

                    Text("Your colors, always within reach")
                        .font(.subheadline)
                        .foregroundStyle(.inverseTheme)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 10)
                }

                // Features section
                VStack(spacing: 12) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        featureRow(
                            icon: feature.icon,
                            title: feature.title,
                            description: feature.description
                        )
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1 + 0.2),
                            value: appearAnimation
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Launch button
                Button {
                    HapticsManager.shared.impact(.medium)
                    AppDelegate.openSwatchBarWindow()
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.headline)
                        Text("Launch SwatchBar")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.purple, .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .opacity(appearAnimation ? 1 : 0)
                .scaleEffect(appearAnimation ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: appearAnimation)

                // Cancel link
                Button {
                    HapticsManager.shared.selection()
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut.delay(0.6), value: appearAnimation)
            }
        }
        .background {
            LinearGradient(
                colors: [
                    .purple.opacity(0.8),
                    .purple.opacity(0.4),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Feature Data

    private var features: [(icon: String, title: String, description: String)] {
        var items: [(icon: String, title: String, description: String)] = [
            (
                icon: "rectangle.on.rectangle",
                title: "Minimal Footprint",
                description: "A compact window for fast color reference. Resize it as narrow as you need."
            ),
            (
                icon: "doc.on.clipboard",
                title: "Quick Copy",
                description: "Tap any swatch to instantly copy its hex value to your clipboard."
            ),
        ]

        #if targetEnvironment(macCatalyst)
        items.append((
            icon: "eyedropper.halffull",
            title: "Color Sampling",
            description: "Use any app's color picker to sample directly from SwatchBar."
        ))
        #endif

        items.append((
            icon: "macwindow.on.rectangle",
            title: "Always Accessible",
            description: "Position it anywhere on screen while you work in other apps."
        ))

        return items
    }

    // MARK: - Feature Row

    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, y: 2)
        )
    }
}

#Preview {
    SwatchBarInfoSheet()
}

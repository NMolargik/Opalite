//
//  WatchAppInfoSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

struct WatchAppInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var appearAnimation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)
                    
                    ZStack {
                        Image(systemName: "applewatch")
                            .font(.system(size: 70))
                            .foregroundStyle(.blue)
                            .blur(radius: 20)
                            .opacity(0.6)

                        Image(systemName: "applewatch")
                            .font(.system(size: 70))
                            .foregroundStyle(.white)
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                    }
                    .scaleEffect(appearAnimation ? 1 : 0.5)
                    .opacity(appearAnimation ? 1 : 0)
                    .accessibilityHidden(true)

                    Text("Opalite for Apple Watch")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.inverseTheme)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 10)

                    Text("Your colors, on your wrist")
                        .font(.subheadline)
                        .foregroundStyle(.inverseTheme)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 10)
                }
                .padding(.top, 20)

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

                // How it works section
                VStack(alignment: .leading, spacing: 12) {
                    Text("How Syncing Works")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        syncInfoRow(
                            number: "1",
                            text: "Colors and palettes sync automatically when your iPhone app is active"
                        )
                        syncInfoRow(
                            number: "2",
                            text: "Your Watch requests the latest data when the Watch app opens"
                        )
                        syncInfoRow(
                            number: "3",
                            text: "Pull to refresh on the Watch to manually sync anytime"
                        )
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                }
                .padding(.top, 24)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut.delay(0.5), value: appearAnimation)

                // Done button
                Button {
                    HapticsManager.shared.selection()
                    dismiss()
                } label: {
                    Text("Got It")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 30)
                .opacity(appearAnimation ? 1 : 0)
                .scaleEffect(appearAnimation ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6), value: appearAnimation)
            }
        }
        .background {
            LinearGradient(
                colors: [
                    .blue.opacity(0.8),
                    .blue.opacity(0.4),
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
        [
            (
                icon: "paintpalette.fill",
                title: "Browse Your Colors",
                description: "Access all your colors and palettes right from your wrist."
            ),
            (
                icon: "doc.on.clipboard",
                title: "Copy Hex Codes",
                description: "Tap any color to copy its hex code to your iPhone's clipboard."
            ),
            (
                icon: "arrow.triangle.2.circlepath",
                title: "Automatic Sync",
                description: "Colors sync directly from your iPhone for fast, reliable access."
            ),
            (
                icon: "iphone.and.arrow.forward",
                title: "Works Offline",
                description: "Once synced, your colors are cached on the Watch for offline use."
            )
        ]
    }

    // MARK: - Feature Row

    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
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

    // MARK: - Sync Info Row

    @ViewBuilder
    private func syncInfoRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WatchAppInfoSheet()
}

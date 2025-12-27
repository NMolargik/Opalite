//
//  OnboardingView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

// MARK: - Onboarding Page Model

struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let text: String
    let requiresOnyx: Bool

    init(icon: String, iconColor: Color = .primary, text: String, requiresOnyx: Bool = false) {
        self.icon = icon
        self.iconColor = iconColor
        self.text = text
        self.requiresOnyx = requiresOnyx
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false
    var onContinue: () -> Void

    @State private var currentPage: Int = 0
    @State private var hasAppeared: Bool = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "paintpalette.fill",
            iconColors: [.blue, .cyan],
            title: "Create Colors",
            subtitle: "Capture and craft the perfect colors for your projects",
            features: [
                OnboardingFeature(icon: "square.grid.3x3.fill", iconColor: .blue, text: "Pick from a color grid"),
                OnboardingFeature(icon: "rainbow", iconColor: .purple, text: "Select from the spectrum"),
                OnboardingFeature(icon: "slider.horizontal.3", iconColor: .green, text: "Fine-tune with sliders"),
                OnboardingFeature(icon: "number", iconColor: .orange, text: "Enter exact color codes"),
                OnboardingFeature(icon: "eyedropper.halffull", iconColor: .pink, text: "Sample from images")
            ]
        ),
        OnboardingPage(
            icon: "swatchpalette.fill",
            iconColors: [.purple, .yellow, .red],
            title: "Organize with Palettes",
            subtitle: "Group your colors into meaningful collections",
            features: [
                OnboardingFeature(icon: "rectangle.stack.fill", iconColor: .blue, text: "Create unlimited palettes", requiresOnyx: true),
                OnboardingFeature(icon: "building.2.fill", iconColor: .indigo, text: "Organize colors by brand or project"),
                OnboardingFeature(icon: "hand.tap.fill", iconColor: .teal, text: "Drag to assign colors"),
                OnboardingFeature(icon: "magnifyingglass", iconColor: .green, text: "Search across all colors"),
                OnboardingFeature(icon: "character.cursor.ibeam", iconColor: .orange, text: "Name and annotate each color")
            ]
        ),
        OnboardingPage(
            icon: "pencil.and.scribble",
            iconColors: [.red, .orange],
            title: "Draw & Design",
            subtitle: "Bring your colors to life on a creative canvas",
            features: [
                OnboardingFeature(icon: "pencil.tip", iconColor: .blue, text: "Sketch with your colors", requiresOnyx: true),
                OnboardingFeature(icon: "square.on.square.dashed", iconColor: .purple, text: "Draw shapes and outlines", requiresOnyx: true),
                OnboardingFeature(icon: "pencil.and.scribble", iconColor: .pink, text: "Draw precisely with Apple Pencil", requiresOnyx: true),
                OnboardingFeature(icon: "doc.fill.badge.plus", iconColor: .green, text: "Create multiple canvases", requiresOnyx: true),
            ]
        ),
        OnboardingPage(
            icon: "square.and.arrow.up.fill",
            iconColors: [.green],
            title: "Share Your Work",
            subtitle: "Export and share colors in versatile formats",
            features: [
                OnboardingFeature(icon: "photo.fill", iconColor: .blue, text: "Share colors as flat images"),
                OnboardingFeature(icon: "arrow.down.doc.fill", iconColor: .purple, text: "Import colors and palettes", requiresOnyx: true),
                OnboardingFeature(icon: "arrow.up.doc.fill", iconColor: .indigo, text: "Export colors and palettes", requiresOnyx: true),
                OnboardingFeature(icon: "doc.richtext.fill", iconColor: .red, text: "Generate detailed PDFs", requiresOnyx: true),
            ]
        ),
        OnboardingPage(
            icon: "icloud.fill",
            iconColors: [.blue, .gray],
            title: "Sync Everywhere",
            subtitle: "Your colors, palettes, and canvases follow you across Apple devices",
            features: [
                OnboardingFeature(icon: "lock.shield.fill", iconColor: .green, text: "Private storage within iCloud"),
                OnboardingFeature(icon: "iphone", iconColor: .blue, text: "Access on iPhone"),
                OnboardingFeature(icon: "ipad", iconColor: .purple, text: "Access on iPad"),
                OnboardingFeature(icon: "macbook", iconColor: .gray, text: "Access on Mac"),
                OnboardingFeature(icon: "arrow.triangle.2.circlepath", iconColor: .orange, text: "Automatic sync")
            ]
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()

                        Button {
                            HapticsManager.shared.selection()
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .accessibilityLabel("Skip introduction")
                        .accessibilityHint("Skips remaining pages and enters the app")
                        .opacity(currentPage < pages.count - 1 ? 1 : 0)
                        .accessibilityHidden(currentPage >= pages.count - 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Page content
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            OnboardingPageView(
                                page: page,
                                isActive: currentPage == index,
                                geometry: geometry
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)

                    // Bottom controls
                    VStack(spacing: 20) {
                        // Navigation buttons
                        HStack(spacing: 8) {
                            // Back button
                            if currentPage > 0 {
                                Button {
                                    HapticsManager.shared.selection()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        currentPage -= 1
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(.ultraThinMaterial, in: Capsule())
                                }
                                .accessibilityLabel("Back")
                                .accessibilityHint("Goes to the previous page")
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }

                            Spacer()
                            
                            // Page indicator
                            HStack(spacing: 4) {
                                ForEach(0..<pages.count, id: \.self) { index in
                                    Capsule()
                                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                                }
                            }
                            .padding(.bottom, 8)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Page \(currentPage + 1) of \(pages.count)")
                            
                            Spacer()

                            // Next / Get Started button
                            Button {
                                HapticsManager.shared.selection()
                                if currentPage < pages.count - 1 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        currentPage += 1
                                    }
                                } else {
                                    completeOnboarding()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(currentPage < pages.count - 1 ? "Next" : "Done")
                                    Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "arrow.right")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .glassIfAvailable(
                                    GlassConfiguration(style: .clear)
                                        .tint(.blue)
                                        .interactive()
                                )
                            }
                            .accessibilityLabel(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .accessibilityHint(currentPage < pages.count - 1 ? "Goes to the next page" : "Completes introduction and enters the app")
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 20 : 32)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                hasAppeared = true
            }
        }
    }

    private func completeOnboarding() {
        HapticsManager.shared.impact(.medium)
        isOnboardingComplete = true
        onContinue()
    }
}

#Preview {
    OnboardingView(
        onContinue: {}
    )
}

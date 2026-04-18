//
//  OnyxInfoSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 4/18/26.
//

import SwiftUI

struct OnyxInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var appearAnimation = false

    // MARK: - Onyx Palette
    private let onyxBlack = Color(red: 0.06, green: 0.06, blue: 0.08)
    private let onyxSlate = Color(red: 0.14, green: 0.14, blue: 0.18)
    private let onyxCharcoal = Color(red: 0.22, green: 0.22, blue: 0.26)
    private let onyxSilver = Color(red: 0.72, green: 0.72, blue: 0.78)
    private let onyxAccent = Color(red: 0.38, green: 0.34, blue: 0.50) // deep muted violet

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)

                    ZStack {
                        Image("onyxgem")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110)
                            .blur(radius: 20)
                            .opacity(0.5)

                        Image("onyxgem")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110)
                            .shadow(color: onyxAccent.opacity(0.6), radius: 12)
                    }
                    .scaleEffect(appearAnimation ? 1 : 0.5)
                    .opacity(appearAnimation ? 1 : 0)
                    .accessibilityHidden(true)

                    Text("Opalite Onyx")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 10)

                    Text("Unlock the full power of Opalite")
                        .font(.subheadline)
                        .foregroundStyle(onyxSilver)
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

                // Plans section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ways to Get Onyx")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        planInfoRow(
                            icon: "calendar",
                            title: "Annual",
                            detail: "Yearly subscription — the best recurring value."
                        )
                        planInfoRow(
                            icon: "infinity",
                            title: "Lifetime",
                            detail: "One-time purchase — keep Onyx forever."
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 24)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.easeOut.delay(0.5), value: appearAnimation)
            }
            .padding(.bottom, 30)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                HapticsManager.shared.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(onyxSilver)
                    .frame(width: 30, height: 30)
                    .background(onyxSlate.opacity(0.8), in: Circle())
                    .overlay(Circle().stroke(onyxCharcoal, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Close")
        }
        .background {
            LinearGradient(
                colors: [
                    onyxBlack,
                    onyxSlate,
                    onyxBlack
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
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
                icon: "swatchpalette.fill",
                title: "Unlimited Palettes",
                description: "Go beyond the 5-palette free limit and organize as many palettes as your work demands."
            ),
            (
                icon: "scribble",
                title: "Unlimited Canvases",
                description: "Create as many PencilKit drawing canvases as you like — the free tier includes one."
            ),
            (
                icon: "person.2.fill",
                title: "Save From The Community",
                description: "Save colors and palettes shared by other Opalite users directly into your portfolio."
            ),
            (
                icon: "square.and.arrow.up",
                title: "Export Data Files",
                description: "Share colors and palettes as Procreate, Adobe ASE, SwiftUI, CSS, GIMP, and PDF files."
            ),
            (
                icon: "square.and.arrow.down",
                title: "Import Data Files",
                description: "Bring palettes and colors from your favorite design tools straight into Opalite."
            )
        ]
    }

    // MARK: - Feature Row

    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(onyxBlack)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(onyxAccent.opacity(0.4), lineWidth: 0.75))

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(onyxSilver)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(onyxSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(onyxSlate)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(onyxCharcoal, lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.45), radius: 10, y: 3)
        )
    }

    // MARK: - Plan Info Row

    @ViewBuilder
    private func planInfoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(onyxSilver)
                .frame(width: 24, height: 24)
                .background(Circle().fill(onyxBlack))
                .overlay(Circle().stroke(onyxAccent.opacity(0.5), lineWidth: 0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(onyxSilver)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnyxInfoSheet()
}

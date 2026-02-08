//
//  ColorBlindnessBannerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

/// Persistent banner shown when color blindness simulation is active.
///
/// Displays the current simulation mode and provides a dismiss button
/// to quickly turn off the simulation.
struct ColorBlindnessBannerView: View {
    let mode: ColorBlindnessMode
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.body.bold())
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Color Blindness Simulation")
                        .font(.caption.bold())
                        .foregroundStyle(.white)

                    Text(mode.shortTitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Button {
                    HapticsManager.shared.selection()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Turn off simulation")
                .accessibilityHint("Disables color blindness simulation and returns to normal colors")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.gradient)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            )

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}

#Preview("Protanopia") {
    VStack {
        ColorBlindnessBannerView(mode: .protanopia) { }
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Deuteranopia") {
    VStack {
        ColorBlindnessBannerView(mode: .deuteranopia) { }
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Tritanopia") {
    VStack {
        ColorBlindnessBannerView(mode: .tritanopia) { }
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

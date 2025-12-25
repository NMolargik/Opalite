//
//  OnboardingFeatureRow.swift
//  Opalite
//
//  Created by Nick Molargik on 12/25/25.
//

import SwiftUI

struct OnboardingFeatureRow: View {
    let feature: OnboardingFeature

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: feature.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(feature.iconColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(feature.iconColor.opacity(0.15))
                )
                .accessibilityHidden(true)

            // Text
            Text(feature.text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            // Onyx badge if required
            if feature.requiresOnyx {
                Text("Onyx")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.text + (feature.requiresOnyx ? ", requires Onyx subscription" : ""))
    }
}

#Preview {
    OnboardingFeatureRow(feature: OnboardingFeature(icon: "plus", text: "feature", requiresOnyx: true))
}

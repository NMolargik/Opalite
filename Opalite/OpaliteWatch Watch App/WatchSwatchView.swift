//
//  WatchSwatchView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI

struct WatchSwatchView: View {
    let color: WatchColor
    let badgeText: String

    @Environment(WatchColorManager.self) private var colorManager
    @Environment(\.colorSchemeContrast) private var systemContrast

    @ScaledMetric(relativeTo: .body) private var swatchHeight: CGFloat = 60

    private var isHighContrast: Bool {
        systemContrast == .increased || colorManager.highContrastEnabled
    }

    init(color: WatchColor) {
        self.color = color
        if let name = color.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            self.badgeText = name
        } else {
            self.badgeText = color.hexString
        }
    }

    var body: some View {
        NavigationLink {
            WatchColorDetailView(color: color)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.swiftUIColor)
                .frame(height: swatchHeight)
                .overlay(alignment: .topLeading) {
                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if isHighContrast {
                                Capsule().fill(Color.black.opacity(0.85))
                            } else {
                                Capsule().fill(.ultraThinMaterial)
                            }
                        }
                        .padding(6)
                }
                .overlay {
                    if isHighContrast {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.voiceOverDescription)
        .accessibilityHint("Opens color details")
    }
}

#Preview {
    NavigationStack {
        WatchSwatchView(color: WatchColor.sample)
            .environment(WatchColorManager())
    }
}

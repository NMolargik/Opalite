//
//  WatchSwatchView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI
import SwiftData
import WatchKit

struct WatchSwatchView: View {
    let color: OpaliteColor
    let badgeText: String

    @Environment(WatchColorManager.self) private var colorManager
    @State private var showCopiedFeedback: Bool = false

    private let sessionManager = WatchSessionManager.shared

    init(color: OpaliteColor) {
        self.color = color
        // Show name if available, otherwise hex
        if let name = color.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            self.badgeText = "\(name) - \(color.hexString)"
        } else {
            self.badgeText = color.hexString
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(color.swiftUIColor)
            .frame(height: 60)
            .overlay(alignment: .topLeading) {
                Text(badgeText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color.idealTextColor())
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(6)
            }
            .overlay {
                // Hex copy feedback overlay
                if showCopiedFeedback {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "number")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(color.idealTextColor())
                        }
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                copyHex()
            }
    }

    private func copyHex() {
        // Show immediate feedback
        WKInterfaceDevice.current().play(.click)

        withAnimation(.easeIn(duration: 0.1)) {
            showCopiedFeedback = true
        }

        // Send hex to iPhone clipboard via WatchConnectivity
        let hex = colorManager.formattedHex(for: color)
        sessionManager.copyHexToiPhone(hex, colorName: color.name)

        // Hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
}

#Preview {
    WatchSwatchView(color: OpaliteColor(
        name: "Ocean Blue",
        red: 0.2,
        green: 0.5,
        blue: 0.8
    ))
    .environment(WatchColorManager(context: try! ModelContainer(
        for: OpaliteColor.self, OpalitePalette.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ).mainContext))
}

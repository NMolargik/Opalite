//
//  TVOLEDRefreshView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Full-screen OLED refresh mode that cycles through colors to help reduce image retention.
/// Press Back on the remote to exit.
struct TVOLEDRefreshView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentColorIndex: Int = 0
    @State private var isRunning: Bool = true

    /// Colors to cycle through for OLED refresh
    private let refreshColors: [Color] = [
        .red,
        .green,
        .blue,
        .white,
        .cyan,
        Color(red: 1, green: 0, blue: 1), // Magenta
        .yellow,
        .orange,
        .purple,
        .pink,
        .black
    ]

    /// Time interval between color changes (in seconds)
    private let cycleInterval: TimeInterval = 4.0

    private var currentColor: Color {
        refreshColors[currentColorIndex]
    }

    var body: some View {
        currentColor
            .ignoresSafeArea()
            .onAppear {
                startCycling()
            }
            .onDisappear {
                isRunning = false
            }
            .onExitCommand {
                dismiss()
            }
    }

    private func startCycling() {
        Task {
            while isRunning {
                try? await Task.sleep(for: .seconds(cycleInterval))
                if isRunning {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            currentColorIndex = (currentColorIndex + 1) % refreshColors.count
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TVOLEDRefreshView()
}

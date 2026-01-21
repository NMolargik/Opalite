//
//  WatchSyncingView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

/// View displayed while waiting for data to sync from iPhone.
struct WatchSyncingView: View {
    @Environment(WatchColorManager.self) private var colorManager

    @State private var dotCount: Int = 0
    @State private var pulseScale: CGFloat = 1.0

    /// Animated dots for the loading indicator
    private var animatedDots: String {
        String(repeating: ".", count: dotCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // iPhone icon with pulse animation
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            VStack(spacing: 6) {
                Text("Syncing")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("with iPhone" + animatedDots)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 16)
            }

            Spacer()

            // Progress indicator
            ProgressView()
                .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            pulseScale = 1.1
            startDotAnimation()
        }
        .task {
            await colorManager.performInitialSync()
        }
    }

    /// Animates the loading dots
    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if colorManager.hasCompletedInitialSync {
                timer.invalidate()
                return
            }
            withAnimation {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

#Preview {
    WatchSyncingView()
        .environment(WatchColorManager())
}

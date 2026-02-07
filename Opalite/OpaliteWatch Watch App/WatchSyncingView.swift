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

            if colorManager.isPhoneReachable {
                reachableContent
            } else {
                unreachableContent
            }

            Spacer()

            ProgressView()
                .tint(colorManager.isPhoneReachable ? .blue : .orange)
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

    // MARK: - Reachable State

    private var reachableContent: some View {
        Group {
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
        }
    }

    // MARK: - Unreachable State

    private var unreachableContent: some View {
        Group {
            Image(systemName: "iphone.slash")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                Text("iPhone Not Connected")
                    .font(.headline)
                    .fontWeight(.semibold)

                if colorManager.hasCachedData {
                    Text("Loading cached colors" + animatedDots)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(height: 16)
                } else {
                    Text("Open Opalite on your iPhone to sync your colors.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// Animates the loading dots using async/await instead of Timer
    private func startDotAnimation() {
        Task { @MainActor in
            while !colorManager.hasCompletedInitialSync {
                try? await Task.sleep(for: .milliseconds(500))
                guard !colorManager.hasCompletedInitialSync else { break }
                withAnimation {
                    dotCount = (dotCount + 1) % 4
                }
            }
        }
    }
}

#Preview {
    WatchSyncingView()
        .environment(WatchColorManager())
}

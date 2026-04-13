//
//  TVSyncingView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// View displayed at launch while waiting for iCloud data to sync.
///
/// Shows a loading indicator and status message while the app fetches
/// any existing data from iCloud. Automatically continues to the main
/// view after data loads or a timeout period elapses.
struct TVSyncingView: View {
    @Environment(ColorManager.self) private var colorManager

    let onComplete: () -> Void

    @State private var statusMessage: String = "Checking for your data..."
    @State private var hasTimedOut: Bool = false
    @State private var dotCount: Int = 0

    /// Maximum time to wait for sync before continuing (in seconds)
    private let syncTimeout: TimeInterval = 30

    /// How often to re-check for newly synced data (in seconds)
    private let pollInterval: TimeInterval = 2

    /// Animated dots for the loading indicator
    private var animatedDots: String {
        String(repeating: ".", count: dotCount)
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // iCloud icon with animation
            Image(systemName: "icloud.fill")
                .font(.system(size: 120))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                Text("Opalite is Syncing with iCloud")
                    .font(.title)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Text(statusMessage + animatedDots)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel(statusMessage)
            }

            Spacer()

            // Progress indicator
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Syncing in progress")

            Text("Free iCloud storage space is required to sync between devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await performSync()
        }
        .onAppear {
            startDotAnimation()
        }
    }

    /// Animates the loading dots
    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if hasTimedOut {
                timer.invalidate()
                return
            }
            withAnimation {
                dotCount = (dotCount + 1) % 4
            }
        }
    }

    /// Performs the iCloud sync with polling and timeout.
    ///
    /// CloudKit imports records into the local SwiftData store asynchronously.
    /// `refreshAll()` only reads the local store, so we poll repeatedly to pick
    /// up records as they arrive. We also track whether the count is still growing
    /// — if it stabilises for two consecutive polls, we consider sync complete.
    private func performSync() async {
        let startTime = Date()
        var previousCount = 0
        var stablePolls = 0

        await MainActor.run {
            statusMessage = "Checking for your data"
        }

        // Poll until data stabilises or we hit the timeout
        while Date().timeIntervalSince(startTime) < syncTimeout {
            await colorManager.refreshAll()

            let colorCount = colorManager.colors.count
            let paletteCount = colorManager.palettes.count
            let currentCount = colorCount + paletteCount

            if currentCount > 0 {
                await MainActor.run {
                    var found: [String] = []
                    if colorCount > 0 { found.append("\(colorCount) color\(colorCount == 1 ? "" : "s")") }
                    if paletteCount > 0 { found.append("\(paletteCount) palette\(paletteCount == 1 ? "" : "s")") }
                    statusMessage = "Found " + found.joined(separator: ", ")
                }

                // If the count hasn't changed since last poll, it may be done
                if currentCount == previousCount {
                    stablePolls += 1
                    if stablePolls >= 2 {
                        // Count stable for 2 consecutive polls — sync likely complete
                        break
                    }
                } else {
                    stablePolls = 0
                }
            } else {
                await MainActor.run {
                    statusMessage = "Waiting for iCloud"
                }
            }

            previousCount = currentCount
            try? await Task.sleep(for: .seconds(pollInterval))
        }

        // Final refresh to catch any last-moment arrivals
        await colorManager.refreshAll()

        let hasData = !colorManager.colors.isEmpty || !colorManager.palettes.isEmpty

        await MainActor.run {
            if !hasData {
                statusMessage = "Ready to create"
            }
        }

        // Brief pause to show the final result
        try? await Task.sleep(for: .seconds(1.5))

        await MainActor.run {
            hasTimedOut = true
            completeSync()
        }
    }

    private func completeSync() {
        onComplete()
    }
}

#Preview {
    TVSyncingView(onComplete: {})
}

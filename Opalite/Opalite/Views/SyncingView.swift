//
//  SyncingView.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import SwiftUI

/// View displayed after onboarding while waiting for iCloud data to sync.
///
/// Shows a loading indicator and status message while the app fetches
/// any existing data from iCloud. Automatically continues to the main
/// view after data loads or a timeout period elapses.
struct SyncingView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(CanvasManager.self) private var canvasManager

    let onComplete: () -> Void

    @State private var statusMessage: String = "Checking for your data..."
    @State private var hasTimedOut: Bool = false
    @State private var dotCount: Int = 0

    /// Maximum time to wait for sync before continuing (in seconds)
    private let syncTimeout: TimeInterval = 8

    /// Animated dots for the loading indicator
    private var animatedDots: String {
        String(repeating: ".", count: dotCount)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // iCloud icon with animation
            Image(systemName: "icloud.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Opalite is Syncing with iCloud")
                    .font(.title2)
                    .bold()

                Text(statusMessage + animatedDots)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Progress indicator
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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

    /// Performs the iCloud sync with timeout
    private func performSync() async {
        // Start a timeout task
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(syncTimeout))
            if !Task.isCancelled {
                await MainActor.run {
                    hasTimedOut = true
                    completeSync()
                }
            }
        }

        // Refresh data from CloudKit
        await MainActor.run {
            statusMessage = "Looking for colors and palettes"
        }

        await colorManager.refreshAll()

        await MainActor.run {
            statusMessage = "Looking for canvases"
        }

        await canvasManager.refreshAll()

        // Small delay to ensure CloudKit has time to process
        try? await Task.sleep(for: .seconds(1))

        // Check if we found any data
        let hasColors = !colorManager.colors.isEmpty
        let hasPalettes = !colorManager.palettes.isEmpty
        let hasCanvases = !canvasManager.canvases.isEmpty

        await MainActor.run {
            if hasColors || hasPalettes || hasCanvases {
                var found: [String] = []
                if hasColors { found.append("\(colorManager.colors.count) color\(colorManager.colors.count == 1 ? "" : "s")") }
                if hasPalettes { found.append("\(colorManager.palettes.count) palette\(colorManager.palettes.count == 1 ? "" : "s")") }
                if hasCanvases { found.append("\(canvasManager.canvases.count) canvas\(canvasManager.canvases.count == 1 ? "" : "es")") }
                statusMessage = "Found " + found.joined(separator: ", ")
            } else {
                statusMessage = "Ready to create"
            }
        }

        // Brief pause to show the result
        try? await Task.sleep(for: .seconds(1.5))

        // Cancel the timeout and complete
        timeoutTask.cancel()

        await MainActor.run {
            if !hasTimedOut {
                completeSync()
            }
        }
    }

    private func completeSync() {
        HapticsManager.shared.impact(.light)
        onComplete()
    }
}

#Preview {
    SyncingView(onComplete: {})
}

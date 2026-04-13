//
//  SyncingView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftData
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
    private let syncTimeout: TimeInterval = 30

    /// How often to re-check for newly synced data (in seconds)
    private let pollInterval: TimeInterval = 2

    /// Animated dots for the loading indicator
    private var animatedDots: String {
        String(repeating: ".", count: dotCount)
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Animated edge gradients
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                EdgeGradientsView(time: time)
            }

            // Main content
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
                        .frame(width: 300)
                        .frame(height: 20)
                }

                Spacer()

                // Progress indicator
                ProgressView()
                    .controlSize(.large)

                Text("Free iCloud storage space is required to sync between devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
            await canvasManager.refreshAll()

            let colorCount = colorManager.colors.count
            let paletteCount = colorManager.palettes.count
            let canvasCount = canvasManager.canvases.count
            let currentCount = colorCount + paletteCount + canvasCount

            if currentCount > 0 {
                await MainActor.run {
                    var found: [String] = []
                    if colorCount > 0 { found.append("\(colorCount) color\(colorCount == 1 ? "" : "s")") }
                    if paletteCount > 0 { found.append("\(paletteCount) palette\(paletteCount == 1 ? "" : "s")") }
                    if canvasCount > 0 { found.append("\(canvasCount) canvas\(canvasCount == 1 ? "" : "es")") }
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
        await canvasManager.refreshAll()

        let hasData = !colorManager.colors.isEmpty || !colorManager.palettes.isEmpty || !canvasManager.canvases.isEmpty

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
        #if !os(visionOS)
        HapticsManager.shared.impact(.light)
        #endif
        onComplete()
    }
}

// MARK: - Edge Gradients View

/// Animated gradient overlay for the syncing view edges
private struct EdgeGradientsView: View {
    let time: TimeInterval

    /// Speed multiplier for the pulsing animation (lower = slower)
    private let speed: Double = 2.0

    /// Compute a pulsing opacity value
    private func pulse(_ offset: Double, baseOpacity: Double = 0.35) -> Double {
        let wave = sin(time * speed + offset)
        // Map sin (-1 to 1) to opacity range (0.15 to baseOpacity)
        return baseOpacity * 0.4 + baseOpacity * 0.6 * (wave * 0.5 + 0.5)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            // Top edge gradient
            EllipticalGradient(
                colors: [
                    Color.cyan.opacity(pulse(0, baseOpacity: 0.5)),
                    Color.blue.opacity(pulse(1, baseOpacity: 0.4)),
                    Color.clear
                ],
                center: .top,
                startRadiusFraction: 0,
                endRadiusFraction: 0.6
            )
            .frame(height: size.height * 0.5)
            .position(x: size.width / 2, y: 0)
            .blur(radius: 40)

            // Bottom edge gradient
            EllipticalGradient(
                colors: [
                    Color.purple.opacity(pulse(2, baseOpacity: 0.45)),
                    Color.indigo.opacity(pulse(3, baseOpacity: 0.35)),
                    Color.clear
                ],
                center: .bottom,
                startRadiusFraction: 0,
                endRadiusFraction: 0.6
            )
            .frame(height: size.height * 0.5)
            .position(x: size.width / 2, y: size.height)
            .blur(radius: 40)

            // Left edge gradient
            EllipticalGradient(
                colors: [
                    Color.teal.opacity(pulse(4, baseOpacity: 0.4)),
                    Color.mint.opacity(pulse(5, baseOpacity: 0.3)),
                    Color.clear
                ],
                center: .leading,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .frame(width: size.width * 0.5)
            .position(x: 0, y: size.height / 2)
            .blur(radius: 30)

            // Right edge gradient
            EllipticalGradient(
                colors: [
                    Color.blue.opacity(pulse(6, baseOpacity: 0.45)),
                    Color.cyan.opacity(pulse(7, baseOpacity: 0.35)),
                    Color.clear
                ],
                center: .trailing,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .frame(width: size.width * 0.5)
            .position(x: size.width, y: size.height / 2)
            .blur(radius: 30)

            // Corner accents - top left
            RadialGradient(
                colors: [
                    Color.indigo.opacity(pulse(0.5, baseOpacity: 0.35)),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: size.width * 0.4
            )
            .blur(radius: 20)

            // Corner accents - top right
            RadialGradient(
                colors: [
                    Color.purple.opacity(pulse(1.5, baseOpacity: 0.3)),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: size.width * 0.35
            )
            .blur(radius: 20)

            // Corner accents - bottom left
            RadialGradient(
                colors: [
                    Color.teal.opacity(pulse(2.5, baseOpacity: 0.3)),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: size.width * 0.35
            )
            .blur(radius: 20)

            // Corner accents - bottom right
            RadialGradient(
                colors: [
                    Color.cyan.opacity(pulse(3.5, baseOpacity: 0.35)),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: size.width * 0.4
            )
            .blur(radius: 20)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpaliteColor.self,
            OpalitePalette.self,
            CanvasFile.self,
        configurations: config
    )

    let context = container.mainContext

    return SyncingView(onComplete: {})
        .modelContainer(container)
        .environment(ColorManager(context: context))
        .environment(CanvasManager(context: context))
}

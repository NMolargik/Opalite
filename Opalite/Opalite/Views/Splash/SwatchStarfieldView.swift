//
//  SwatchStarfieldView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI

// MARK: - Starfield (SwatchView-based)

/// A fun "Star Wars hyperspace" style starfield made out of SwatchViews.
///
/// - Stars are small SwatchViews that grow as they approach the camera (z -> 0).
/// - They appear to fly toward the viewer and then respawn far away.
/// - Uses TimelineView for smooth, system-driven animation.
struct SwatchStarfieldView: View {
    struct Star: Identifiable {
        let id = UUID()
        var x: CGFloat          // normalized [-1, 1]
        var y: CGFloat          // normalized [-1, 1]
        var z: CGFloat          // depth (0...1], where smaller is closer
        var speed: CGFloat      // depth units per second
        var baseSize: CGFloat   // base size in points at z ~= 1
        var fill: OpaliteColor
        var cornerRadius: CGFloat
        var phase: CGFloat
    }

    // Tweakables
    var starCount: Int = 55
    var minSpeed: CGFloat = 0.2
    var maxSpeed: CGFloat = 0.6
    var minBaseSize: CGFloat = 24
    var maxBaseSize: CGFloat = 50
    var totalDuration: CGFloat = 12.0
    var rampDuration: CGFloat = 4.0

    /// How aggressively stars "spread" as they get closer.
    /// Larger values push stars outward more dramatically.
    var perspective: CGFloat = 1.25

    /// How close a star can get before we recycle it.
    private let nearZ: CGFloat = 0.06

    @State private var stars: [Star] = []
    @State private var startDate: Date = .now

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation) { context in
                    let t = CGFloat(context.date.timeIntervalSince(startDate))

                    // Stop abruptly after totalDuration seconds
                    if t >= totalDuration {
                        EmptyView()
                    } else {
                        // Ramp from 1 star -> starCount over rampDuration
                        let ramp = min(1.0, max(0.0, t / max(rampDuration, 0.001)))
                        let eased = ramp * ramp * (3 - 2 * ramp) // smoothstep
                        let visibleCount = max(1, Int(round(CGFloat(starCount) * eased)))

                        ZStack {
                            ForEach(stars.prefix(visibleCount)) { star in
                                starView(star, now: context.date, elapsed: t, in: geo.size)
                            }
                        }
                        .compositingGroup()
                        .drawingGroup() // Render to Metal texture for better animation performance
                    }
                }
            }
            .onAppear {
                // Generate once we know geometry
                if stars.isEmpty {
                    stars = (0..<starCount).map { _ in
                        spawnStar()
                    }
                }
                startDate = .now
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Rendering

    @ViewBuilder
    private func starView(_ star: Star, now: Date, elapsed t: CGFloat, in size: CGSize) -> some View {
        // Non-repeating flight: start far, move toward the viewer, then we're done.
        // Use a negative offset so stars don't all begin at the same depth.
        let startOffset = -star.phase * 0.75
        let rawProgress = (t * star.speed) + startOffset
        let progress = min(1.0, max(0.0, rawProgress)) // clamp (no looping)

        // Map progress into depth, keeping a small near plane to avoid singularities.
        let animatedZ = max(nearZ, 1.0 - progress * (1.0 - nearZ))

        // Perspective projection.
        // z in (0,1] => invZ in [1, +inf)
        let invZ = max(1, 1 / max(animatedZ, 0.001))

        // Project normalized x/y to screen space.
        // Multiply by invZ so stars drift outward as they approach.
        let halfW = size.width / 2
        let halfH = size.height / 2

        let px = halfW + (star.x * halfW) * invZ * perspective
        let py = halfH + (star.y * halfH) * invZ * perspective

        // Size grows as star approaches.
        let starSize = star.baseSize * invZ

        // Fade in slightly as they get closer (prevents harsh popping)
        let alpha = min(1.0, max(0.0, Double((1.0 - animatedZ) * 1.35)))

        SwatchView(
            color: star.fill,
            width: starSize,
            height: starSize,
            badgeText: "",
            showOverlays: false
        )
        .opacity(alpha)
        .clipShape(RoundedRectangle(cornerRadius: star.cornerRadius, style: .continuous))
        .position(x: px, y: py)
        // Little bit of motion blur vibe via subtle scale transition when recycling
        .transition(.scale)
        // Skip hit testing to keep it lightweight
        .allowsHitTesting(false)
    }

    private func spawnStar() -> Star {
        // x/y normalized so we can re-project for any screen size
        let x = CGFloat.random(in: -1...1)
        let y = CGFloat.random(in: -1...1)

        let speed = CGFloat.random(in: minSpeed...maxSpeed)
        let baseSize = CGFloat.random(in: minBaseSize...maxBaseSize)

        // Make the fills "spacey": mostly white/blue with the occasional colorful streak
        let fill = randomSpaceFill()

        // Some stars are more "rect" and some more "pill".

        let phase = CGFloat.random(in: 0...1)

        return Star(
            x: x,
            y: y,
            z: 1.0,
            speed: speed,
            baseSize: baseSize,
            fill: fill,
            cornerRadius: 16,
            phase: phase
        )
    }

    private func hsvToRgb(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        // h: 0...1
        let hh = (h.truncatingRemainder(dividingBy: 1.0)) * 6.0
        let i = Int(hh)
        let f = hh - Double(i)
        let p = v * (1.0 - s)
        let q = v * (1.0 - s * f)
        let t = v * (1.0 - s * (1.0 - f))

        switch i {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    private func randomSpaceFill() -> OpaliteColor {
        // We want a lot of variety in star colors.
        // Keep a small amount of white-ish stars for realism, but bias toward vivid colors.

        // ~15%: near-white / pale stars
        if Double.random(in: 0...1) < 0.15 {
            let v = Double.random(in: 0.82...1.0)
            let tint = Double.random(in: 0.0...0.18)
            return OpaliteColor(red: v, green: v - tint * 0.4, blue: v + tint, alpha: 1.0)
        }

        // Otherwise: vivid, high-saturation stars.
        // Use HSV to guarantee bright, saturated colors.
        let hue = Double.random(in: 0...1)
        let sat = Double.random(in: 0.75...1.0)
        let val = Double.random(in: 0.82...1.0)
        let (r, g, b) = hsvToRgb(h: hue, s: sat, v: val)
        return OpaliteColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

#Preview("Swatch Starfield") {
    SwatchStarfieldView(starCount: 75)
}

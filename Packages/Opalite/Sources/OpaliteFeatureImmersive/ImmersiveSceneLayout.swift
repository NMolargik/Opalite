//
//  ImmersiveSceneLayout.swift
//  OpaliteFeatureImmersive
//
//  Pure geometry for the immersive scene — where panels and orbs sit, how wide a ring panel
//  must be to close the gaps, how the scene drifts over time. No RealityKit, so it is unit
//  tested on the host and the visionOS view is a thin assembler over it.
//

import Foundation
import OpaliteCore

/// Scene dimensions are in meters, in RealityKit's right-handed space: +Y up, −Z forward.
nonisolated public enum ImmersiveSceneLayout {

    // MARK: - Constants

    /// Standing eye height; everything is centered here so the viewer is inside the scene.
    public static let eyeHeight: Float = 1.5
    /// The enveloping sphere's radius in single-color mode.
    public static let sphereRadius: Float = 50
    /// The ring of palette panels sits this far from the viewer.
    public static let ringRadius: Float = 5
    /// Palette panels are this tall, centered at eye height.
    public static let panelHeight: Float = 10
    /// Harmony orbs float on an arc this far in front of the viewer.
    public static let orbRingRadius: Float = 2.2
    /// Harmony orb radius.
    public static let orbRadius: Float = 0.16
    /// The arc the harmony orbs span, centered straight ahead.
    public static let orbArc: Float = .pi * 0.75
    /// One full revolution of the palette ring takes this long.
    public static let rotationPeriod: Double = 60
    /// Orbs bob with this period and amplitude.
    public static let bobPeriod: Double = 6
    public static let bobAmplitude: Float = 0.05

    // MARK: - Palette ring

    /// The chord width of one panel in a ring of `count`, plus a hair so neighbors overlap
    /// instead of showing a seam.
    public static func panelWidth(count: Int, radius: Float = ringRadius) -> Float {
        guard count > 0 else { return 0 }
        if count == 1 { return radius * 2 * .pi }
        let anglePerPanel = (2 * Float.pi) / Float(count)
        return 2 * radius * sin(anglePerPanel / 2) + 0.02
    }

    /// Where panel `index` of `count` sits on the ring, at eye height. Index 0 is straight ahead.
    public static func panelPosition(index: Int, count: Int, radius: Float = ringRadius) -> SIMD3<Float> {
        guard count > 0 else { return SIMD3(0, eyeHeight, 0) }
        let angle = (2 * Float.pi) / Float(count) * Float(index)
        return SIMD3(sin(angle) * radius, eyeHeight, -cos(angle) * radius)
    }

    /// The floor and ceiling caps that close the enclosure.
    public static var floorHeight: Float { eyeHeight - panelHeight / 2 }
    public static var ceilingHeight: Float { eyeHeight + panelHeight / 2 }
    public static func capSide(radius: Float = ringRadius) -> Float { radius * 2.5 }

    // MARK: - Harmony orbs

    /// Where harmony orb `index` of `count` floats: spread evenly across `orbArc` in front
    /// of the viewer, slightly below eye level so they read as a constellation, not a wall.
    public static func orbPosition(index: Int, count: Int, radius: Float = orbRingRadius) -> SIMD3<Float> {
        guard count > 0 else { return SIMD3(0, eyeHeight, -radius) }
        let t: Float = count == 1 ? 0.5 : Float(index) / Float(count - 1)
        let angle = (t - 0.5) * orbArc
        // Alternate a little above and below eye level so neighbors never overlap.
        let lift: Float = index.isMultiple(of: 2) ? 0.12 : -0.12
        return SIMD3(sin(angle) * radius, eyeHeight + lift, -cos(angle) * radius)
    }

    // MARK: - Motion

    /// The palette ring's yaw at `time` seconds — one revolution per `rotationPeriod`.
    public static func rotationAngle(at time: Double) -> Float {
        Float(time.truncatingRemainder(dividingBy: rotationPeriod) / rotationPeriod) * 2 * .pi
    }

    /// A gentle vertical bob for orb `index` at `time`, phase-shifted so they don't move in unison.
    public static func bobOffset(at time: Double, index: Int) -> Float {
        let phase = Double(index) * (.pi / 3)
        return Float(sin(time / bobPeriod * 2 * .pi + phase)) * bobAmplitude
    }

    // MARK: - Color

    /// The mean of the colors — the floor and ceiling cap color for a palette ring.
    public static func average(_ colors: [RGBA]) -> RGBA {
        guard !colors.isEmpty else { return .black }
        let count = Double(colors.count)
        return RGBA(
            red: colors.reduce(0) { $0 + $1.red } / count,
            green: colors.reduce(0) { $0 + $1.green } / count,
            blue: colors.reduce(0) { $0 + $1.blue } / count
        )
    }
}

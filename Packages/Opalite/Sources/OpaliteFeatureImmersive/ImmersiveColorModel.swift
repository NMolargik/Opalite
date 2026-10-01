//
//  ImmersiveColorModel.swift
//  OpaliteFeatureImmersive
//
//  The colors the visionOS immersive space renders. Cross-platform and RealityKit-free so
//  the shell can hand it a color before opening the space, and so it is testable on the host.
//

import Foundation
import Observation
import OpaliteCore

/// The source of truth for `ColorConstellationView`: which colors to show and how.
///
/// Set the colors with `prepareForSingleColor(_:)` or `prepareForPalette(_:)` *before* calling
/// `openImmersiveSpace`; the space reads the model from the environment when it appears and
/// flips `isImmersed` while it is open.
@MainActor
@Observable
public final class ImmersiveColorModel {

    /// How the immersive scene is laid out.
    nonisolated public enum Mode: Sendable, Equatable {
        /// An enveloping sphere in the hero color with its harmonies floating as orbs.
        case singleColor
        /// Tall panels in a full ring so every direction shows a palette color.
        case palette
    }

    /// The current layout.
    public var mode: Mode = .singleColor

    /// The colors to render. In `.singleColor` mode index 0 is the hero and the rest are its
    /// harmonies; in `.palette` mode every color is an equal panel.
    public var colors: [RGBA] = []

    /// Whether the immersive space is currently open.
    public var isImmersed = false

    public init() {}

    // MARK: - Derived

    /// The enveloping color in single-color mode, or the first palette color.
    public var heroColor: RGBA? { colors.first }

    /// The harmony orbs (single-color mode only).
    public var harmonyColors: [RGBA] {
        mode == .singleColor ? Array(colors.dropFirst()) : []
    }

    /// Whether there is anything to render.
    public var hasContent: Bool { !colors.isEmpty }

    // MARK: - Preparation

    /// Prepares single-color immersion: the hero plus its complementary, analogous (2),
    /// split-complementary (2) and first triadic harmonies — six orbs around the viewer.
    public func prepareForSingleColor(_ rgba: RGBA) {
        mode = .singleColor
        colors = Self.singleColorSet(for: rgba)
    }

    /// Prepares palette immersion: every color becomes an equal panel in the ring.
    public func prepareForPalette(_ colors: [RGBA]) {
        mode = .palette
        self.colors = colors
    }

    /// The hero followed by its six harmony colors, in render order.
    nonisolated public static func singleColorSet(for hero: RGBA) -> [RGBA] {
        var set: [RGBA] = [hero]
        set.append(ColorHarmony.complementary(of: hero))
        set.append(contentsOf: ColorHarmony.analogous(of: hero))
        set.append(contentsOf: ColorHarmony.splitComplementary(of: hero))
        if let triadic = ColorHarmony.triadic(of: hero).first {
            set.append(triadic)
        }
        return set
    }
}

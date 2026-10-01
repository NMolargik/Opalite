//
//  Haptics.swift
//  OpaliteDesignSystem
//
//  Tactile feedback that's a no-op where UIKit haptics don't exist, so call sites stay
//  unconditional.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS) && !os(visionOS)
import UIKit

public enum Haptics {
    public static var isEnabled = true

    public static func lightImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func mediumImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    public static func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    public static func warning() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    public static func error() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
#else
import Foundation

public enum Haptics {
    public static var isEnabled = true
    public static func lightImpact() {}
    public static func mediumImpact() {}
    public static func selection() {}
    public static func success() {}
    public static func warning() {}
    public static func error() {}
}
#endif

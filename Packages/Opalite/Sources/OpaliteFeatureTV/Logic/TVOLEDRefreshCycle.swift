//
//  TVOLEDRefreshCycle.swift
//  OpaliteFeatureTV
//
//  The full-field color cycle that helps clear temporary image retention on OLED panels.
//

import Foundation
import OpaliteCore

nonisolated public struct TVOLEDRefreshCycle: Sendable, Equatable {
    public struct Step: Sendable, Equatable {
        public let name: String
        public let rgba: RGBA
        public init(name: String, rgba: RGBA) { self.name = name; self.rgba = rgba }
    }

    public static let standard = TVOLEDRefreshCycle(steps: [
        Step(name: String(localized: "Red"), rgba: RGBA(red: 1, green: 0, blue: 0)),
        Step(name: String(localized: "Green"), rgba: RGBA(red: 0, green: 1, blue: 0)),
        Step(name: String(localized: "Blue"), rgba: RGBA(red: 0, green: 0, blue: 1)),
        Step(name: String(localized: "White"), rgba: .white),
        Step(name: String(localized: "Cyan"), rgba: RGBA(red: 0, green: 1, blue: 1)),
        Step(name: String(localized: "Magenta"), rgba: RGBA(red: 1, green: 0, blue: 1)),
        Step(name: String(localized: "Yellow"), rgba: RGBA(red: 1, green: 1, blue: 0)),
        Step(name: String(localized: "Orange"), rgba: RGBA(red: 1, green: 0.5, blue: 0)),
        Step(name: String(localized: "Purple"), rgba: RGBA(red: 0.5, green: 0, blue: 1)),
        Step(name: String(localized: "Pink"), rgba: RGBA(red: 1, green: 0.4, blue: 0.7)),
        Step(name: String(localized: "Black"), rgba: .black),
    ])

    public let steps: [Step]
    /// Seconds each color is held.
    public let interval: Duration

    public init(steps: [Step], interval: Duration = .seconds(4)) {
        self.steps = steps
        self.interval = interval
    }

    public func step(at index: Int) -> Step? {
        guard !steps.isEmpty else { return nil }
        return steps[((index % steps.count) + steps.count) % steps.count]
    }

    public func nextIndex(after index: Int) -> Int {
        guard !steps.isEmpty else { return 0 }
        return (index + 1) % steps.count
    }
}

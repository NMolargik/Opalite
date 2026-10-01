//
//  OnboardingStep.swift
//  OpaliteCore
//
//  The onboarding pages in order. Every page is skippable per the HIG; the profile page
//  is the only one that collects input (a display name used for authorship).
//

import Foundation

nonisolated public enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome
    case portfolio
    case canvas
    case community
    case profile

    public var id: Int { rawValue }

    public var isFirst: Bool { self == Self.allCases.first }
    public var isLast: Bool { self == Self.allCases.last }

    public var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    public var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// Progress 0...1 for the page indicator.
    public var progress: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }
}

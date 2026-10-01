//
//  AppStage.swift
//  OpaliteCore
//

import Foundation

/// The app's launch stages: splash → onboarding → main.
nonisolated public enum AppStage: String, Identifiable, Sendable {
    case splash
    case onboarding
    case main

    public var id: String { rawValue }
}

//
//  CommunityFeedLogic.swift
//  OpaliteFeatureCommunity
//
//  The pure, host-testable decisions behind the Community screens: which state the feed
//  shows, the one-time display-name prompt, grid sizing per width class, and the short
//  device label on detail tiles. Views stay thin by delegating here.
//

import Foundation
import OpaliteCore

// MARK: - Feed status

/// What the feed renders for a segment, in priority order.
nonisolated public enum CommunityFeedStatus: Equatable, Sendable {
    /// No network — browsing is impossible.
    case offline
    /// No iCloud account — the public database is unavailable.
    case signedOut
    /// First page in flight with nothing cached yet (skeleton cards).
    case loading
    /// The fetch failed and nothing is cached.
    case failed
    /// The search matched nothing.
    case noResults
    /// Nothing published yet.
    case empty
    /// Items to show.
    case content

    /// Resolves the status for one segment.
    public static func resolve(
        isConnected: Bool,
        isSignedIn: Bool,
        isLoading: Bool,
        itemCount: Int,
        hasError: Bool,
        isSearching: Bool
    ) -> CommunityFeedStatus {
        if itemCount > 0 { return .content }
        if !isConnected { return .offline }
        if !isSignedIn { return .signedOut }
        if isLoading { return .loading }
        if isSearching { return .noResults }
        if hasError { return .failed }
        return .empty
    }
}

// MARK: - Display-name prompt

/// The first-visit display-name prompt: shown once, prefilled from the profile name
/// unless that is still the anonymous default.
nonisolated public struct CommunityNameDraft: Equatable, Sendable {
    public static let maxLength = 40

    public var text: String

    public init(storedName: String) {
        let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed == Authorship.anonymous.displayName ? "" : trimmed
    }

    /// The name as it would be saved.
    public var trimmed: String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
    }

    public var canSave: Bool { !trimmed.isEmpty }

    /// Whether the prompt should appear on this visit.
    public static func shouldPrompt(hasPrompted: Bool) -> Bool { !hasPrompted }
}

// MARK: - Grid metrics

/// Column minimums for the adaptive feed grids. Compact widths get two color columns and
/// a single palette column; regular widths get wider cards and more of them.
nonisolated public enum CommunityGridMetrics {
    public static func columnMinimum(for segment: CommunitySegment, isRegularWidth: Bool) -> CGFloat {
        switch (segment, isRegularWidth) {
        case (.colors, false): 150
        case (.colors, true): 190
        case (.palettes, false): 300
        case (.palettes, true): 340
        }
    }

    /// How many skeleton cards to show while the first page loads.
    public static func placeholderCount(for segment: CommunitySegment) -> Int {
        switch segment {
        case .colors: 6
        case .palettes: 3
        }
    }
}

// MARK: - Device label

/// A short, tile-sized label for the device a color was created on.
nonisolated public enum CommunityDeviceLabel {
    public static func short(_ deviceName: String?) -> String {
        switch DeviceKind.from(deviceName) {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .iMac: "iMac"
        case .macStudio, .macMini, .macPro, .macBook: "Mac"
        case .visionPro: "Vision Pro"
        case .appleWatch: "Apple Watch"
        case .appleTV: "Apple TV"
        case .unknown:
            if let deviceName = deviceName?.trimmingCharacters(in: .whitespacesAndNewlines), !deviceName.isEmpty {
                deviceName
            } else {
                "—"
            }
        }
    }
}

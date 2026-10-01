//
//  PublishLogic.swift
//  OpaliteFeatureSharing
//
//  Pure state for the Community sheets: the notes/tags a publish sheet collects, why a
//  publish is currently blocked, and the report draft. Host-tested.
//

import Foundation
import OpaliteCore

// MARK: - Publish draft

/// What the publish sheets collect on top of the item itself. Notes and tags are
/// published as entered here; the Portfolio copy is left untouched.
nonisolated public struct PublishDraft: Equatable, Sendable {
    public static let maxNotesLength = 500
    public static let maxTags = 10
    public static let maxTagLength = 24

    public var notes: String
    /// Free text; tags are separated by commas or new lines.
    public var tagsText: String

    public init(notes: String? = nil, tags: [String] = []) {
        self.notes = notes ?? ""
        self.tagsText = tags.joined(separator: ", ")
    }

    /// The notes to publish, or nil when the field is blank.
    public var trimmedNotes: String? {
        let trimmed = String(notes.prefix(Self.maxNotesLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var notesRemaining: Int { max(0, Self.maxNotesLength - notes.count) }
    public var isNotesOverLimit: Bool { notes.count > Self.maxNotesLength }

    /// Cleaned tags: split on commas/new lines, trimmed, leading `#` dropped, each capped
    /// at `maxTagLength`, de-duplicated case-insensitively, at most `maxTags`.
    public var tags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tagsText.components(separatedBy: CharacterSet(charactersIn: ",\n")) {
            var tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            while tag.hasPrefix("#") { tag.removeFirst() }
            tag = String(tag.prefix(Self.maxTagLength)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { continue }
            result.append(tag)
            if result.count == Self.maxTags { break }
        }
        return result
    }

    /// Whether the user typed more tags than will be published.
    public var isTagsOverLimit: Bool {
        tagsText.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count > Self.maxTags
    }
}

// MARK: - Publish blockers

/// Why the publish button is disabled right now.
nonisolated public enum PublishBlocker: Equatable, Sendable {
    case offline
    case notSignedIn
    case rateLimited

    /// Derives the blocker from the Community model's state (`canPublish` already folds
    /// in the rate limiter, so it's only consulted once the other two pass).
    public static func evaluate(isConnected: Bool, isSignedIn: Bool, canPublish: Bool) -> PublishBlocker? {
        guard isConnected else { return .offline }
        guard isSignedIn else { return .notSignedIn }
        return canPublish ? nil : .rateLimited
    }

    public var title: String {
        switch self {
        case .offline: String(localized: "You're offline")
        case .notSignedIn: String(localized: "Sign in to iCloud")
        case .rateLimited: String(localized: "Publishing limit reached")
        }
    }

    public var message: String {
        switch self {
        case .offline: String(localized: "Connect to the internet to publish to the Community.")
        case .notSignedIn: String(localized: "Publishing uses your iCloud account. Sign in from the Settings app, then try again.")
        case .rateLimited: String(localized: "You can publish up to \(PublishRateLimiter.maxPublishesPerHour) items an hour. Try again a little later.")
        }
    }

    public var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .notSignedIn: "icloud.slash"
        case .rateLimited: "clock.badge.exclamationmark"
        }
    }
}

// MARK: - Report draft

/// The report sheet's state: a required reason and optional details.
nonisolated public struct ReportDraft: Equatable, Sendable {
    public static let maxDetailsLength = 500

    public var reason: ReportReason?
    public var details: String

    public init(reason: ReportReason? = nil, details: String = "") {
        self.reason = reason
        self.details = details
    }

    public var canSubmit: Bool { reason != nil && !isDetailsOverLimit }

    /// The details to send, or nil when blank.
    public var trimmedDetails: String? {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var detailsRemaining: Int { max(0, Self.maxDetailsLength - details.count) }
    public var isDetailsOverLimit: Bool { details.count > Self.maxDetailsLength }
}

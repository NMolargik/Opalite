//
//  AppRouter.swift
//  OpaliteCore
//
//  App-wide navigation state: the selected tab, the deep link waiting to be acted on, and
//  the modal the main UI should present next (paywall with context, color editor, photo
//  sampler). Widgets, quick actions, Siri, the menu bar, the watch, and `onOpenURL` all
//  funnel through `open(_:)`; `MainView` consumes. Pure Observation, host-tested.
//

import Foundation
import Observation

/// A modal the shell presents on behalf of some entry point.
nonisolated public enum PendingPresentation: Equatable, Sendable {
    case paywall(context: String)
    case colorEditor
    case photoSampler
    case sharedImage
    case swatchBarInfo
}

@MainActor
@Observable
public final class AppRouter {
    public var selectedTab: AppTab = .portfolio
    public var pendingDeepLink: DeepLink?
    public var pendingPresentation: PendingPresentation?

    /// Set by the Settings screen to pick a tab shown with a badge (unused by default).
    public var badgeCounts: [AppTab: Int] = [:]

    public init() {}

    public func select(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Routes a deep link: jumps to its destination tab and stages it for the screen.
    public func open(_ link: DeepLink) {
        if let tab = link.destinationTab, AppTab.available.contains(tab) {
            selectedTab = tab
        }
        pendingDeepLink = link
    }

    /// Parses and routes an external URL; unknown URLs are ignored.
    @discardableResult
    public func open(url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        open(link)
        return true
    }

    public func takePendingDeepLink() -> DeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    /// Asks the shell to present a modal (paywall, editor, sampler).
    public func present(_ presentation: PendingPresentation) {
        pendingPresentation = presentation
    }

    public func takePendingPresentation() -> PendingPresentation? {
        defer { pendingPresentation = nil }
        return pendingPresentation
    }

    /// Convenience: show the paywall with a reason the user can read.
    public func requestPaywall(context: String) {
        present(.paywall(context: context))
    }
}

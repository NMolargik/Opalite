//
//  AppTab.swift
//  OpaliteCore
//
//  The adaptive TabView's tabs. Titles are localized in the UI; icons/colors in the
//  design system.
//

import Foundation

nonisolated public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case portfolio
    case community
    case search
    case canvas
    case settings

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .portfolio: "paintpalette.fill"
        case .community: "person.2"
        case .search: "magnifyingglass"
        case .canvas: "pencil.and.scribble"
        case .settings: "gear"
        }
    }

    /// ⌘1…⌘5 in the menu bar.
    public var keyboardNumber: Int {
        switch self {
        case .portfolio: 1
        case .community: 2
        case .canvas: 3
        case .search: 4
        case .settings: 5
        }
    }

    /// The tabs available on a platform (tvOS has no canvas or community).
    public static var available: [AppTab] {
        #if os(tvOS)
        [.portfolio, .search, .settings]
        #else
        allCases
        #endif
    }
}

//
//  PersistenceError.swift
//  OpaliteCore
//
//  The typed failure of the persistence boundary. Repositories and use-cases declare
//  `throws(PersistenceError)`; the shared models turn these into toasts.
//

import Foundation

nonisolated public enum PersistenceError: LocalizedError, Equatable, Sendable {
    case fetchFailed(String)
    case saveFailed(String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .fetchFailed: String(localized: "Unable to load your portfolio.")
        case .saveFailed: String(localized: "Unable to save changes.")
        case .notFound: String(localized: "That item no longer exists.")
        }
    }
}

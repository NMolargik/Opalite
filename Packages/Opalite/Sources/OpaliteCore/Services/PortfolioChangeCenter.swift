//
//  PortfolioChangeCenter.swift
//  OpaliteCore
//
//  One multicast change stream for the portfolio store. Repositories notify after every
//  successful write and CloudSyncManager notifies on CloudKit imports, so the shared
//  models, the watch relay, widgets, Spotlight, and Siri vocabulary all observe a single
//  stream instead of per-screen refresh calls.
//

import Foundation

nonisolated public enum PortfolioChange: Equatable, Sendable {
    case colorCreated(UUID)
    case colorUpdated(UUID)
    case colorDeleted(UUID)
    case paletteCreated(UUID)
    case paletteUpdated(UUID)
    case paletteDeleted(UUID)
    case canvasCreated(UUID)
    case canvasUpdated(UUID)
    case canvasDeleted(UUID)
    /// Many records changed at once (import, sample data, CloudKit import).
    case bulk

    /// Whether colors or palettes (the things widgets, Siri, and the watch mirror) changed.
    public var affectsPortfolio: Bool {
        switch self {
        case .canvasCreated, .canvasUpdated, .canvasDeleted: false
        default: true
        }
    }

    public var affectsCanvases: Bool {
        switch self {
        case .canvasCreated, .canvasUpdated, .canvasDeleted, .bulk: true
        default: false
        }
    }
}

@MainActor
public final class PortfolioChangeCenter {
    private var continuations: [UUID: AsyncStream<PortfolioChange>.Continuation] = [:]

    public init() {}

    /// A stream that yields after every successful mutation of portfolio data.
    public func changes() -> AsyncStream<PortfolioChange> {
        let (stream, continuation) = AsyncStream<PortfolioChange>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    public func notify(_ change: PortfolioChange) {
        for continuation in continuations.values {
            continuation.yield(change)
        }
    }

    /// The number of live subscribers (tests).
    public var subscriberCount: Int { continuations.count }
}

// MARK: - Use case

@MainActor
public protocol ObservePortfolioChanges {
    func callAsFunction() -> AsyncStream<PortfolioChange>
}

public struct ObservePortfolioChangesUseCase: ObservePortfolioChanges {
    private let center: PortfolioChangeCenter
    public init(center: PortfolioChangeCenter) { self.center = center }
    public func callAsFunction() -> AsyncStream<PortfolioChange> { center.changes() }
}

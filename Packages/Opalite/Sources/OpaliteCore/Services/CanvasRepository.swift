//
//  CanvasRepository.swift
//  OpaliteCore
//
//  The canvas data boundary and its use-cases. Creating a canvas is gated by the free tier.
//

import Foundation

@MainActor
public protocol CanvasRepository: AnyObject {
    /// Every canvas, alphabetical by title (duplicates from sync races folded).
    func canvases() throws(PersistenceError) -> [CanvasFile]
    func canvas(withID id: UUID) throws(PersistenceError) -> CanvasFile?
    func count() throws(PersistenceError) -> Int

    func insert(_ canvas: CanvasFile, deviceName: String?) throws(PersistenceError)
    func update(_ canvas: CanvasFile, deviceName: String?, configure: (CanvasFile) -> Void) throws(PersistenceError)
    func delete(_ canvas: CanvasFile) throws(PersistenceError)
}

nonisolated public enum CanvasCreationError: Error, Equatable, Sendable {
    case limitReached
    case persistence(PersistenceError)
}

@MainActor
public protocol LoadCanvases {
    func callAsFunction() throws(PersistenceError) -> [CanvasFile]
}

public struct LoadCanvasesUseCase: LoadCanvases {
    private let repository: any CanvasRepository
    public init(repository: any CanvasRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [CanvasFile] { try repository.canvases() }
}

@MainActor
public protocol FindCanvas {
    func callAsFunction(withID id: UUID) throws(PersistenceError) -> CanvasFile?
}

public struct FindCanvasUseCase: FindCanvas {
    private let repository: any CanvasRepository
    public init(repository: any CanvasRepository) { self.repository = repository }
    public func callAsFunction(withID id: UUID) throws(PersistenceError) -> CanvasFile? { try repository.canvas(withID: id) }
}

@MainActor
public protocol CreateCanvas {
    @discardableResult
    func callAsFunction(title: String, deviceName: String?) throws(CanvasCreationError) -> CanvasFile
}

public struct CreateCanvasUseCase: CreateCanvas {
    private let repository: any CanvasRepository
    private let entitlements: any EntitlementProviding

    public init(repository: any CanvasRepository, entitlements: any EntitlementProviding) {
        self.repository = repository
        self.entitlements = entitlements
    }

    @discardableResult
    public func callAsFunction(title: String, deviceName: String?) throws(CanvasCreationError) -> CanvasFile {
        let count: Int
        do { count = try repository.count() } catch { throw .persistence(error) }
        guard OnyxGate(hasOnyx: entitlements.hasOnyx).canCreateCanvas(currentCount: count) else { throw .limitReached }
        let canvas = CanvasFile(title: title)
        do { try repository.insert(canvas, deviceName: deviceName) } catch { throw .persistence(error) }
        return canvas
    }
}

@MainActor
public protocol UpdateCanvas {
    func callAsFunction(_ canvas: CanvasFile, deviceName: String?, configure: (CanvasFile) -> Void) throws(PersistenceError)
}

public struct UpdateCanvasUseCase: UpdateCanvas {
    private let repository: any CanvasRepository
    public init(repository: any CanvasRepository) { self.repository = repository }
    public func callAsFunction(_ canvas: CanvasFile, deviceName: String?, configure: (CanvasFile) -> Void) throws(PersistenceError) {
        try repository.update(canvas, deviceName: deviceName, configure: configure)
    }
}

@MainActor
public protocol DeleteCanvas {
    func callAsFunction(_ canvas: CanvasFile) throws(PersistenceError)
}

public struct DeleteCanvasUseCase: DeleteCanvas {
    private let repository: any CanvasRepository
    public init(repository: any CanvasRepository) { self.repository = repository }
    public func callAsFunction(_ canvas: CanvasFile) throws(PersistenceError) { try repository.delete(canvas) }
}

// MARK: - Sample data (DEBUG)

/// Seeds demo colors, palettes, and canvases (Settings' developer menu). The protocol is
/// always available so the shared models keep one init signature; the concrete generator in
/// OpaliteData is DEBUG-only and the composition root passes nil in release.
@MainActor
public protocol GenerateSampleData {
    func callAsFunction() throws(PersistenceError)
}

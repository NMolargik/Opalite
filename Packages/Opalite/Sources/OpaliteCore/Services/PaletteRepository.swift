//
//  PaletteRepository.swift
//  OpaliteCore
//
//  The palette data boundary and its use-cases. Creating a palette is gated by the free
//  tier; the gate is checked in the use-case so every entry point (toolbar, menu bar,
//  Siri, Community save, import) enforces it identically.
//

import Foundation

@MainActor
public protocol PaletteRepository: AnyObject {
    /// Every palette, newest first.
    func palettes() throws(PersistenceError) -> [OpalitePalette]
    func palette(withID id: UUID) throws(PersistenceError) -> OpalitePalette?
    func count() throws(PersistenceError) -> Int

    /// Persists a new palette (and any colors it carries), keeping back-references consistent.
    func insert(_ palette: OpalitePalette, authorship: Authorship) throws(PersistenceError)
    func update(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) throws(PersistenceError)
    /// Deletes a palette; `deleteColors` also removes its colors, otherwise they become loose.
    func delete(_ palette: OpalitePalette, deleteColors: Bool) throws(PersistenceError)

    /// Links a canvas one-to-one with a palette (clearing prior links on both sides).
    func attach(_ canvas: CanvasFile, to palette: OpalitePalette) throws(PersistenceError)
    func detachCanvas(from palette: OpalitePalette) throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadPalettes {
    func callAsFunction() throws(PersistenceError) -> [OpalitePalette]
}

public struct LoadPalettesUseCase: LoadPalettes {
    private let repository: any PaletteRepository
    public init(repository: any PaletteRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [OpalitePalette] { try repository.palettes() }
}

@MainActor
public protocol FindPalette {
    func callAsFunction(withID id: UUID) throws(PersistenceError) -> OpalitePalette?
}

public struct FindPaletteUseCase: FindPalette {
    private let repository: any PaletteRepository
    public init(repository: any PaletteRepository) { self.repository = repository }
    public func callAsFunction(withID id: UUID) throws(PersistenceError) -> OpalitePalette? { try repository.palette(withID: id) }
}

/// The failure of a gated create.
nonisolated public enum PaletteCreationError: Error, Equatable, Sendable {
    case limitReached
    case persistence(PersistenceError)
}

@MainActor
public protocol CreatePalette {
    /// Creates a palette unless the free tier's limit is hit.
    @discardableResult
    func callAsFunction(name: String, notes: String?, tags: [String], colors: [OpaliteColor], authorship: Authorship) throws(PaletteCreationError) -> OpalitePalette
}

public struct CreatePaletteUseCase: CreatePalette {
    private let repository: any PaletteRepository
    private let entitlements: any EntitlementProviding
    private let donor: (any IntentDonating)?

    public init(repository: any PaletteRepository, entitlements: any EntitlementProviding, donor: (any IntentDonating)? = nil) {
        self.repository = repository
        self.entitlements = entitlements
        self.donor = donor
    }

    @discardableResult
    public func callAsFunction(name: String, notes: String?, tags: [String], colors: [OpaliteColor], authorship: Authorship) throws(PaletteCreationError) -> OpalitePalette {
        let count: Int
        do { count = try repository.count() } catch { throw .persistence(error) }
        guard OnyxGate(hasOnyx: entitlements.hasOnyx).canCreatePalette(currentCount: count) else { throw .limitReached }

        let palette = OpalitePalette(name: name, createdByDisplayName: authorship.displayName, notes: notes, tags: tags, colors: colors)
        do { try repository.insert(palette, authorship: authorship) } catch { throw .persistence(error) }
        donor?.donate(.createPalette)
        return palette
    }
}

/// Inserts an already-built palette (imports, Community saves); gated like `CreatePalette`.
@MainActor
public protocol InsertPalette {
    @discardableResult
    func callAsFunction(_ palette: OpalitePalette, authorship: Authorship) throws(PaletteCreationError) -> OpalitePalette
}

public struct InsertPaletteUseCase: InsertPalette {
    private let repository: any PaletteRepository
    private let entitlements: any EntitlementProviding

    public init(repository: any PaletteRepository, entitlements: any EntitlementProviding) {
        self.repository = repository
        self.entitlements = entitlements
    }

    @discardableResult
    public func callAsFunction(_ palette: OpalitePalette, authorship: Authorship) throws(PaletteCreationError) -> OpalitePalette {
        let count: Int
        do { count = try repository.count() } catch { throw .persistence(error) }
        guard OnyxGate(hasOnyx: entitlements.hasOnyx).canCreatePalette(currentCount: count) else { throw .limitReached }
        do { try repository.insert(palette, authorship: authorship) } catch { throw .persistence(error) }
        return palette
    }
}

@MainActor
public protocol UpdatePalette {
    func callAsFunction(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) throws(PersistenceError)
}

public struct UpdatePaletteUseCase: UpdatePalette {
    private let repository: any PaletteRepository
    public init(repository: any PaletteRepository) { self.repository = repository }
    public func callAsFunction(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) throws(PersistenceError) {
        try repository.update(palette, configure: configure)
    }
}

@MainActor
public protocol DeletePalette {
    func callAsFunction(_ palette: OpalitePalette, deleteColors: Bool) throws(PersistenceError)
}

public struct DeletePaletteUseCase: DeletePalette {
    private let repository: any PaletteRepository
    public init(repository: any PaletteRepository) { self.repository = repository }
    public func callAsFunction(_ palette: OpalitePalette, deleteColors: Bool) throws(PersistenceError) {
        try repository.delete(palette, deleteColors: deleteColors)
    }
}

@MainActor
public protocol LinkCanvasToPalette {
    /// Links `canvas` to `palette`, or unlinks the palette's canvas when `canvas` is nil.
    func callAsFunction(_ canvas: CanvasFile?, to palette: OpalitePalette) throws(PersistenceError)
}

public struct LinkCanvasToPaletteUseCase: LinkCanvasToPalette {
    private let repository: any PaletteRepository
    public init(repository: any PaletteRepository) { self.repository = repository }
    public func callAsFunction(_ canvas: CanvasFile?, to palette: OpalitePalette) throws(PersistenceError) {
        if let canvas {
            try repository.attach(canvas, to: palette)
        } else {
            try repository.detachCanvas(from: palette)
        }
    }
}

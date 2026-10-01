//
//  ColorRepository.swift
//  OpaliteCore
//
//  The color data boundary and its single-verb use-cases. `DefaultColorRepository` in
//  OpaliteData owns the ModelContext, stamps authorship/device metadata, keeps both
//  sides of the palette relationship in sync, throws typed failures, and notifies the
//  change stream after every successful write.
//

import Foundation

/// Authorship stamped onto new/updated records.
nonisolated public struct Authorship: Sendable, Equatable {
    public var displayName: String
    public var deviceName: String?

    public init(displayName: String, deviceName: String? = nil) {
        self.displayName = displayName
        self.deviceName = deviceName
    }

    public static let anonymous = Authorship(displayName: "User")
}

@MainActor
public protocol ColorRepository: AnyObject {
    /// Every color, most recently updated first.
    func colors() throws(PersistenceError) -> [OpaliteColor]
    func color(withID id: UUID) throws(PersistenceError) -> OpaliteColor?
    func count() throws(PersistenceError) -> Int

    /// Persists a new color, stamping authorship when the record has none.
    func insert(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError)
    /// Applies edits, stamps the updating device, and persists.
    func update(_ color: OpaliteColor, authorship: Authorship, configure: (OpaliteColor) -> Void) throws(PersistenceError)
    func delete(_ color: OpaliteColor) throws(PersistenceError)

    /// Attaches a color to a palette (moving it from any previous palette).
    func attach(_ color: OpaliteColor, to palette: OpalitePalette, authorship: Authorship) throws(PersistenceError)
    /// Detaches a color from its palette, leaving it loose.
    func detach(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadColors {
    func callAsFunction() throws(PersistenceError) -> [OpaliteColor]
}

public struct LoadColorsUseCase: LoadColors {
    private let repository: any ColorRepository
    public init(repository: any ColorRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [OpaliteColor] { try repository.colors() }
}

@MainActor
public protocol FindColor {
    func callAsFunction(withID id: UUID) throws(PersistenceError) -> OpaliteColor?
}

public struct FindColorUseCase: FindColor {
    private let repository: any ColorRepository
    public init(repository: any ColorRepository) { self.repository = repository }
    public func callAsFunction(withID id: UUID) throws(PersistenceError) -> OpaliteColor? { try repository.color(withID: id) }
}

/// Creates a color from components (editor, quick-add, Siri, watch, Community save).
@MainActor
public protocol CreateColor {
    @discardableResult
    func callAsFunction(_ rgba: RGBA, name: String?, notes: String?, palette: OpalitePalette?, authorship: Authorship) throws(PersistenceError) -> OpaliteColor
}

public struct CreateColorUseCase: CreateColor {
    private let repository: any ColorRepository
    private let donor: (any IntentDonating)?

    public init(repository: any ColorRepository, donor: (any IntentDonating)? = nil) {
        self.repository = repository
        self.donor = donor
    }

    @discardableResult
    public func callAsFunction(_ rgba: RGBA, name: String?, notes: String?, palette: OpalitePalette?, authorship: Authorship) throws(PersistenceError) -> OpaliteColor {
        let color = OpaliteColor(name: name, notes: notes, red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha, palette: palette)
        try repository.insert(color, authorship: authorship)
        donor?.donate(.createColor)
        return color
    }
}

/// Inserts an already-built model (imports, Community saves) — authorship fills gaps only.
@MainActor
public protocol InsertColor {
    @discardableResult
    func callAsFunction(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) -> OpaliteColor
}

public struct InsertColorUseCase: InsertColor {
    private let repository: any ColorRepository
    public init(repository: any ColorRepository) { self.repository = repository }
    @discardableResult
    public func callAsFunction(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) -> OpaliteColor {
        try repository.insert(color, authorship: authorship)
        return color
    }
}

@MainActor
public protocol UpdateColor {
    func callAsFunction(_ color: OpaliteColor, authorship: Authorship, configure: (OpaliteColor) -> Void) throws(PersistenceError)
}

public struct UpdateColorUseCase: UpdateColor {
    private let repository: any ColorRepository
    public init(repository: any ColorRepository) { self.repository = repository }
    public func callAsFunction(_ color: OpaliteColor, authorship: Authorship, configure: (OpaliteColor) -> Void) throws(PersistenceError) {
        try repository.update(color, authorship: authorship, configure: configure)
    }
}

@MainActor
public protocol DeleteColor {
    func callAsFunction(_ color: OpaliteColor) throws(PersistenceError)
}

public struct DeleteColorUseCase: DeleteColor {
    private let repository: any ColorRepository
    public init(repository: any ColorRepository) { self.repository = repository }
    public func callAsFunction(_ color: OpaliteColor) throws(PersistenceError) { try repository.delete(color) }
}

@MainActor
public protocol MoveColorToPalette {
    /// Moves `color` into `palette`, or makes it loose when `palette` is nil.
    func callAsFunction(_ color: OpaliteColor, to palette: OpalitePalette?, authorship: Authorship) throws(PersistenceError)
}

public struct MoveColorToPaletteUseCase: MoveColorToPalette {
    private let repository: any ColorRepository
    public init(repository: any ColorRepository) { self.repository = repository }
    public func callAsFunction(_ color: OpaliteColor, to palette: OpalitePalette?, authorship: Authorship) throws(PersistenceError) {
        if let palette {
            try repository.attach(color, to: palette, authorship: authorship)
        } else {
            try repository.detach(color, authorship: authorship)
        }
    }
}

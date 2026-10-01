//
//  DefaultPaletteRepository.swift
//  OpaliteData
//

import Foundation
import SwiftData
import OpaliteCore

public final class DefaultPaletteRepository: PaletteRepository {
    private let context: ModelContext
    private let changeCenter: PortfolioChangeCenter

    public init(container: ModelContainer, changeCenter: PortfolioChangeCenter) {
        self.context = container.mainContext
        self.changeCenter = changeCenter
    }

    private var sort: [SortDescriptor<OpalitePalette>] {
        [SortDescriptor(\OpalitePalette.createdAt, order: .reverse)]
    }

    public func palettes() throws(PersistenceError) -> [OpalitePalette] {
        try context.fetchTyped(FetchDescriptor<OpalitePalette>(sortBy: sort))
    }

    public func palette(withID id: UUID) throws(PersistenceError) -> OpalitePalette? {
        var descriptor = FetchDescriptor<OpalitePalette>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetchTyped(descriptor).first
    }

    public func count() throws(PersistenceError) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<OpalitePalette>())
        } catch {
            throw .fetchFailed(error.localizedDescription)
        }
    }

    public func insert(_ palette: OpalitePalette, authorship: Authorship) throws(PersistenceError) {
        if palette.createdByDisplayName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            palette.createdByDisplayName = authorship.displayName
        }
        let colors = palette.colors ?? []
        context.insert(palette)
        for color in colors {
            color.palette = palette
            if color.createdByDisplayName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                color.createdByDisplayName = authorship.displayName
            }
            if color.createdOnDeviceName == nil { color.createdOnDeviceName = authorship.deviceName }
            if color.updatedOnDeviceName == nil { color.updatedOnDeviceName = authorship.deviceName }
            context.insert(color)
        }
        try context.saveTyped()
        changeCenter.notify(.paletteCreated(palette.id))
        if !colors.isEmpty { changeCenter.notify(.bulk) }
    }

    public func update(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) throws(PersistenceError) {
        configure(palette)
        palette.updatedAt = .now
        try context.saveTyped()
        changeCenter.notify(.paletteUpdated(palette.id))
    }

    public func delete(_ palette: OpalitePalette, deleteColors: Bool) throws(PersistenceError) {
        let id = palette.id
        let colors = palette.colors ?? []
        if deleteColors {
            for color in colors { context.delete(color) }
        } else {
            for color in colors {
                color.palette = nil
                color.updatedAt = .now
            }
        }
        if let canvas = palette.canvasFile {
            canvas.palette = nil
        }
        context.delete(palette)
        try context.saveTyped()
        changeCenter.notify(.paletteDeleted(id))
        if !colors.isEmpty { changeCenter.notify(.bulk) }
    }

    public func attach(_ canvas: CanvasFile, to palette: OpalitePalette) throws(PersistenceError) {
        if canvas.palette?.id != palette.id {
            if let oldPalette = canvas.palette {
                oldPalette.canvasFile = nil
                oldPalette.updatedAt = .now
            }
            if let oldCanvas = palette.canvasFile, oldCanvas.id != canvas.id {
                oldCanvas.palette = nil
                oldCanvas.updatedAt = .now
            }
            palette.canvasFile = canvas
            canvas.palette = palette
        }
        palette.updatedAt = .now
        canvas.updatedAt = .now
        try context.saveTyped()
        changeCenter.notify(.paletteUpdated(palette.id))
        changeCenter.notify(.canvasUpdated(canvas.id))
    }

    public func detachCanvas(from palette: OpalitePalette) throws(PersistenceError) {
        guard let canvas = palette.canvasFile else { return }
        canvas.palette = nil
        canvas.updatedAt = .now
        palette.canvasFile = nil
        palette.updatedAt = .now
        try context.saveTyped()
        changeCenter.notify(.paletteUpdated(palette.id))
        changeCenter.notify(.canvasUpdated(canvas.id))
    }
}

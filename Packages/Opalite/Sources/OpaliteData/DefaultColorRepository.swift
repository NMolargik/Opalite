//
//  DefaultColorRepository.swift
//  OpaliteData
//
//  SwiftData-backed color persistence. Stamps authorship/device metadata, keeps both
//  sides of the palette relationship consistent, and notifies the change stream after
//  every successful write.
//

import Foundation
import SwiftData
import OpaliteCore

public final class DefaultColorRepository: ColorRepository {
    private let context: ModelContext
    private let changeCenter: PortfolioChangeCenter

    public init(container: ModelContainer, changeCenter: PortfolioChangeCenter) {
        self.context = container.mainContext
        self.changeCenter = changeCenter
    }

    private var sort: [SortDescriptor<OpaliteColor>] {
        [SortDescriptor(\OpaliteColor.updatedAt, order: .reverse), SortDescriptor(\OpaliteColor.createdAt, order: .reverse)]
    }

    public func colors() throws(PersistenceError) -> [OpaliteColor] {
        try context.fetchTyped(FetchDescriptor<OpaliteColor>(sortBy: sort))
    }

    public func color(withID id: UUID) throws(PersistenceError) -> OpaliteColor? {
        var descriptor = FetchDescriptor<OpaliteColor>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetchTyped(descriptor).first
    }

    public func count() throws(PersistenceError) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<OpaliteColor>())
        } catch {
            throw .fetchFailed(error.localizedDescription)
        }
    }

    public func insert(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) {
        if color.createdByDisplayName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            color.createdByDisplayName = authorship.displayName
        }
        if color.createdOnDeviceName == nil { color.createdOnDeviceName = authorship.deviceName }
        if color.updatedOnDeviceName == nil { color.updatedOnDeviceName = authorship.deviceName }
        if let palette = color.palette {
            if palette.colors == nil { palette.colors = [] }
            if palette.colors?.contains(where: { $0.id == color.id }) == false { palette.colors?.append(color) }
            palette.updatedAt = .now
        }
        context.insert(color)
        try context.saveTyped()
        changeCenter.notify(.colorCreated(color.id))
    }

    public func update(_ color: OpaliteColor, authorship: Authorship, configure: (OpaliteColor) -> Void) throws(PersistenceError) {
        configure(color)
        color.updatedOnDeviceName = authorship.deviceName ?? color.updatedOnDeviceName
        color.updatedAt = .now
        try context.saveTyped()
        changeCenter.notify(.colorUpdated(color.id))
    }

    public func delete(_ color: OpaliteColor) throws(PersistenceError) {
        let id = color.id
        if let palette = color.palette {
            palette.colors?.removeAll { $0.id == id }
            palette.updatedAt = .now
        }
        context.delete(color)
        try context.saveTyped()
        changeCenter.notify(.colorDeleted(id))
    }

    public func attach(_ color: OpaliteColor, to palette: OpalitePalette, authorship: Authorship) throws(PersistenceError) {
        if color.palette?.id == palette.id {
            if palette.colors == nil { palette.colors = [] }
            guard palette.colors?.contains(where: { $0.id == color.id }) == false else { return }
            palette.colors?.append(color)
        } else {
            if let old = color.palette, old.id != palette.id {
                old.colors?.removeAll { $0.id == color.id }
                old.updatedAt = .now
            }
            color.palette = palette
            if palette.colors == nil { palette.colors = [] }
            palette.colors?.removeAll { $0.id == color.id }
            palette.colors?.append(color)
        }
        palette.updatedAt = .now
        color.updatedAt = .now
        color.updatedOnDeviceName = authorship.deviceName ?? color.updatedOnDeviceName
        try context.saveTyped()
        changeCenter.notify(.colorUpdated(color.id))
        changeCenter.notify(.paletteUpdated(palette.id))
    }

    public func detach(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) {
        guard let palette = color.palette else { return }
        palette.colors?.removeAll { $0.id == color.id }
        palette.updatedAt = .now
        color.palette = nil
        color.updatedAt = .now
        color.updatedOnDeviceName = authorship.deviceName ?? color.updatedOnDeviceName
        try context.saveTyped()
        changeCenter.notify(.colorUpdated(color.id))
        changeCenter.notify(.paletteUpdated(palette.id))
    }
}

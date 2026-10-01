//
//  ImportModel.swift
//  OpaliteFeatureShared
//
//  Opens `.opalitecolor` / `.opalitepalette` files: builds an import preview against the
//  portfolio, and applies it on confirmation (skipping duplicates by id).
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import os

@MainActor
@Observable
public final class ImportModel {
    @ObservationIgnored private let toastManager: ToastManager

    public var pendingColorImport: ColorImportPreview?
    public var pendingPaletteImport: PaletteImportPreview?
    public var importError: OpaliteFileError?

    public init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    public var isShowingColorImport: Bool {
        get { pendingColorImport != nil }
        set { if !newValue { pendingColorImport = nil } }
    }

    public var isShowingPaletteImport: Bool {
        get { pendingPaletteImport != nil }
        set { if !newValue { pendingPaletteImport = nil } }
    }

    public var isShowingError: Bool {
        get { importError != nil }
        set { if !newValue { importError = nil } }
    }

    /// Reads an incoming file and stages a preview. Returns false when the URL isn't an
    /// Opalite file (so the caller can try other handlers).
    @discardableResult
    public func handleIncomingURL(_ url: URL, portfolio: PortfolioModel) -> Bool {
        guard let kind = OpaliteFileCodec.kind(of: url) else { return false }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let colorIDs = Set(portfolio.colors.map(\.id))
            switch kind {
            case .color:
                pendingColorImport = try OpaliteFileCodec.previewColorImport(data: data, existingColorIDs: colorIDs)
            case .palette:
                pendingPaletteImport = try OpaliteFileCodec.previewPaletteImport(data: data, existingPaletteIDs: Set(portfolio.palettes.map(\.id)), existingColorIDs: colorIDs)
            }
        } catch let error as OpaliteFileError {
            importError = error
        } catch {
            Log.sharing.error("Import read failed: \(error.localizedDescription)")
            importError = .fileAccessDenied
        }
        return true
    }

    /// Applies the staged color import.
    public func confirmColorImport(into portfolio: PortfolioModel) {
        guard let preview = pendingColorImport else { return }
        pendingColorImport = nil
        guard !preview.willSkip else {
            toastManager.show(message: String(localized: "That color is already in your Portfolio"), style: .info)
            return
        }
        if portfolio.insert(preview.color.makeModel()) != nil {
            toastManager.showSuccess(String(localized: "Imported \(preview.color.name ?? preview.color.rgba.hexString)"))
        }
    }

    /// Applies the staged palette import: updates an existing palette's metadata, adds new
    /// colors, and attaches any already-present colors.
    public func confirmPaletteImport(into portfolio: PortfolioModel) {
        guard let preview = pendingPaletteImport else { return }
        pendingPaletteImport = nil
        let decoded = preview.palette

        if let existingID = preview.existingPaletteID, let existing = portfolio.palette(withID: existingID) {
            portfolio.update(existing) { palette in
                palette.name = decoded.name
                palette.notes = decoded.notes
                palette.tags = decoded.tags
                palette.previewBackgroundRaw = decoded.previewBackgroundRaw
            }
            for color in preview.newColors {
                _ = portfolio.createColor(color.rgba, name: color.name, notes: color.notes, in: existing)
            }
            for id in preview.existingColorIDs {
                if let color = portfolio.color(withID: id), color.palette?.id != existing.id {
                    portfolio.move(color, to: existing)
                }
            }
            toastManager.showSuccess(String(localized: "Updated \(decoded.name)"))
        } else {
            let newColors = preview.newColors.map { $0.makeModel() }
            let palette = OpalitePalette(id: decoded.id, name: decoded.name, createdAt: decoded.createdAt, updatedAt: decoded.updatedAt, createdByDisplayName: decoded.createdByDisplayName, notes: decoded.notes, tags: decoded.tags, colors: newColors)
            palette.previewBackgroundRaw = decoded.previewBackgroundRaw
            guard let inserted = portfolio.insert(palette) else { return }
            for id in preview.existingColorIDs {
                if let color = portfolio.color(withID: id) { portfolio.move(color, to: inserted) }
            }
            toastManager.showSuccess(String(localized: "Imported \(decoded.name)"))
        }
    }
}

//
//  ImportCoordinator.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

/// Coordinates import state across the app when opening .opalitecolor or .opalitepalette files
@MainActor
@Observable
class ImportCoordinator {
    var pendingColorImport: ColorImportPreview?
    var pendingPaletteImport: PaletteImportPreview?
    var importError: SharingError?
    var showingImportError: Bool = false

    var isShowingColorImport: Bool {
        get { pendingColorImport != nil }
        set { if !newValue { pendingColorImport = nil } }
    }

    var isShowingPaletteImport: Bool {
        get { pendingPaletteImport != nil }
        set { if !newValue { pendingPaletteImport = nil } }
    }

    /// Handles an incoming file URL and prepares the appropriate import preview
    func handleIncomingURL(_ url: URL, colorManager: ColorManager) {
        // Attempt to access security-scoped resource for files from outside the sandbox
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let pathExtension = url.pathExtension.lowercased()

        do {
            switch pathExtension {
            case "opalitecolor":
                let preview = try SharingService.previewColorImport(
                    from: url,
                    existingColors: colorManager.colors
                )
                pendingColorImport = preview

            case "opalitepalette":
                let preview = try SharingService.previewPaletteImport(
                    from: url,
                    existingPalettes: colorManager.palettes,
                    existingColors: colorManager.colors
                )
                pendingPaletteImport = preview

            default:
                importError = .invalidFormat
                showingImportError = true
            }
        } catch let error as SharingError {
            importError = error
            showingImportError = true
        } catch {
            importError = .invalidFormat
            showingImportError = true
        }
    }
}

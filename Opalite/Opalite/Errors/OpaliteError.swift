//
//  OpaliteError.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import Foundation

/// Unified error type for all Opalite operations
enum OpaliteError: LocalizedError, Equatable {
    // MARK: - Color Operations
    case colorCreationFailed
    case colorUpdateFailed
    case colorDeletionFailed
    case colorFetchFailed

    // MARK: - Palette Operations
    case paletteCreationFailed
    case paletteUpdateFailed
    case paletteDeletionFailed
    case paletteFetchFailed

    // MARK: - Canvas Operations
    case canvasCreationFailed
    case canvasUpdateFailed
    case canvasDeletionFailed
    case canvasFetchFailed
    case canvasSaveFailed

    // MARK: - Relationship Operations
    case colorAttachFailed
    case colorDetachFailed

    // MARK: - Import/Export Operations
    case importFailed(reason: String)
    case exportFailed(reason: String)
    case pdfExportFailed

    // MARK: - Data Operations
    case saveFailed
    case loadFailed
    case sampleDataFailed

    // MARK: - Generic
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        // Color
        case .colorCreationFailed:
            return "Unable to create color"
        case .colorUpdateFailed:
            return "Unable to update color"
        case .colorDeletionFailed:
            return "Unable to delete color"
        case .colorFetchFailed:
            return "Unable to load colors"

        // Palette
        case .paletteCreationFailed:
            return "Unable to create palette"
        case .paletteUpdateFailed:
            return "Unable to update palette"
        case .paletteDeletionFailed:
            return "Unable to delete palette"
        case .paletteFetchFailed:
            return "Unable to load palettes"

        // Canvas
        case .canvasCreationFailed:
            return "Unable to create canvas"
        case .canvasUpdateFailed:
            return "Unable to update canvas"
        case .canvasDeletionFailed:
            return "Unable to delete canvas"
        case .canvasFetchFailed:
            return "Unable to load canvases"
        case .canvasSaveFailed:
            return "Unable to save canvas"

        // Relationships
        case .colorAttachFailed:
            return "Unable to add color to palette"
        case .colorDetachFailed:
            return "Unable to remove color from palette"

        // Import/Export
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .pdfExportFailed:
            return "Unable to export PDF"

        // Data
        case .saveFailed:
            return "Unable to save changes"
        case .loadFailed:
            return "Unable to load data"
        case .sampleDataFailed:
            return "Unable to load sample data"

        // Generic
        case .unknownError(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .colorCreationFailed, .paletteCreationFailed, .canvasCreationFailed:
            return "plus.circle.fill"
        case .colorUpdateFailed, .paletteUpdateFailed, .canvasUpdateFailed:
            return "pencil.circle.fill"
        case .colorDeletionFailed, .paletteDeletionFailed, .canvasDeletionFailed:
            return "trash.circle.fill"
        case .colorFetchFailed, .paletteFetchFailed, .canvasFetchFailed, .loadFailed:
            return "arrow.down.circle.fill"
        case .canvasSaveFailed, .saveFailed:
            return "externaldrive.fill.badge.xmark"
        case .colorAttachFailed, .colorDetachFailed:
            return "link.circle.fill"
        case .importFailed:
            return "square.and.arrow.down.fill"
        case .exportFailed, .pdfExportFailed:
            return "square.and.arrow.up.fill"
        case .sampleDataFailed:
            return "doc.fill.badge.plus"
        case .unknownError:
            return "exclamationmark.triangle.fill"
        }
    }

    static func == (lhs: OpaliteError, rhs: OpaliteError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

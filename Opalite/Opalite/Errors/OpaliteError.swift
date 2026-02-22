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
    case canvasAttachFailed
    case canvasDetachFailed

    // MARK: - Import/Export Operations
    case importFailed(reason: String)
    case exportFailed(reason: String)
    case pdfExportFailed

    // MARK: - Data Operations
    case saveFailed
    case loadFailed
    case sampleDataFailed

    // MARK: - Subscription Operations
    case subscriptionLoadFailed
    case subscriptionPurchaseFailed
    case subscriptionRestoreFailed
    case subscriptionVerificationFailed

    // MARK: - Community Operations
    case communityFetchFailed(reason: String)
    case communityPublishFailed(reason: String)
    case communityDeleteFailed(reason: String)
    case communityReportFailed(reason: String)
    case communityRateLimited
    case communityRequiresOnyx
    case communityColorAlreadyExists
    case communityPaletteAlreadyExists
    case communityNotSignedIn
    case communityAdminRequired

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
        case .canvasAttachFailed:
            return "Unable to link canvas to palette"
        case .canvasDetachFailed:
            return "Unable to unlink canvas from palette"

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

        // Subscription
        case .subscriptionLoadFailed:
            return "Unable to load subscription options"
        case .subscriptionPurchaseFailed:
            return "Purchase could not be completed"
        case .subscriptionRestoreFailed:
            return "Unable to restore purchases"
        case .subscriptionVerificationFailed:
            return "Purchase verification failed"

        // Community
        case .communityFetchFailed(let reason):
            return "Couldn't load content: \(reason)"
        case .communityPublishFailed(let reason):
            return "Publish failed: \(reason)"
        case .communityDeleteFailed(let reason):
            return "Delete failed: \(reason)"
        case .communityReportFailed(let reason):
            return "Report failed: \(reason)"
        case .communityRateLimited:
            return "Slow down, try again soon"
        case .communityRequiresOnyx:
            return "Onyx required"
        case .communityColorAlreadyExists:
            return "Color already saved"
        case .communityPaletteAlreadyExists:
            return "Palette already saved"
        case .communityNotSignedIn:
            return "Sign in to iCloud"
        case .communityAdminRequired:
            return "Admin required"

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
        case .colorAttachFailed, .colorDetachFailed,
             .canvasAttachFailed, .canvasDetachFailed:
            return "link.circle.fill"
        case .importFailed:
            return "square.and.arrow.down.fill"
        case .exportFailed, .pdfExportFailed:
            return "square.and.arrow.up.fill"
        case .sampleDataFailed:
            return "doc.fill.badge.plus"
        case .subscriptionLoadFailed, .subscriptionPurchaseFailed,
             .subscriptionRestoreFailed, .subscriptionVerificationFailed:
            return "creditcard.fill"
        case .communityFetchFailed, .communityPublishFailed, .communityDeleteFailed,
             .communityReportFailed:
            return "person.2"
        case .communityRateLimited:
            return "clock.fill"
        case .communityRequiresOnyx:
            return "lock.fill"
        case .communityColorAlreadyExists, .communityPaletteAlreadyExists:
            return "doc.on.doc.fill"
        case .communityNotSignedIn:
            return "icloud.slash.fill"
        case .communityAdminRequired:
            return "lock.shield.fill"
        case .unknownError:
            return "exclamationmark.triangle.fill"
        }
    }

}

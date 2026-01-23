//
//  PortfolioView-ViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 1/19/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

// MARK: - ViewModel

extension PortfolioView {
    @MainActor
    @Observable
    final class ViewModel {
        // MARK: - Sheet/Cover State
        var paletteSelectionColor: OpaliteColor?
        var isShowingPaywall: Bool = false
        var isShowingColorEditor: Bool = false
        var pendingPaletteToAddTo: OpalitePalette?
        var isShowingFileImporter: Bool = false
        var colorToExport: OpaliteColor?
        var isShowingSwatchBarInfo: Bool = false
        var isShowingQuickAddHex: Bool = false
        var isShowingPaletteOrder: Bool = false
        var isShowingBatchPaletteSelection: Bool = false
        var isShowingPhotoColorPicker: Bool = false

        // MARK: - Alert State
        var colorToDelete: OpaliteColor?
        var colorsToDelete: [OpaliteColor] = []
        var colorToRename: OpaliteColor?
        var renameText: String = ""
        var importError: String?
        var isShowingImportError: Bool = false

        // MARK: - Navigation
        var navigationPath: [PortfolioNavigationNode] = []

        // MARK: - Edit Mode
        var isEditingColors: Bool = false
        var selectedColorIDs: Set<UUID> = []

        // MARK: - Misc State
        var swatchSize: SwatchSize = .medium
        var quickActionTrigger: UUID?
        var copiedColorID: UUID?

        #if os(iOS) && !targetEnvironment(macCatalyst)
        var droppedImageItem: DroppedImageItem?
        #endif

        // MARK: - Computed Properties

        /// Title for batch delete confirmation alert
        var batchDeleteAlertTitle: String {
            let count = colorsToDelete.count
            return "Delete \(count) Color\(count == 1 ? "" : "s")?"
        }

        /// Palettes ordered according to user's custom order
        func orderedPalettes(
            palettes: [OpalitePalette],
            paletteOrderData: Data,
            colorManager: ColorManager
        ) -> [OpalitePalette] {
            guard !paletteOrderData.isEmpty,
                  let savedOrder = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) else {
                return palettes
            }

            // Remove duplicate palettes (keep most recently updated)
            var seenIDs: [UUID: OpalitePalette] = [:]
            for palette in palettes {
                if let existing = seenIDs[palette.id] {
                    let older = palette.updatedAt > existing.updatedAt ? existing : palette
                    try? colorManager.deletePalette(older)
                    seenIDs[palette.id] = palette.updatedAt > existing.updatedAt ? palette : existing
                } else {
                    seenIDs[palette.id] = palette
                }
            }
            let paletteDict = seenIDs
            var result: [OpalitePalette] = []

            // Add palettes in saved order
            for id in savedOrder {
                if let palette = paletteDict[id] {
                    result.append(palette)
                }
            }

            // Add any new palettes not in the saved order (at the end)
            for palette in palettes {
                if !savedOrder.contains(palette.id) {
                    result.append(palette)
                }
            }

            return result
        }

        /// Whether all loose colors are selected
        func allColorsSelected(looseColorCount: Int) -> Bool {
            selectedColorIDs.count == looseColorCount
        }

        // MARK: - Edit Mode Helpers

        /// Whether to show overlays on loose colors (hide when editing)
        func looseColorShowOverlays(swatchShowsOverlays: Bool) -> Bool {
            swatchShowsOverlays && !isEditingColors
        }

        /// Whether loose colors should show navigation (disable when editing)
        var looseColorShowsNavigation: Bool {
            !isEditingColors
        }

        /// Handler for tapping a color swatch in edit mode
        func handleColorTap(_ color: OpaliteColor) {
            guard isEditingColors else { return }
            HapticsManager.shared.selection()
            if selectedColorIDs.contains(color.id) {
                selectedColorIDs.remove(color.id)
            } else {
                selectedColorIDs.insert(color.id)
            }
        }

        // MARK: - File Import

        func handleFileImport(
            _ result: Result<[URL], Error>,
            colorManager: ColorManager,
            toastManager: ToastManager,
            prependPaletteToOrder: (UUID) -> Void
        ) {
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                // Gain security-scoped access
                guard url.startAccessingSecurityScopedResource() else {
                    importError = "Unable to access the selected file."
                    isShowingImportError = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let pathExtension = url.pathExtension.lowercased()

                do {
                    if pathExtension == "opalitecolor" {
                        let preview = try SharingService.previewColorImport(
                            from: url,
                            existingColors: colorManager.colors
                        )
                        if preview.willSkip {
                            importError = "This color already exists in your portfolio."
                            isShowingImportError = true
                        } else {
                            _ = try colorManager.createColor(existing: preview.color)
                            Task { await colorManager.refreshAll() }
                        }
                    } else if pathExtension == "opalitepalette" {
                        let preview = try SharingService.previewPaletteImport(
                            from: url,
                            existingPalettes: colorManager.palettes,
                            existingColors: colorManager.colors
                        )
                        if preview.willUpdate {
                            importError = "A palette with this ID already exists."
                            isShowingImportError = true
                        } else {
                            let importedPalette = try colorManager.createPalette(existing: preview.palette)
                            prependPaletteToOrder(importedPalette.id)
                            Task { await colorManager.refreshAll() }
                        }
                    } else {
                        importError = "Unsupported file type."
                        isShowingImportError = true
                    }
                } catch {
                    importError = error.localizedDescription
                    isShowingImportError = true
                }

            case .failure(let error):
                importError = error.localizedDescription
                isShowingImportError = true
            }
        }

        // MARK: - Palette Order

        /// Prepends a new palette ID to the saved order so it appears at the top.
        func prependPaletteToOrder(_ paletteID: UUID, paletteOrderData: inout Data) {
            var currentOrder: [UUID] = []
            if !paletteOrderData.isEmpty,
               let decoded = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) {
                currentOrder = decoded
            }

            // Remove if already exists (shouldn't happen for new palettes, but safe)
            currentOrder.removeAll { $0 == paletteID }

            // Prepend to front
            currentOrder.insert(paletteID, at: 0)

            // Save
            if let encoded = try? JSONEncoder().encode(currentOrder) {
                paletteOrderData = encoded
            }
        }

        // MARK: - Image Handling (iOS only)

        #if os(iOS) && !targetEnvironment(macCatalyst)
        func handleImageDrop(providers: [NSItemProvider]) -> Bool {
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: UIImage.self) }) else {
                return false
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                guard let self = self, let uiImage = image as? UIImage else { return }
                Task { @MainActor [weak self] in
                    HapticsManager.shared.impact()
                    self?.droppedImageItem = DroppedImageItem(image: uiImage)
                }
            }

            return true
        }

        /// Checks for a shared image from the Share Extension and opens the photo picker if found.
        func checkForSharedImage() {
            guard SharedImageManager.shared.hasSharedImage(),
                  let image = SharedImageManager.shared.loadSharedImage() else {
                return
            }

            // Clear the shared image so we don't re-open it
            SharedImageManager.shared.clearSharedImage()

            // Open the photo color picker with the shared image
            HapticsManager.shared.impact()
            droppedImageItem = DroppedImageItem(image: image)
        }
        #endif

        // MARK: - Mac Catalyst Screen Sampler

        func sampleFromScreen(colorManager: ColorManager, toastManager: ToastManager) {
            SystemColorSampler.sample { uiColor in
                guard let uiColor else {
                    // User cancelled or sampling failed
                    return
                }

                // Extract RGB components
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                // Create and save the color
                let newColor = OpaliteColor(
                    name: nil,
                    red: Double(red),
                    green: Double(green),
                    blue: Double(blue),
                    alpha: Double(alpha)
                )

                do {
                    _ = try colorManager.createColor(existing: newColor)
                    HapticsManager.shared.impact()
                    toastManager.showSuccess("Color sampled from screen")
                    OpaliteTipActions.advanceTipsAfterContentCreation()
                } catch {
                    toastManager.show(error: .colorCreationFailed)
                }
            }
        }

        // MARK: - Actions

        func toggleEditMode() {
            HapticsManager.shared.selection()
            withAnimation {
                isEditingColors.toggle()
                if !isEditingColors {
                    selectedColorIDs.removeAll()
                }
            }
        }

        func selectAllColors(looseColors: [OpaliteColor]) {
            HapticsManager.shared.selection()
            if selectedColorIDs.count == looseColors.count {
                selectedColorIDs.removeAll()
            } else {
                selectedColorIDs = Set(looseColors.map(\.id))
            }
        }

        func confirmBatchDelete(looseColors: [OpaliteColor]) {
            HapticsManager.shared.notification(.warning)
            colorsToDelete = looseColors.filter { selectedColorIDs.contains($0.id) }
        }

        func executeBatchDelete(colorManager: ColorManager) {
            HapticsManager.shared.selection()
            withAnimation {
                for color in colorsToDelete {
                    try? colorManager.deleteColor(color)
                }
                colorsToDelete = []
                selectedColorIDs.removeAll()
                isEditingColors = false
            }
        }

        func deleteColor(_ color: OpaliteColor, colorManager: ColorManager, toastManager: ToastManager) {
            HapticsManager.shared.selection()
            withAnimation {
                do {
                    try colorManager.deleteColor(color)
                } catch {
                    toastManager.show(error: .colorDeletionFailed)
                }
            }
            colorToDelete = nil
        }

        func renameColor(colorManager: ColorManager, toastManager: ToastManager) {
            HapticsManager.shared.selection()
            if let color = colorToRename {
                do {
                    try colorManager.renameColor(color, to: renameText.isEmpty ? nil : renameText)
                } catch {
                    toastManager.show(error: .colorUpdateFailed)
                }
            }
            colorToRename = nil
            renameText = ""
        }

        func createNewPalette(
            colorManager: ColorManager,
            subscriptionManager: SubscriptionManager,
            toastManager: ToastManager,
            paletteOrderData: inout Data
        ) {
            withAnimation {
                HapticsManager.shared.selection()
                if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                    do {
                        let newPalette = try colorManager.createPalette(name: "New Palette")
                        prependPaletteToOrder(newPalette.id, paletteOrderData: &paletteOrderData)
                        OpaliteTipActions.advanceTipsAfterContentCreation()
                    } catch {
                        toastManager.show(error: .paletteCreationFailed)
                    }
                } else {
                    isShowingPaywall = true
                }
            }
        }
    }
}

// MARK: - Identifiable wrapper for dropped images

#if os(iOS) && !targetEnvironment(macCatalyst)
struct DroppedImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif

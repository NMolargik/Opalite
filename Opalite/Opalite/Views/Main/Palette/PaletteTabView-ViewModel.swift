//
//  PaletteTabView-ViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

extension PaletteTabView {
    @Observable
    final class ViewModel {
        var isPalettesExpanded: Bool = true
        var isUnassignedExpanded: Bool = true
        var path: [Route] = []
        var isPresentingNewColorEditor: Bool = false
        
        // Deletion alert state
        var pendingDeletionPalette: OpalitePalette?
        var pendingDeletionColor: OpaliteColor?
        var isShowingDeletePaletteAlert: Bool = false
        var isShowingDeleteColorAlert: Bool = false
        
        func beginCreateColor() {
            isPresentingNewColorEditor = true
        }
        
        func cancelCreateColor() {
            isPresentingNewColorEditor = false
        }
        
        func pushPalette(_ palette: OpalitePalette) {
            path.append(.palette(palette))
        }
        
        func pushColor(_ color: OpaliteColor) {
            path.append(.color(color))
        }
        
        func requestDeletePalette(_ palette: OpalitePalette) {
            pendingDeletionPalette = palette
            isShowingDeletePaletteAlert = true
        }
        
        func requestDeleteColor(_ color: OpaliteColor) {
            pendingDeletionColor = color
            isShowingDeleteColorAlert = true
        }
        
        func cancelDeletePalette() {
            isShowingDeletePaletteAlert = false
            pendingDeletionPalette = nil
        }
        
        func cancelDeleteColor() {
            isShowingDeleteColorAlert = false
            pendingDeletionColor = nil
        }
    }
}

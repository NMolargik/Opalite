//
//  ColorDetailViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import SwiftUI

extension ColorDetailView {
    @Observable
    class ViewModel {
        var notesDraft: String
        var isSavingNotes: Bool = false
        let color: OpaliteColor
        
        init(color: OpaliteColor) {
            self.color = color
            self.notesDraft = color.notes ?? ""
        }
        
        func saveNotes(using colorManager: ColorManager, onError: ((OpaliteError) -> Void)? = nil) {
            isSavingNotes = true
            defer { isSavingNotes = false }
            do {
                try colorManager.updateColor(color) { c in
                    let trimmed = self.notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    c.notes = trimmed.isEmpty ? nil : trimmed
                }
            } catch {
                onError?(.colorUpdateFailed)
            }
        }

        func rename(to newName: String, using colorManager: ColorManager, onError: ((OpaliteError) -> Void)? = nil) {
            do {
                try colorManager.updateColor(color) { c in
                    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    c.name = trimmed.isEmpty ? nil : trimmed
                }
            } catch {
                onError?(.colorUpdateFailed)
            }
        }

        func applyEditorUpdate(from updatedColor: OpaliteColor, using colorManager: ColorManager, onError: ((OpaliteError) -> Void)? = nil) {
            do {
                try colorManager.updateColor(color) { c in
                    c.name = updatedColor.name
                    c.red = updatedColor.red
                    c.green = updatedColor.green
                    c.blue = updatedColor.blue
                    c.alpha = updatedColor.alpha
                }
            } catch {
                onError?(.colorUpdateFailed)
            }
        }
        
        func deleteColor(using colorManager: ColorManager) throws {
            try colorManager.deleteColor(color)
        }
        
        func detachFromPalette(using colorManager: ColorManager) {
            colorManager.detachColorFromPalette(color)
        }
        
        var badgeText: String {
            color.name ?? color.hexString
        }
    }
}

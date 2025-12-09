//
//  ColorEditorView-ViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

extension ColorEditorView {
    @Observable
    class ViewModel {
        var originalColor: OpaliteColor?
        var palette: OpalitePalette?

        var tempColor: OpaliteColor
        var mode: ColorPickerTab = .grid
        var isShowingPaletteStrip: Bool = false
        var isExpanded: Bool = true
        var didCopyHex: Bool = false

        init(color: OpaliteColor?, palette: OpalitePalette?) {
            self.originalColor = color
            self.palette = palette

            if let color {
                // Create a temporary copy so edits don't immediately mutate the original
                self.tempColor = OpaliteColor(
                    name: color.name,
                    notes: color.notes,
                    isPinned: color.isPinned,
                    createdByDisplayName: color.createdByDisplayName,
                    createdOnDeviceName: color.createdOnDeviceName,
                    createdAt: color.createdAt,
                    updatedAt: color.updatedAt,
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: color.alpha,
                    palette: color.palette
                )
            } else {
                // Default tempColor to pure white when creating a brand new color
                self.tempColor = OpaliteColor(
                    name: nil,
                    red: 1.0,
                    green: 1.0,
                    blue: 1.0,
                    alpha: 1.0
                )
            }
        }
    }
}

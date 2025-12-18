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

        var tempColor: OpaliteColor
        var mode: ColorPickerTab = .grid
        var isShowingPaletteStrip: Bool = false
        var isColorExpanded: Bool = false
        var didCopyHex: Bool = false

        init(color: OpaliteColor?) {
            self.originalColor = color

            if let color {
                // Create a temporary copy so edits don't immediately mutate the original
                self.tempColor = OpaliteColor(
                    name: color.name,
                    notes: color.notes,
                    createdByDisplayName: color.createdByDisplayName,
                    createdOnDeviceName: color.createdOnDeviceName,
                    createdAt: color.createdAt,
                    updatedAt: color.updatedAt,
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: color.alpha,
                    palette: nil
                )
            } else {
                // Default tempColor to pure white when creating a brand new color
                self.tempColor = OpaliteColor(
                    name: nil,
                    red: 0.5,
                    green: 0.6,
                    blue: 0.7,
                    alpha: 1.0
                )
            }
        }
    }
}


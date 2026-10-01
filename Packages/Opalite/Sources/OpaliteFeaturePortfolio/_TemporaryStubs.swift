//
//  _TemporaryStubs.swift
//  OpaliteFeaturePortfolio
//
//  TEMPORARY: local stand-ins for views other agents are writing concurrently
//  (OpaliteFeatureColorEditor's ColorEditorView/PhotoSamplerSheet and
//  OpaliteFeatureSharing's sheets). Declarations in this module shadow the imported
//  ones, so this file compiles either way. DELETE BEFORE FINISHING.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureColorEditor

struct ColorEditorView: View {
    let mode: ColorEditorMode
    let onCancel: () -> Void
    let onSave: (ColorEditorResult) -> Void

    init(mode: ColorEditorMode, onCancel: @escaping () -> Void, onSave: @escaping (ColorEditorResult) -> Void) {
        self.mode = mode
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Text("Color Editor (stub)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { onSave(ColorEditorResult(rgba: RGBA(red: 0.5, green: 0.5, blue: 0.5))) }
                    }
                }
        }
    }
}

struct PhotoSamplerSheet: View {
    let image: PlatformImage?
    let onSample: (RGBA) -> Void

    init(image: PlatformImage? = nil, onSample: @escaping (RGBA) -> Void) {
        self.image = image
        self.onSample = onSample
    }

    var body: some View { Text("Photo Sampler (stub)") }
}

struct ColorExportSheet: View {
    let color: OpaliteColor
    init(color: OpaliteColor) { self.color = color }
    var body: some View { Text("Export (stub)") }
}

struct PaletteExportSheet: View {
    let palette: OpalitePalette
    init(palette: OpalitePalette) { self.palette = palette }
    var body: some View { Text("Export (stub)") }
}

struct PublishColorSheet: View {
    let color: OpaliteColor
    init(color: OpaliteColor) { self.color = color }
    var body: some View { Text("Publish (stub)") }
}

struct PublishPaletteSheet: View {
    let palette: OpalitePalette
    init(palette: OpalitePalette) { self.palette = palette }
    var body: some View { Text("Publish (stub)") }
}
#endif

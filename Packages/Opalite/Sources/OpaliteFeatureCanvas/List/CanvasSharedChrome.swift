//
//  CanvasSharedChrome.swift
//  OpaliteFeatureCanvas
//
//  Bits the list and the editor share: the rename alert, the link-palette menu content,
//  and the delete confirmation.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

/// Menu items that link this canvas to one of the user's palettes (or unlink it).
struct PaletteLinkMenuContent: View {
    @Environment(PortfolioModel.self) private var portfolio
    let canvas: CanvasFile

    var body: some View {
        if portfolio.orderedPalettes.isEmpty {
            Text("No palettes yet")
        }
        ForEach(portfolio.orderedPalettes) { palette in
            Button {
                Haptics.selection()
                portfolio.link(canvas, to: palette)
            } label: {
                Label(palette.name, systemImage: canvas.palette?.id == palette.id ? "checkmark" : "swatchpalette")
            }
        }
        if let linked = canvas.palette {
            Divider()
            Button(role: .destructive) {
                Haptics.selection()
                portfolio.link(nil, to: linked)
            } label: {
                Label("Unlink Palette", systemImage: "link.badge.minus")
            }
        }
    }
}

struct CanvasRenameAlert: ViewModifier {
    @Environment(CanvasModel.self) private var canvases
    @Binding var canvas: CanvasFile?
    @State private var title = ""

    func body(content: Content) -> some View {
        content.alert("Rename Canvas", isPresented: Binding(get: { canvas != nil }, set: { if !$0 { canvas = nil } })) {
            TextField("Canvas name", text: $title)
                .accessibilityIdentifier("canvas.rename.field")
            Button("Cancel", role: .cancel) { canvas = nil }
            Button("Rename") {
                if let canvas { canvases.rename(canvas, to: title) }
                canvas = nil
            }
        }
        .onChange(of: canvas?.id) { _, _ in title = canvas?.title ?? "" }
    }
}

struct CanvasDeleteConfirmation: ViewModifier {
    @Environment(CanvasModel.self) private var canvases
    @Binding var canvas: CanvasFile?
    var onDeleted: (() -> Void)?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            canvas.map { Text("Delete “\($0.title)”?") } ?? Text("Delete Canvas?"),
            isPresented: Binding(get: { canvas != nil }, set: { if !$0 { canvas = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Canvas", role: .destructive) {
                if let canvas {
                    canvases.delete(canvas)
                    Haptics.mediumImpact()
                    onDeleted?()
                }
                canvas = nil
            }
            Button("Cancel", role: .cancel) { canvas = nil }
        } message: {
            Text("The drawing and its placed images are removed from every device. This can't be undone.")
        }
    }
}

extension View {
    func canvasRenameAlert(for canvas: Binding<CanvasFile?>) -> some View {
        modifier(CanvasRenameAlert(canvas: canvas))
    }

    func canvasDeleteConfirmation(for canvas: Binding<CanvasFile?>, onDeleted: (() -> Void)? = nil) -> some View {
        modifier(CanvasDeleteConfirmation(canvas: canvas, onDeleted: onDeleted))
    }
}
#endif

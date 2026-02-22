//
//  CanvasSectionView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/21/26.
//

import SwiftUI
import SwiftData

#if canImport(PencilKit)
import PencilKit

struct CanvasSectionView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(CanvasManager.self) private var canvasManager
    @Environment(ToastManager.self) private var toastManager

    @Bindable var palette: OpalitePalette

    let onOpenCanvas: (CanvasFile) -> Void

    @State private var isShowingCanvasPicker: Bool = false
    @State private var showRemoveConfirmation: Bool = false
    @State private var exportedImage: UIImage?
    @State private var showShareSheet: Bool = false

    var body: some View {
        SectionCard(title: "Canvas", systemImage: "pencil.and.scribble") {
            if let canvas = palette.canvasFile {
                linkedCanvasContent(canvas)
            } else {
                unlinkedContent
            }
        }
        .sheet(isPresented: $isShowingCanvasPicker) {
            CanvasPickerSheet { canvas in
                colorManager.attachCanvas(canvas, to: palette) { error in
                    toastManager.show(error: error)
                }
            }
        }
        .alert("Remove Canvas Link?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            Button("Remove", role: .destructive) {
                HapticsManager.shared.selection()
                colorManager.detachCanvasFromPalette(palette) { error in
                    toastManager.show(error: error)
                }
            }
        } message: {
            Text("This will unlink the canvas from this palette. The canvas itself will not be deleted.")
        }
        .background {
            ShareSheetPresenter(
                image: exportedImage,
                title: palette.canvasFile?.title ?? "Canvas",
                isPresented: $showShareSheet
            )
        }
    }

    // MARK: - Linked Canvas Content

    @ViewBuilder
    private func linkedCanvasContent(_ canvas: CanvasFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "scribble")
                .foregroundStyle(.red)
            Text(canvas.title)
                .font(.subheadline)
                .bold()

            Spacer()

            Button {
                HapticsManager.shared.impact()
                onOpenCanvas(canvas)
            } label: {
                Image(systemName: "arrow.right.circle")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button {
                HapticsManager.shared.impact()
                exportCanvasImage(canvas)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 20, height: 20)

            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button(role: .destructive) {
                HapticsManager.shared.selection()
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Unlinked Content

    private var unlinkedContent: some View {
        HStack {
            Text("No Linked Canvas")
            
            Spacer()
            
            Button {
                HapticsManager.shared.selection()
                isShowingCanvasPicker = true
            } label: {
                Label("Link a Canvas", systemImage: "link.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Export

    private func exportCanvasImage(_ canvas: CanvasFile) {
        let drawing = canvasManager.loadDrawing(from: canvas)
        let contentBounds = drawing.bounds

        guard !contentBounds.isEmpty else {
            toastManager.show(message: "Canvas is empty.", style: .error)
            return
        }

        let padding: CGFloat = 40
        let exportBounds = contentBounds.insetBy(dx: -padding, dy: -padding)

        #if os(visionOS)
        let scale: CGFloat = 2.0
        #else
        let scale = UIScreen.main.scale
        #endif
        let drawingImage = drawing.image(from: exportBounds, scale: scale)

        let size = exportBounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let finalImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            drawingImage.draw(at: .zero)
        }

        exportedImage = finalImage
        showShareSheet = true
    }
}

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        CanvasFile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    let canvasManager = CanvasManager(context: container.mainContext)

    return CanvasSectionView(
        palette: OpalitePalette.sample,
        onOpenCanvas: { _ in }
    )
    .environment(colorManager)
    .environment(canvasManager)
    .environment(ToastManager())
    .padding()
}
#endif

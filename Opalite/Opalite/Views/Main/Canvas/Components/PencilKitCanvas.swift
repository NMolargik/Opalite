//
//  PencilKitCanvas.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI
import PencilKit

struct PencilKitCanvas: View {
    @Binding var drawing: PKDrawing
    @Binding var inkColor: UIColor
    var forceColorUpdate: UUID
    var appearTrigger: UUID
    var backgroundImage: UIImage?
    var canvasSize: CGSize?

    var body: some View {
        CanvasDetail_PencilKitRepresentable(
            drawing: $drawing,
            inkColor: $inkColor,
            forceColorUpdate: forceColorUpdate,
            appearTrigger: appearTrigger,
            backgroundImage: backgroundImage,
            canvasSize: canvasSize
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

#if os(iOS)
private struct CanvasDetail_PencilKitRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var inkColor: UIColor
    var forceColorUpdate: UUID
    var appearTrigger: UUID
    var backgroundImage: UIImage?
    var canvasSize: CGSize?

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.backgroundColor = .clear
        view.isOpaque = false
        view.alwaysBounceVertical = true
        view.alwaysBounceHorizontal = true
        view.drawingPolicy = .default
        view.delegate = context.coordinator

        // Enable zooming
        view.minimumZoomScale = 0.5
        view.maximumZoomScale = 4.0
        view.bouncesZoom = true

        // Set content size if we have a stored canvas size
        if let size = canvasSize {
            view.contentSize = size
            context.coordinator.storedCanvasSize = size
        }

        // Add background image view - scales with content
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.clipsToBounds = true
        let contentSize = canvasSize ?? view.bounds.size
        imageView.frame = CGRect(origin: .zero, size: contentSize)
        imageView.image = backgroundImage
        view.insertSubview(imageView, at: 0)
        context.coordinator.backgroundImageView = imageView

        // Attach tool picker
        context.coordinator.attachToolPicker(to: view)

        // Initialize tool only if we haven't seen a user change yet
        if !context.coordinator.userChangedTool {
            context.coordinator.isProgrammaticToolChange = true
            if let currentInk = view.tool as? PKInkingTool {
                view.tool = PKInkingTool(currentInk.inkType, color: inkColor, width: currentInk.width)
            } else {
                view.tool = PKInkingTool(.pen, color: inkColor, width: 4)
            }
            context.coordinator.isProgrammaticToolChange = false
        }
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }

        // Update canvas size if it changed
        if let size = canvasSize, context.coordinator.storedCanvasSize != size {
            context.coordinator.storedCanvasSize = size
            uiView.contentSize = size
            context.coordinator.backgroundImageView?.frame = CGRect(origin: .zero, size: size)
        }

        // Update background image if changed
        if context.coordinator.backgroundImageView?.image !== backgroundImage {
            context.coordinator.backgroundImageView?.image = backgroundImage
            // Ensure the image view frame matches the canvas size
            if let size = canvasSize {
                context.coordinator.backgroundImageView?.frame = CGRect(origin: .zero, size: size)
            }
        }

        // Re-attach tool picker when view reappears
        if context.coordinator.lastAppearTrigger != appearTrigger {
            context.coordinator.lastAppearTrigger = appearTrigger
            context.coordinator.reattachToolPicker()
        }

        // Check if we need to force a color update from our swatch picker
        let shouldForceUpdate = context.coordinator.lastForceColorUpdate != forceColorUpdate
        if shouldForceUpdate {
            context.coordinator.lastForceColorUpdate = forceColorUpdate
        }

        // Respect user changes from the tool picker, unless we're forcing an update from our picker
        guard shouldForceUpdate || !context.coordinator.userChangedTool else { return }

        if let ink = uiView.tool as? PKInkingTool {
            if ink.color != inkColor || shouldForceUpdate {
                let newTool = PKInkingTool(ink.inkType, color: inkColor, width: ink.width)
                context.coordinator.isProgrammaticToolChange = true
                uiView.tool = newTool
                context.coordinator.isProgrammaticToolChange = false
            }
        } else if shouldForceUpdate {
            // Only switch to inking tool if forcing update (user selected from our picker)
            let newTool = PKInkingTool(.pen, color: inkColor, width: 4)
            context.coordinator.isProgrammaticToolChange = true
            uiView.tool = newTool
            context.coordinator.isProgrammaticToolChange = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, PKToolPickerObserver {
        @Binding var drawing: PKDrawing
        weak var canvasView: PKCanvasView?
        weak var backgroundImageView: UIImageView?
        var toolPicker: PKToolPicker?
        var userChangedTool = false
        var isProgrammaticToolChange = false
        var lastForceColorUpdate: UUID?
        var lastAppearTrigger: UUID?
        var storedCanvasSize: CGSize?

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func reattachToolPicker() {
            guard let canvasView = canvasView, let toolPicker = toolPicker else { return }
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func attachToolPicker(to canvasView: PKCanvasView) {
            self.canvasView = canvasView
            guard canvasView.window != nil else {
                DispatchQueue.main.async { [weak self, weak canvasView] in
                    if let canvasView { self?.attachToolPicker(to: canvasView) }
                }
                return
            }
            if toolPicker == nil {
                toolPicker = PKToolPicker()
            }
            guard let toolPicker else { return }
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            canvasView.becomeFirstResponder()
        }

        func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
            if !isProgrammaticToolChange {
                userChangedTool = true
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }

        deinit {
            if let toolPicker {
                toolPicker.removeObserver(self)
                if let canvasView {
                    toolPicker.removeObserver(canvasView)
                }
            }
        }
    }
}
#elseif os(macOS)
private struct CanvasDetail_PencilKitRepresentable: NSViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var inkColor: UIColor
    var forceColorUpdate: UUID
    var appearTrigger: UUID
    var backgroundImage: UIImage?
    var canvasSize: CGSize?

    func makeNSView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .default
        view.delegate = context.coordinator

        // Add background image view
        if let nsImage = backgroundImage {
            let imageView = NSImageView()
            imageView.image = NSImage(cgImage: nsImage.cgImage!, size: NSSize(width: nsImage.size.width, height: nsImage.size.height))
            imageView.imageScaling = .scaleNone
            imageView.frame = view.bounds
            imageView.autoresizingMask = [.width, .height]
            view.addSubview(imageView, positioned: .below, relativeTo: nil)
            context.coordinator.backgroundImageView = imageView
        }

        // Initialize with current color (pen as default)
        view.tool = PKInkingTool(.pen, color: inkColor, width: 4)
        return view
    }

    func updateNSView(_ nsView: PKCanvasView, context: Context) {
        if nsView.drawing != drawing {
            nsView.drawing = drawing
        }

        // Update background image if changed
        if let bgImageView = context.coordinator.backgroundImageView, let uiImage = backgroundImage {
            let nsImage = NSImage(cgImage: uiImage.cgImage!, size: NSSize(width: uiImage.size.width, height: uiImage.size.height))
            if bgImageView.image !== nsImage {
                bgImageView.image = nsImage
            }
        }

        // Only update the tool if the color changed or we're not currently using an inking tool
        let currentWidth: CGFloat
        let currentType: PKInkingTool.InkType
        if let ink = nsView.tool as? PKInkingTool {
            currentWidth = ink.width
            currentType = ink.inkType
            if ink.color != inkColor {
                nsView.tool = PKInkingTool(currentType, color: inkColor, width: currentWidth)
            }
        } else {
            // Switch to an inking tool with the chosen color
            nsView.tool = PKInkingTool(.pen, color: inkColor, width: 4)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        weak var backgroundImageView: NSImageView?

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}
#endif

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
    var canvasSize: CGSize?
    @Binding var contentOffset: CGPoint
    @Binding var zoomScale: CGFloat
    var showToolPickerTrigger: UUID
    @Binding var externalTool: PKTool?

    var body: some View {
        CanvasDetail_PencilKitRepresentable(
            drawing: $drawing,
            inkColor: $inkColor,
            forceColorUpdate: forceColorUpdate,
            appearTrigger: appearTrigger,
            canvasSize: canvasSize,
            contentOffset: $contentOffset,
            zoomScale: $zoomScale,
            showToolPickerTrigger: showToolPickerTrigger,
            externalTool: $externalTool
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
    var canvasSize: CGSize?
    @Binding var contentOffset: CGPoint
    @Binding var zoomScale: CGFloat
    var showToolPickerTrigger: UUID
    @Binding var externalTool: PKTool?

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.overrideUserInterfaceStyle = .light
        view.drawing = drawing
        view.backgroundColor = .clear
        view.isOpaque = false
        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, allow drawing with mouse/trackpad
        view.drawingPolicy = .anyInput
        #else
        view.drawingPolicy = .default
        #endif
        view.delegate = context.coordinator

        // Disable bouncing to prevent showing hard edges
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = false
        view.bounces = false
        view.bouncesZoom = false

        // Enable zooming
        view.minimumZoomScale = 0.25
        view.maximumZoomScale = 4.0

        // Set content size if we have a stored canvas size
        if let size = canvasSize {
            view.contentSize = size
            context.coordinator.storedCanvasSize = size
            context.coordinator.viewSize = view.bounds.size
        }

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
        }

        // Track view size for scroll bounds calculation
        context.coordinator.viewSize = uiView.bounds.size

        // Re-attach tool picker when view reappears
        if context.coordinator.lastAppearTrigger != appearTrigger {
            context.coordinator.lastAppearTrigger = appearTrigger
            context.coordinator.reattachToolPicker()
        }

        // Show tool picker when triggered (for Mac Catalyst toolbar button)
        if context.coordinator.lastShowToolPickerTrigger != showToolPickerTrigger {
            context.coordinator.lastShowToolPickerTrigger = showToolPickerTrigger
            context.coordinator.reattachToolPicker()
        }

        // Apply external tool changes (from Mac Catalyst custom tool picker)
        if let tool = externalTool {
            context.coordinator.isProgrammaticToolChange = true
            uiView.tool = tool
            context.coordinator.isProgrammaticToolChange = false
            // Clear it after applying
            DispatchQueue.main.async {
                self.externalTool = nil
            }
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
                context.coordinator.toolPicker?.selectedTool = newTool
                context.coordinator.isProgrammaticToolChange = false
            }
        } else if shouldForceUpdate {
            // Only switch to inking tool if forcing update (user selected from our picker)
            let newTool = PKInkingTool(.pen, color: inkColor, width: 4)
            context.coordinator.isProgrammaticToolChange = true
            uiView.tool = newTool
            context.coordinator.toolPicker?.selectedTool = newTool
            context.coordinator.isProgrammaticToolChange = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, contentOffset: $contentOffset, zoomScale: $zoomScale)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, PKToolPickerObserver, UIScrollViewDelegate {
        @Binding var drawing: PKDrawing
        @Binding var contentOffset: CGPoint
        @Binding var zoomScale: CGFloat
        weak var canvasView: PKCanvasView?
        var toolPicker: PKToolPicker?
        var userChangedTool = false
        var isProgrammaticToolChange = false
        var lastForceColorUpdate: UUID?
        var lastAppearTrigger: UUID?
        var lastShowToolPickerTrigger: UUID?
        var storedCanvasSize: CGSize?
        var viewSize: CGSize = .zero

        init(drawing: Binding<PKDrawing>, contentOffset: Binding<CGPoint>, zoomScale: Binding<CGFloat>) {
            _drawing = drawing
            _contentOffset = contentOffset
            _zoomScale = zoomScale
        }

        // MARK: - UIScrollViewDelegate

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            constrainContentOffset(scrollView)
            updateScrollState(scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            constrainContentOffset(scrollView)
            updateScrollState(scrollView)
        }

        private func updateScrollState(_ scrollView: UIScrollView) {
            DispatchQueue.main.async { [weak self] in
                self?.contentOffset = scrollView.contentOffset
                self?.zoomScale = scrollView.zoomScale
            }
        }

        private func constrainContentOffset(_ scrollView: UIScrollView) {
            guard let canvasSize = storedCanvasSize else { return }

            let zoomScale = scrollView.zoomScale
            let scaledContentWidth = canvasSize.width * zoomScale
            let scaledContentHeight = canvasSize.height * zoomScale
            let viewWidth = scrollView.bounds.width
            let viewHeight = scrollView.bounds.height

            var offset = scrollView.contentOffset

            // Calculate the maximum allowed offset
            let maxOffsetX = max(0, scaledContentWidth - viewWidth)
            let maxOffsetY = max(0, scaledContentHeight - viewHeight)

            // Constrain X offset
            if offset.x < 0 {
                offset.x = 0
            } else if offset.x > maxOffsetX {
                offset.x = maxOffsetX
            }

            // Constrain Y offset
            if offset.y < 0 {
                offset.y = 0
            } else if offset.y > maxOffsetY {
                offset.y = maxOffsetY
            }

            // Only update if changed to avoid recursion
            if offset != scrollView.contentOffset {
                scrollView.contentOffset = offset
            }
        }

        func reattachToolPicker() {
            guard let canvasView = canvasView else { return }

            // Ensure tool picker exists
            if toolPicker == nil {
                toolPicker = PKToolPicker()
                toolPicker?.addObserver(canvasView)
                toolPicker?.addObserver(self)
            }

            guard let toolPicker else { return }
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            _ = canvasView.becomeFirstResponder()

            #if targetEnvironment(macCatalyst)
            // On Mac Catalyst, aggressively ensure tool picker visibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak canvasView, weak toolPicker] in
                guard let canvasView, let toolPicker else { return }
                // Force the canvas to be first responder and show picker
                if !canvasView.isFirstResponder {
                    _ = canvasView.becomeFirstResponder()
                }
                toolPicker.setVisible(true, forFirstResponder: canvasView)

                // Also try showing via the window
                if let window = canvasView.window {
                    toolPicker.setVisible(true, forFirstResponder: canvasView)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        _ = canvasView.becomeFirstResponder()
                    }
                }
            }
            #endif
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
            _ = canvasView.becomeFirstResponder()

            #if targetEnvironment(macCatalyst)
            // On Mac Catalyst, the tool picker needs additional prompting to appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak canvasView, weak toolPicker] in
                guard let canvasView, let toolPicker else { return }
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                _ = canvasView.becomeFirstResponder()
            }
            #endif
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
    var canvasSize: CGSize?
    @Binding var contentOffset: CGPoint
    @Binding var zoomScale: CGFloat
    var showToolPickerTrigger: UUID
    @Binding var externalTool: PKTool?

    func makeNSView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .default
        view.delegate = context.coordinator

        // Initialize with current color (pen as default)
        view.tool = PKInkingTool(.pen, color: inkColor, width: 4)
        return view
    }

    func updateNSView(_ nsView: PKCanvasView, context: Context) {
        if nsView.drawing != drawing {
            nsView.drawing = drawing
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

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}
#endif

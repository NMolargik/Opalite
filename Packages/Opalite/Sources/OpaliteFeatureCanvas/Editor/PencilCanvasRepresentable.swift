//
//  PencilCanvasRepresentable.swift
//  OpaliteFeatureCanvas
//
//  The PencilKit canvas: a zoomable, pannable `PKCanvasView` sized to the stored canvas,
//  the system tool picker (shown/hidden on request, re-shown when the system drops it),
//  ink pushed from the swatch strip, external tools from the Catalyst strip, and the
//  viewport + obscured-inset reports the SwiftUI overlays build on.
//

#if canImport(PencilKit) && (os(iOS) || os(visionOS))
import SwiftUI
import UIKit
import PencilKit

struct PencilCanvasRepresentable: UIViewRepresentable {
    let drawing: PKDrawing
    let canvasSize: CGSize
    let inkColor: UIColor
    let inkStamp: UUID
    let externalTool: PKTool?
    let externalToolStamp: UUID
    let isToolPickerVisible: Bool
    let suppressToolPicker: Bool
    let isInteractionEnabled: Bool
    let onDrawingChanged: (PKDrawing) -> Void
    let onViewportChanged: (CGPoint, CGFloat, CGSize) -> Void
    let onObscuredInsetChanged: (CGFloat) -> Void
    let onUserToolChanged: (PKTool) -> Void

    func makeUIView(context: Context) -> OpaliteCanvasView {
        let view = OpaliteCanvasView()
        view.overrideUserInterfaceStyle = .light
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawing = drawing
        view.delegate = context.coordinator
        #if targetEnvironment(macCatalyst)
        view.drawingPolicy = .anyInput
        #else
        view.drawingPolicy = .default
        #endif
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = false
        view.bounces = false
        view.bouncesZoom = false
        view.minimumZoomScale = 0.25
        view.maximumZoomScale = 4
        view.contentSize = canvasSize
        view.tool = PKInkingTool(.pen, color: inkColor, width: 4)
        view.accessibilityLabel = String(localized: "Drawing canvas")

        let coordinator = context.coordinator
        coordinator.canvasView = view
        coordinator.storedCanvasSize = canvasSize
        view.onMovedToWindow = { [weak coordinator] in coordinator?.windowDidAppear() }
        #if targetEnvironment(macCatalyst)
        // Clicking any SwiftUI control in the window can move first responder away from the
        // canvas, after which PencilKit ignores pointer drags. Take it back on touch-down.
        view.addGestureRecognizer(FirstResponderReclaimingRecognizer())
        #endif
        return view
    }

    func updateUIView(_ view: OpaliteCanvasView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isUpdatingView = true
        defer {
            coordinator.isUpdatingView = false
            coordinator.flushDeferredViewport()
        }
        coordinator.onDrawingChanged = onDrawingChanged
        coordinator.onViewportChanged = onViewportChanged
        coordinator.onObscuredInsetChanged = onObscuredInsetChanged
        coordinator.onUserToolChanged = onUserToolChanged

        if view.drawing != drawing {
            coordinator.isApplyingDrawing = true
            view.drawing = drawing
            view.undoManager?.removeAllActions()
            coordinator.isApplyingDrawing = false
        }

        if coordinator.storedCanvasSize != canvasSize {
            coordinator.storedCanvasSize = canvasSize
            view.contentSize = canvasSize
        }

        view.isUserInteractionEnabled = isInteractionEnabled

        if coordinator.lastInkStamp != inkStamp {
            coordinator.lastInkStamp = inkStamp
            coordinator.applyInk(inkColor)
        }

        if coordinator.lastExternalToolStamp != externalToolStamp, let externalTool {
            coordinator.lastExternalToolStamp = externalToolStamp
            coordinator.apply(tool: externalTool)
        }

        let wantsPicker = isToolPickerVisible && !suppressToolPicker
        if coordinator.wantsToolPicker != wantsPicker {
            coordinator.wantsToolPicker = wantsPicker
            coordinator.syncToolPickerVisibility()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, PKToolPickerObserver {
        weak var canvasView: OpaliteCanvasView?
        #if targetEnvironment(macCatalyst)
        nonisolated(unsafe) private var keyWindowObserver: (any NSObjectProtocol)?

        override init() {
            super.init()
            keyWindowObserver = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.windowDidBecomeKey() }
            }
        }

        deinit {
            if let keyWindowObserver { NotificationCenter.default.removeObserver(keyWindowObserver) }
        }
        #endif

        var toolPicker: PKToolPicker?
        var storedCanvasSize: CGSize = .zero
        var lastInkStamp: UUID?
        var lastExternalToolStamp: UUID?
        var wantsToolPicker = false
        var isApplyingDrawing = false
        var isProgrammaticToolChange = false
        var isUpdatingView = false
        private var deferredViewport: (CGPoint, CGFloat, CGSize)?

        var onDrawingChanged: ((PKDrawing) -> Void)?
        var onViewportChanged: ((CGPoint, CGFloat, CGSize) -> Void)?
        var onObscuredInsetChanged: ((CGFloat) -> Void)?
        var onUserToolChanged: ((PKTool) -> Void)?

        // MARK: Window

        func windowDidAppear() {
            guard let canvasView else { return }
            if toolPicker == nil {
                let picker = PKToolPicker()
                picker.overrideUserInterfaceStyle = .light
                picker.addObserver(canvasView)
                picker.addObserver(self)
                toolPicker = picker
            }
            syncToolPickerVisibility()
            reportViewport(canvasView)
        }

        func syncToolPickerVisibility() {
            guard let canvasView, let toolPicker, canvasView.window != nil else { return }
            toolPicker.setVisible(wantsToolPicker, forFirstResponder: canvasView)
            if wantsToolPicker {
                _ = canvasView.becomeFirstResponder()
            } else {
                onObscuredInsetChanged?(0)
                #if targetEnvironment(macCatalyst)
                // On Mac Catalyst PencilKit only draws with the pointer while the canvas is
                // first responder, whether or not the system picker is showing.
                _ = canvasView.becomeFirstResponder()
                #endif
            }
        }

        #if targetEnvironment(macCatalyst)
        /// Catalyst drops first responder when the window loses key; take it back.
        func windowDidBecomeKey() {
            guard let canvasView, canvasView.window?.isKeyWindow == true, !canvasView.isFirstResponder else { return }
            _ = canvasView.becomeFirstResponder()
        }
        #endif

        // MARK: Tools

        func applyInk(_ color: UIColor) {
            guard let canvasView else { return }
            let tool: PKInkingTool
            if let current = canvasView.tool as? PKInkingTool {
                tool = PKInkingTool(current.inkType, color: color, width: current.width)
            } else {
                tool = PKInkingTool(.pen, color: color, width: 4)
            }
            apply(tool: tool)
        }

        func apply(tool: PKTool) {
            guard let canvasView else { return }
            isProgrammaticToolChange = true
            canvasView.tool = tool
            if let toolPicker {
                if let inking = tool as? PKInkingTool {
                    toolPicker.selectedToolItem = PKToolPickerInkingItem(type: inking.inkType, color: inking.color, width: inking.width)
                } else if let eraser = tool as? PKEraserTool {
                    toolPicker.selectedToolItem = PKToolPickerEraserItem(type: eraser.eraserType, width: eraser.width)
                }
            }
            isProgrammaticToolChange = false
        }

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawing else { return }
            onDrawingChanged?(canvasView.drawing)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            clampContentOffset(scrollView)
            reportViewport(scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            clampContentOffset(scrollView)
            reportViewport(scrollView)
        }

        private func reportViewport(_ scrollView: UIScrollView) {
            let report = (scrollView.contentOffset, scrollView.zoomScale, scrollView.bounds.size)
            if isUpdatingView {
                deferredViewport = report
            } else {
                onViewportChanged?(report.0, report.1, report.2)
            }
        }

        func flushDeferredViewport() {
            guard let deferredViewport else { return }
            self.deferredViewport = nil
            let report = deferredViewport
            DispatchQueue.main.async { [weak self] in self?.onViewportChanged?(report.0, report.1, report.2) }
        }

        /// Keeps the content from sliding past the canvas edge (bouncing is off, but zoom
        /// changes can still leave the offset out of range).
        private func clampContentOffset(_ scrollView: UIScrollView) {
            guard storedCanvasSize != .zero else { return }
            let maxX = max(0, storedCanvasSize.width * scrollView.zoomScale - scrollView.bounds.width)
            let maxY = max(0, storedCanvasSize.height * scrollView.zoomScale - scrollView.bounds.height)
            var offset = scrollView.contentOffset
            offset.x = min(max(0, offset.x), maxX)
            offset.y = min(max(0, offset.y), maxY)
            if offset != scrollView.contentOffset { scrollView.contentOffset = offset }
        }

        // MARK: PKToolPickerObserver

        func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) {
            guard !isProgrammaticToolChange, let canvasView else { return }
            onUserToolChanged?(canvasView.tool)
        }

        func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
            // Re-show when the system hid it under us (e.g. after an alert took first responder).
            guard wantsToolPicker, !toolPicker.isVisible, let canvasView, canvasView.window != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, self.wantsToolPicker, let canvasView = self.canvasView, canvasView.window != nil else { return }
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                _ = canvasView.becomeFirstResponder()
            }
        }

        func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
            guard let canvasView else { return }
            let obscured = toolPicker.frameObscured(in: canvasView)
            let inset = obscured.isNull || obscured.isEmpty ? 0 : max(0, canvasView.bounds.maxY - obscured.minY)
            onObscuredInsetChanged?(inset)
        }

    }
}

#if targetEnvironment(macCatalyst)
/// A passive recognizer that makes its view first responder when a touch begins, then
/// fails so PencilKit's own recognizers see every event untouched.
private final class FirstResponderReclaimingRecognizer: UIGestureRecognizer {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let view, !view.isFirstResponder { _ = view.becomeFirstResponder() }
        state = .failed
    }
}
#endif

/// Reports when it joins a window so the tool picker attaches at the right moment.
final class OpaliteCanvasView: PKCanvasView {
    var onMovedToWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onMovedToWindow?() }
    }

    override var canBecomeFirstResponder: Bool { true }
}
#endif

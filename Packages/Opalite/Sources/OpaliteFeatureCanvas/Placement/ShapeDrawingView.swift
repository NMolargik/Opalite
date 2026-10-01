//
//  ShapeDrawingView.swift
//  OpaliteFeatureCanvas
//
//  The touch layer of drag-to-define placement. Idle: a pencil/pointer hover shows a ghost.
//  Drawing: drag corner to corner (aspect-locked when the subject needs it). Adjusting:
//  one finger moves, two fingers or Apple Pencil Pro roll rotate in 5° steps with haptic
//  ticks every 10°. All rect math lives in `ShapePlacementGeometry`.
//

#if os(iOS) || os(visionOS)
import UIKit
import SwiftUI

final class ShapeDrawingView: UIView, UIGestureRecognizerDelegate {
    var onRectChanged: ((CGRect) -> Void)?
    var onPhaseChanged: ((ShapePlacementPhase) -> Void)?
    var onRotationChanged: ((CGFloat) -> Void)?
    var onHoverChanged: ((CGPoint?) -> Void)?
    var constrainedAspectRatio: CGFloat?

    private(set) var phase: ShapePlacementPhase = .idle
    private var drawOrigin: CGPoint = .zero
    private var shapeRect: CGRect = .zero
    private var rotation: CGFloat = 0
    private var isRepositioning = false
    private var lastDragLocation: CGPoint = .zero
    private var lastHapticBucket = 0
    #if os(iOS)
    private var pencilRollBaseline: CGFloat?
    private lazy var impact = UIImpactFeedbackGenerator(style: .light)
    private lazy var canvasFeedback = UICanvasFeedbackGenerator(view: self)
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotate.delegate = self
        addGestureRecognizer(rotate)
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hover)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    // MARK: - Public

    func reset() {
        setPhase(.idle)
        shapeRect = .zero
        rotation = 0
        lastHapticBucket = 0
        isRepositioning = false
        #if os(iOS)
        pencilRollBaseline = nil
        #endif
    }

    /// Jumps straight to the adjusting phase with a default-size rect (VoiceOver path).
    func placeDefault(at point: CGPoint) {
        drawOrigin = point
        shapeRect = ShapePlacementGeometry.defaultRect(centeredAt: point, aspectRatio: constrainedAspectRatio)
        onRectChanged?(shapeRect)
        setPhase(.adjusting)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        onHoverChanged?(nil)
        switch phase {
        case .idle:
            drawOrigin = location
            shapeRect = CGRect(origin: location, size: .zero)
            setPhase(.drawing)
            #if os(iOS)
            impact.prepare()
            #endif
        case .adjusting:
            isRepositioning = true
            lastDragLocation = location
            #if os(iOS)
            if touch.type == .pencil { pencilRollBaseline = -touch.rollAngle }
            #endif
        case .drawing:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        switch phase {
        case .drawing:
            shapeRect = ShapePlacementGeometry.dragRect(from: drawOrigin, to: location, aspectRatio: constrainedAspectRatio)
            onRectChanged?(shapeRect)
        case .adjusting:
            if isRepositioning, event?.allTouches?.count ?? 1 == 1 {
                shapeRect = shapeRect.offsetBy(dx: location.x - lastDragLocation.x, dy: location.y - lastDragLocation.y)
                lastDragLocation = location
                onRectChanged?(shapeRect)
            }
            #if os(iOS)
            if touch.type == .pencil, let baseline = pencilRollBaseline {
                let current = -touch.rollAngle
                rotation += current - baseline
                pencilRollBaseline = current
                emitRotation(at: location)
            }
            #endif
        case .idle:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        switch phase {
        case .drawing:
            shapeRect = ShapePlacementGeometry.finalizedRect(shapeRect, origin: drawOrigin, aspectRatio: constrainedAspectRatio)
            onRectChanged?(shapeRect)
            rotation = 0
            lastHapticBucket = 0
            setPhase(.adjusting)
            #if os(iOS)
            impact.impactOccurred(intensity: 0.6)
            #endif
        case .adjusting:
            isRepositioning = false
            #if os(iOS)
            pencilRollBaseline = nil
            #endif
        case .idle:
            break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isRepositioning = false
        #if os(iOS)
        pencilRollBaseline = nil
        #endif
    }

    // MARK: - Gestures

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard phase == .adjusting, gesture.state == .changed else { return }
        rotation += gesture.rotation
        gesture.rotation = 0
        emitRotation(at: gesture.location(in: self))
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        guard phase == .idle else { return }
        switch gesture.state {
        case .began, .changed: onHoverChanged?(gesture.location(in: self))
        default: onHoverChanged?(nil)
        }
    }

    private func emitRotation(at location: CGPoint) {
        let snapped = ShapePlacementGeometry.snappedRotation(rotation)
        let bucket = ShapePlacementGeometry.hapticBucket(forRotation: snapped)
        if bucket != lastHapticBucket {
            lastHapticBucket = bucket
            #if os(iOS)
            impact.impactOccurred(intensity: 0.6)
            canvasFeedback.alignmentOccurred(at: location)
            #endif
        }
        onRotationChanged?(snapped)
    }

    private func setPhase(_ newPhase: ShapePlacementPhase) {
        phase = newPhase
        onPhaseChanged?(newPhase)
    }
}

/// Bridges `ShapeDrawingView` into the overlay's state.
struct ShapeDrawingRepresentable: UIViewRepresentable {
    @Binding var shapeRect: CGRect
    @Binding var rotation: CGFloat
    @Binding var phase: ShapePlacementPhase
    @Binding var hoverLocation: CGPoint?
    var constrainedAspectRatio: CGFloat?
    /// Bumped by the accessibility "place at center" action.
    var placeAtCenterStamp: UUID

    func makeUIView(context: Context) -> ShapeDrawingView {
        let view = ShapeDrawingView()
        view.constrainedAspectRatio = constrainedAspectRatio
        view.onRectChanged = { shapeRect = $0 }
        view.onPhaseChanged = { phase = $0 }
        view.onRotationChanged = { rotation = $0 }
        view.onHoverChanged = { hoverLocation = $0 }
        view.isAccessibilityElement = true
        view.accessibilityLabel = String(localized: "Placement area")
        view.accessibilityHint = String(localized: "Drag from corner to corner to size the shape")
        context.coordinator.lastStamp = placeAtCenterStamp
        return view
    }

    func updateUIView(_ view: ShapeDrawingView, context: Context) {
        view.constrainedAspectRatio = constrainedAspectRatio
        if phase == .idle, view.phase != .idle { view.reset() }
        if context.coordinator.lastStamp != placeAtCenterStamp {
            context.coordinator.lastStamp = placeAtCenterStamp
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            DispatchQueue.main.async { view.placeDefault(at: center) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastStamp: UUID?
    }
}
#endif

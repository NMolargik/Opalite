//
//  ShapeDrawingView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/8/26.
//

#if canImport(UIKit)
import UIKit

/// Phases for the drag-to-define shape placement flow.
enum ShapePlacementPhase {
    case idle
    case drawing
    case adjusting
}

/// UIView that handles touch gestures for the drag-to-define shape placement system.
///
/// **Draw phase**: Touch down records an origin point. As the finger moves, a bounding rect
/// is computed from origin to current point (with optional aspect-ratio constraint).
/// On touch up the rect is finalized and the view transitions to the adjust phase.
///
/// **Adjust phase**: Single-finger drag repositions the rect. Rotation via two-finger
/// `UIRotationGestureRecognizer` **or** Apple Pencil Pro roll angle, both snapping to
/// 5-degree increments with haptics every 10 degrees.
class ShapeDrawingView: UIView, UIGestureRecognizerDelegate {

    // MARK: - Callbacks

    /// Called whenever the bounding rect changes (during draw or adjust).
    var onRectUpdate: ((CGRect) -> Void)?

    /// Called when the placement phase changes.
    var onPhaseChange: ((ShapePlacementPhase) -> Void)?

    /// Called when rotation changes during adjust phase.
    var onRotationUpdate: ((CGFloat) -> Void)?

    // MARK: - Configuration

    /// Locked aspect ratio (width/height). `nil` means free-form.
    var constrainedAspectRatio: CGFloat?

    // MARK: - Internal State

    private(set) var phase: ShapePlacementPhase = .idle

    /// Origin point where the drag began (in view coordinates).
    private var drawOrigin: CGPoint = .zero

    /// Current bounding rect for the shape.
    private var shapeRect: CGRect = .zero

    /// Cumulative rotation (radians) applied during the adjust phase.
    private var cumulativeRotation: CGFloat = 0

    /// Whether a single-finger drag is currently repositioning.
    private var isDraggingToReposition: Bool = false

    /// Last touch location during reposition drag.
    private var lastDragLocation: CGPoint = .zero

    /// Minimum bounding-box dimension before snapping up.
    private let minimumDimension: CGFloat = 20

    /// Default size for a quick tap (no drag).
    private let defaultTapSize: CGFloat = 100

    // MARK: - Apple Pencil Pro Roll State

    /// Baseline roll angle captured on first pencil touch during adjust phase.
    private var baselinePencilRollAngle: CGFloat?

    // MARK: - Haptic Generators

    private lazy var impactGenerator: UIImpactFeedbackGenerator = {
        UIImpactFeedbackGenerator(style: .light)
    }()

    /// Apple Pencil Pro haptic feedback for alignment/snap.
    private lazy var canvasFeedbackGenerator: UICanvasFeedbackGenerator = {
        UICanvasFeedbackGenerator(view: self)
    }()

    /// Last 10-degree threshold crossed for rotation haptics.
    private var lastRotationHapticThreshold: Int = 0

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }

    // MARK: - Gesture Setup

    private func setupGestures() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear

        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
        addGestureRecognizer(rotationGesture)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    // MARK: - Phase Transitions

    private func setPhase(_ newPhase: ShapePlacementPhase) {
        phase = newPhase
        onPhaseChange?(newPhase)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        switch phase {
        case .idle:
            // Begin drawing
            drawOrigin = location
            shapeRect = CGRect(origin: location, size: .zero)
            setPhase(.drawing)
            impactGenerator.prepare()

        case .adjusting:
            // Begin reposition drag
            isDraggingToReposition = true
            lastDragLocation = location

            // Capture baseline roll angle for Apple Pencil Pro
            if touch.type == .pencil {
                baselinePencilRollAngle = -touch.rollAngle
            }

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
            updateDrawingRect(to: location)

        case .adjusting:
            // Reposition via drag
            if isDraggingToReposition {
                let dx = location.x - lastDragLocation.x
                let dy = location.y - lastDragLocation.y
                shapeRect = shapeRect.offsetBy(dx: dx, dy: dy)
                lastDragLocation = location
                onRectUpdate?(shapeRect)
            }

            // Apple Pencil Pro roll → rotation
            if touch.type == .pencil, let baseline = baselinePencilRollAngle {
                let rawAngle = -touch.rollAngle
                let pencilDelta = rawAngle - baseline
                baselinePencilRollAngle = rawAngle

                cumulativeRotation += pencilDelta
                applySnappedRotation(at: location)
            }

        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        switch phase {
        case .drawing:
            finalizeDrawing()

        case .adjusting:
            isDraggingToReposition = false
            baselinePencilRollAngle = nil

        case .idle:
            break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isDraggingToReposition = false
        baselinePencilRollAngle = nil
    }

    // MARK: - Drawing Phase Helpers

    /// Computes the bounding rect from `drawOrigin` to `currentPoint`, applying
    /// aspect-ratio constraints when required.
    private func updateDrawingRect(to currentPoint: CGPoint) {
        var width = abs(currentPoint.x - drawOrigin.x)
        var height = abs(currentPoint.y - drawOrigin.y)

        if let ratio = constrainedAspectRatio {
            // Constrain: use the larger axis to determine the other
            let candidateHeight = width / ratio
            let candidateWidth = height * ratio
            if candidateHeight <= height {
                // Width is the limiting axis
                height = candidateHeight
            } else {
                width = candidateWidth
            }
        }

        let originX = min(drawOrigin.x, currentPoint.x)
        let originY = min(drawOrigin.y, currentPoint.y)

        // Re-derive origin so the rect always grows away from drawOrigin
        let x: CGFloat
        let y: CGFloat

        if currentPoint.x >= drawOrigin.x {
            x = drawOrigin.x
        } else {
            x = drawOrigin.x - width
        }

        if currentPoint.y >= drawOrigin.y {
            y = drawOrigin.y
        } else {
            y = drawOrigin.y - height
        }

        shapeRect = CGRect(x: x, y: y, width: width, height: height)
        onRectUpdate?(shapeRect)
    }

    /// Finalizes the drawing rect. If it's too small (quick tap), use the default size.
    private func finalizeDrawing() {
        if shapeRect.width < minimumDimension && shapeRect.height < minimumDimension {
            // Quick tap — use default size centered on the tap point
            var w = defaultTapSize
            var h = defaultTapSize
            if let ratio = constrainedAspectRatio {
                // Maintain aspect ratio with the default size as the larger axis
                if ratio >= 1.0 {
                    h = w / ratio
                } else {
                    w = h * ratio
                }
            }
            let center = drawOrigin
            shapeRect = CGRect(
                x: center.x - w / 2,
                y: center.y - h / 2,
                width: w,
                height: h
            )
        } else if shapeRect.width < minimumDimension * 2 || shapeRect.height < minimumDimension * 2 {
            // Too small — snap up to minimum
            var w = max(shapeRect.width, minimumDimension * 2)
            var h = max(shapeRect.height, minimumDimension * 2)
            if let ratio = constrainedAspectRatio {
                if ratio >= 1.0 {
                    h = w / ratio
                } else {
                    w = h * ratio
                }
            }
            let center = CGPoint(x: shapeRect.midX, y: shapeRect.midY)
            shapeRect = CGRect(
                x: center.x - w / 2,
                y: center.y - h / 2,
                width: w,
                height: h
            )
        }

        onRectUpdate?(shapeRect)
        cumulativeRotation = 0
        lastRotationHapticThreshold = 0
        setPhase(.adjusting)
        impactGenerator.impactOccurred(intensity: 0.6)
    }

    // MARK: - Rotation (Two-Finger Gesture + Apple Pencil Pro Roll)

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard phase == .adjusting else { return }

        switch gesture.state {
        case .changed:
            cumulativeRotation += gesture.rotation
            gesture.rotation = 0

            let location = gesture.location(in: self)
            applySnappedRotation(at: location)

        default:
            break
        }
    }

    /// Snaps `cumulativeRotation` to 5-degree increments, fires haptics every 10 degrees,
    /// and calls `onRotationUpdate`. Shared by two-finger gesture and Pencil Pro roll.
    private func applySnappedRotation(at location: CGPoint) {
        let degrees = cumulativeRotation * 180 / .pi
        let snappedDegrees = (degrees / 5).rounded() * 5
        let snappedRadians = snappedDegrees * .pi / 180

        // Haptic every 10 degrees
        let currentThreshold = Int(snappedDegrees / 10)
        if currentThreshold != lastRotationHapticThreshold {
            lastRotationHapticThreshold = currentThreshold
            impactGenerator.impactOccurred(intensity: 0.6)
            canvasFeedbackGenerator.alignmentOccurred(at: location)
        }

        onRotationUpdate?(snappedRadians)
    }

    // MARK: - Reset

    /// Resets the view back to idle for a new placement session.
    func reset() {
        setPhase(.idle)
        shapeRect = .zero
        cumulativeRotation = 0
        lastRotationHapticThreshold = 0
        isDraggingToReposition = false
        baselinePencilRollAngle = nil
    }
}

#elseif canImport(AppKit)
import AppKit

enum ShapePlacementPhase {
    case idle
    case drawing
    case adjusting
}

/// macOS counterpart using mouse drag and trackpad rotation.
class ShapeDrawingView: NSView {
    var onRectUpdate: ((CGRect) -> Void)?
    var onPhaseChange: ((ShapePlacementPhase) -> Void)?
    var onRotationUpdate: ((CGFloat) -> Void)?
    var constrainedAspectRatio: CGFloat?

    private(set) var phase: ShapePlacementPhase = .idle
    private var drawOrigin: CGPoint = .zero
    private var shapeRect: CGRect = .zero
    private var cumulativeRotation: CGFloat = 0
    private var isDraggingToReposition: Bool = false
    private var lastDragLocation: CGPoint = .zero
    private let minimumDimension: CGFloat = 20
    private let defaultTapSize: CGFloat = 100
    private var lastRotationHapticThreshold: Int = 0

    override var acceptsFirstResponder: Bool { true }

    private func setPhase(_ newPhase: ShapePlacementPhase) {
        phase = newPhase
        onPhaseChange?(newPhase)
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        switch phase {
        case .idle:
            drawOrigin = location
            shapeRect = CGRect(origin: location, size: .zero)
            setPhase(.drawing)
        case .adjusting:
            isDraggingToReposition = true
            lastDragLocation = location
        case .drawing:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        switch phase {
        case .drawing:
            updateDrawingRect(to: location)
        case .adjusting where isDraggingToReposition:
            let dx = location.x - lastDragLocation.x
            let dy = location.y - lastDragLocation.y
            shapeRect = shapeRect.offsetBy(dx: dx, dy: dy)
            lastDragLocation = location
            onRectUpdate?(shapeRect)
        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch phase {
        case .drawing:
            finalizeDrawing()
        case .adjusting:
            isDraggingToReposition = false
        case .idle:
            break
        }
    }

    override func rotate(with event: NSEvent) {
        guard phase == .adjusting else { return }
        cumulativeRotation += CGFloat(event.rotation) * .pi / 180
        let degrees = cumulativeRotation * 180 / .pi
        let snappedDegrees = (degrees / 5).rounded() * 5
        let snappedRadians = snappedDegrees * .pi / 180
        onRotationUpdate?(snappedRadians)
    }

    private func updateDrawingRect(to currentPoint: CGPoint) {
        var width = abs(currentPoint.x - drawOrigin.x)
        var height = abs(currentPoint.y - drawOrigin.y)

        if let ratio = constrainedAspectRatio {
            let candidateHeight = width / ratio
            let candidateWidth = height * ratio
            if candidateHeight <= height {
                height = candidateHeight
            } else {
                width = candidateWidth
            }
        }

        let x: CGFloat = currentPoint.x >= drawOrigin.x ? drawOrigin.x : drawOrigin.x - width
        let y: CGFloat = currentPoint.y >= drawOrigin.y ? drawOrigin.y : drawOrigin.y - height

        shapeRect = CGRect(x: x, y: y, width: width, height: height)
        onRectUpdate?(shapeRect)
    }

    private func finalizeDrawing() {
        if shapeRect.width < minimumDimension && shapeRect.height < minimumDimension {
            var w = defaultTapSize
            var h = defaultTapSize
            if let ratio = constrainedAspectRatio {
                if ratio >= 1.0 { h = w / ratio } else { w = h * ratio }
            }
            let center = drawOrigin
            shapeRect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        } else if shapeRect.width < minimumDimension * 2 || shapeRect.height < minimumDimension * 2 {
            var w = max(shapeRect.width, minimumDimension * 2)
            var h = max(shapeRect.height, minimumDimension * 2)
            if let ratio = constrainedAspectRatio {
                if ratio >= 1.0 { h = w / ratio } else { w = h * ratio }
            }
            let center = CGPoint(x: shapeRect.midX, y: shapeRect.midY)
            shapeRect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        }

        onRectUpdate?(shapeRect)
        cumulativeRotation = 0
        lastRotationHapticThreshold = 0
        setPhase(.adjusting)
    }

    func reset() {
        setPhase(.idle)
        shapeRect = .zero
        cumulativeRotation = 0
        lastRotationHapticThreshold = 0
        isDraggingToReposition = false
    }
}
#endif

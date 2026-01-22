#if canImport(UIKit)
import UIKit

class HoverDetectionView: UIView, UIGestureRecognizerDelegate {
    var onHoverUpdate: ((CGPoint, CGFloat?) -> Void)?
    var onHoverEnd: (() -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onScaleUpdate: ((CGFloat) -> Void)?
    var onRotationUpdate: ((CGFloat) -> Void)?
    var onAspectRatioUpdate: ((CGFloat) -> Void)?

    /// When true, pinch gestures affect aspect ratio instead of uniform scale
    var useNonUniformScale: Bool = false

    // Baseline roll angle captured on first touch - rotation is relative to this
    private(set) var baselineRollAngle: CGFloat?

    // Baseline altitude angle captured on first touch - scale is relative to this
    private var baselineAltitudeAngle: CGFloat?

    // Current pencil-based scale (from altitude/tilt)
    private var pencilScale: CGFloat = 1.0

    // Track if we're in two-finger mode (pinch/rotate)
    private var isTwoFingerMode: Bool = false

    // Track gesture states to know when both have ended
    private var pinchGestureActive: Bool = false
    private var rotationGestureActive: Bool = false

    // Prevents double-placement when touches and gestures both try to place
    private var hasPlacedInCurrentInteraction: Bool = false

    // Last known location for placement after two-finger gestures
    private var lastGestureLocation: CGPoint = .zero

    // Cumulative rotation from two-finger gesture
    private var twoFingerRotation: CGFloat = 0

    // Cumulative scale from pinch gesture
    private var currentScale: CGFloat = 1.0

    // Current aspect ratio for non-uniform scaling (width/height)
    private var currentAspectRatio: CGFloat = 1.0

    // Track initial touch positions for aspect ratio calculation
    private var initialPinchWidth: CGFloat = 0
    private var initialPinchHeight: CGFloat = 0

    // Haptic feedback for Apple Pencil Pro rotation (iOS only)
    private lazy var canvasFeedbackGenerator: UICanvasFeedbackGenerator = {
        UICanvasFeedbackGenerator(view: self)
    }()

    // Standard haptic for scale/rotate feedback
    private lazy var impactGenerator: UIImpactFeedbackGenerator = {
        UIImpactFeedbackGenerator(style: .light)
    }()

    // Track the last 10-degree threshold crossed for haptic feedback
    private var lastHapticThreshold: Int = 0

    // Track the last scale threshold for haptic feedback
    private var lastScaleHapticThreshold: Int = 10  // Start at 1.0 (10 * 0.1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }

    func resetBaseline() {
        baselineRollAngle = nil
        baselineAltitudeAngle = nil
        pencilScale = 1.0
        lastHapticThreshold = 0
        twoFingerRotation = 0
        currentScale = 1.0
        currentAspectRatio = 1.0
        lastScaleHapticThreshold = 10
        isTwoFingerMode = false
        pinchGestureActive = false
        rotationGestureActive = false
        hasPlacedInCurrentInteraction = false
        initialPinchWidth = 0
        initialPinchHeight = 0
    }

    private func setupGestures() {
        // Hover gesture for Apple Pencil / Pointer
        let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hoverGesture)

        // Pinch gesture for scaling (two-finger)
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)

        // Rotation gesture for rotating (two-finger)
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
        addGestureRecognizer(rotationGesture)
    }

    // Allow simultaneous recognition of pinch and rotation gestures
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow pinch and rotation to work together
        let isPinchOrRotation = gestureRecognizer is UIPinchGestureRecognizer ||
                                gestureRecognizer is UIRotationGestureRecognizer
        let otherIsPinchOrRotation = otherGestureRecognizer is UIPinchGestureRecognizer ||
                                     otherGestureRecognizer is UIRotationGestureRecognizer
        return isPinchOrRotation && otherIsPinchOrRotation
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: self)
            onHoverUpdate?(location, nil)
        case .ended, .cancelled:
            onHoverEnd?()
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            isTwoFingerMode = true
            pinchGestureActive = true
            impactGenerator.prepare()

            // Capture initial touch positions for aspect ratio calculation
            if useNonUniformScale && gesture.numberOfTouches >= 2 {
                let touch0 = gesture.location(ofTouch: 0, in: self)
                let touch1 = gesture.location(ofTouch: 1, in: self)
                initialPinchWidth = abs(touch1.x - touch0.x)
                initialPinchHeight = abs(touch1.y - touch0.y)
                // Ensure minimum values to avoid division by zero
                if initialPinchWidth < 10 { initialPinchWidth = 10 }
                if initialPinchHeight < 10 { initialPinchHeight = 10 }
            }

        case .changed:
            if useNonUniformScale && gesture.numberOfTouches >= 2 {
                // Non-uniform scaling: calculate aspect ratio from touch positions
                let touch0 = gesture.location(ofTouch: 0, in: self)
                let touch1 = gesture.location(ofTouch: 1, in: self)
                let currentWidth = max(10, abs(touch1.x - touch0.x))
                let currentHeight = max(10, abs(touch1.y - touch0.y))

                // Calculate scale factors for each axis
                let widthScale = currentWidth / initialPinchWidth
                let heightScale = currentHeight / initialPinchHeight

                // Update aspect ratio (relative change from initial)
                let newAspectRatio = max(0.25, min(4.0, currentAspectRatio * (widthScale / heightScale)))

                // Also update uniform scale based on height
                let newScale = max(0.25, min(4.0, currentScale * heightScale))

                // Check for haptic feedback
                let currentThreshold = Int(newScale * 10)
                if currentThreshold != lastScaleHapticThreshold {
                    lastScaleHapticThreshold = currentThreshold
                    impactGenerator.impactOccurred(intensity: 0.5)
                }

                onScaleUpdate?(newScale)
                onAspectRatioUpdate?(newAspectRatio)

                // Update stored values
                currentScale = newScale
                currentAspectRatio = newAspectRatio

                // Reset initial positions for incremental updates
                initialPinchWidth = currentWidth
                initialPinchHeight = currentHeight
            } else {
                // Uniform scaling (original behavior)
                let newScale = max(0.25, min(4.0, currentScale * gesture.scale))

                // Check for scale haptic feedback (every 0.1 scale change)
                let currentThreshold = Int(newScale * 10)
                if currentThreshold != lastScaleHapticThreshold {
                    lastScaleHapticThreshold = currentThreshold
                    impactGenerator.impactOccurred(intensity: 0.5)
                }

                onScaleUpdate?(newScale)

                // Reset scale for incremental updates
                gesture.scale = 1.0

                // Update stored scale
                currentScale = newScale
            }

            // Update position to center of pinch
            let location = gesture.location(in: self)
            lastGestureLocation = location
            onHoverUpdate?(location, nil)

        case .ended, .cancelled:
            pinchGestureActive = false
            checkAndPlaceAfterTwoFingerGesture()

        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            isTwoFingerMode = true
            rotationGestureActive = true

        case .changed:
            // Accumulate rotation
            twoFingerRotation += gesture.rotation

            // Snap to 5° increments
            let degrees = twoFingerRotation * 180 / .pi
            let snappedDegrees = (degrees / 5).rounded() * 5
            let snappedRadians = snappedDegrees * .pi / 180

            // Check for rotation haptic feedback
            let currentThreshold = Int(snappedDegrees / 10)
            if currentThreshold != lastHapticThreshold {
                lastHapticThreshold = currentThreshold
                impactGenerator.impactOccurred(intensity: 0.6)
            }

            onRotationUpdate?(snappedRadians)

            // Update position to center of rotation
            let location = gesture.location(in: self)
            lastGestureLocation = location
            onHoverUpdate?(location, nil)

            // Reset rotation for incremental updates
            gesture.rotation = 0

        case .ended, .cancelled:
            rotationGestureActive = false
            checkAndPlaceAfterTwoFingerGesture()

        default:
            break
        }
    }

    /// Called when a two-finger gesture ends - places shape when both gestures are done
    private func checkAndPlaceAfterTwoFingerGesture() {
        // Only place when both gestures have ended and we haven't already placed
        if !pinchGestureActive && !rotationGestureActive && isTwoFingerMode && !hasPlacedInCurrentInteraction {
            hasPlacedInCurrentInteraction = true
            onTap?(lastGestureLocation)
            // Don't reset isTwoFingerMode here - let touchesEnded handle final cleanup
        }
    }

    // Calculate relative roll angle from baseline, snapped to 5° increments
    private func relativeRollAngle(from touch: UITouch) -> CGFloat {
        let rawAngle = -touch.rollAngle

        // Capture baseline on first touch
        if baselineRollAngle == nil {
            baselineRollAngle = rawAngle
        }

        // Calculate relative angle from baseline
        let relativeAngle = rawAngle - (baselineRollAngle ?? 0)

        // Snap to 5° increments for finer control
        let degrees = relativeAngle * 180 / .pi
        let snappedDegrees = (degrees / 5).rounded() * 5
        return snappedDegrees * .pi / 180
    }

    /// Calculates scale factor from pencil altitude (tilt) angle.
    /// Tilting the pencil more upright increases scale, tilting flatter decreases it.
    /// Returns the updated scale and whether it changed significantly for haptic feedback.
    private func updateScaleFromAltitude(_ touch: UITouch) -> (scale: CGFloat, changed: Bool) {
        let altitude = touch.altitudeAngle  // 0 = flat, π/2 = perpendicular

        // Capture baseline on first touch
        if baselineAltitudeAngle == nil {
            baselineAltitudeAngle = altitude
            return (pencilScale, false)
        }

        // Calculate change from baseline
        // Positive change (more upright) = larger scale
        // Negative change (more tilted) = smaller scale
        let altitudeChange = altitude - (baselineAltitudeAngle ?? altitude)

        // Map altitude change to scale multiplier
        // A change of π/8 (22.5°) corresponds to doubling or halving the scale
        let scaleFactor = 1.0 + (altitudeChange / (CGFloat.pi / 8))

        // Apply scale factor with bounds
        let newScale = max(0.25, min(4.0, pencilScale * scaleFactor))

        // Check if scale changed significantly (for haptic feedback)
        let previousThreshold = Int(pencilScale * 10)
        let newThreshold = Int(newScale * 10)
        let changed = previousThreshold != newThreshold

        // Update stored values
        pencilScale = newScale
        baselineAltitudeAngle = altitude  // Reset baseline for incremental changes

        return (newScale, changed)
    }

    // Check if rotation crossed a 10-degree threshold and trigger haptic
    private func checkRotationHaptic(degrees: CGFloat, at location: CGPoint) {
        let currentThreshold = Int(degrees / 10)
        if currentThreshold != lastHapticThreshold {
            lastHapticThreshold = currentThreshold
            // Trigger Apple Pencil Pro haptic feedback for alignment/snap
            canvasFeedbackGenerator.alignmentOccurred(at: location)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        let touchCount = event?.allTouches?.count ?? touches.count

        // If two or more fingers, enter two-finger mode (gestures will handle it)
        if touchCount >= 2 {
            isTwoFingerMode = true
            hasPlacedInCurrentInteraction = false
            // Update lastGestureLocation with center of touches
            if let allTouches = event?.allTouches, allTouches.count >= 2 {
                let touchArray = Array(allTouches)
                let loc1 = touchArray[0].location(in: self)
                let loc2 = touchArray[1].location(in: self)
                lastGestureLocation = CGPoint(
                    x: (loc1.x + loc2.x) / 2,
                    y: (loc1.y + loc2.y) / 2
                )
                onHoverUpdate?(lastGestureLocation, nil)
            }
            return
        }

        guard let touch = touches.first else { return }

        impactGenerator.prepare()

        let location = touch.location(in: self)
        lastGestureLocation = location
        let rollAngle = relativeRollAngle(from: touch)

        // Initialize scale from altitude angle (captures baseline)
        let (scale, _) = updateScaleFromAltitude(touch)
        onScaleUpdate?(scale)

        onHoverUpdate?(location, rollAngle)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        // Don't process single-touch moves if in two-finger mode
        if isTwoFingerMode { return }

        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        lastGestureLocation = location
        let rollAngle = relativeRollAngle(from: touch)

        // Update scale from altitude angle (tilt)
        let (scale, scaleChanged) = updateScaleFromAltitude(touch)
        if scaleChanged {
            impactGenerator.impactOccurred(intensity: 0.5)
        }
        onScaleUpdate?(scale)

        // Trigger haptic every 10 degrees of rotation
        let degrees = rollAngle * 180 / .pi
        checkRotationHaptic(degrees: degrees, at: location)

        onHoverUpdate?(location, rollAngle)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        // Count remaining active touches (not ended or cancelled)
        let remainingTouches = event?.allTouches?.filter {
            $0.phase == .began || $0.phase == .moved || $0.phase == .stationary
        }.count ?? 0

        // If in two-finger mode, handle placement when all fingers are lifted
        if isTwoFingerMode {
            // Only place when all fingers are up and we haven't already placed
            if remainingTouches == 0 && !hasPlacedInCurrentInteraction {
                hasPlacedInCurrentInteraction = true
                onTap?(lastGestureLocation)
            }

            // Reset state when all fingers are lifted
            if remainingTouches == 0 {
                isTwoFingerMode = false
                pinchGestureActive = false
                rotationGestureActive = false
                hasPlacedInCurrentInteraction = false
            }
            return
        }

        // Single finger release - place the shape
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastGestureLocation = location

        // Update preview position to match placement location
        onHoverUpdate?(location, nil)

        onTap?(location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isTwoFingerMode = false
        pinchGestureActive = false
        rotationGestureActive = false
        hasPlacedInCurrentInteraction = false
    }
}
#elseif canImport(AppKit)
import AppKit

class HoverDetectionView: NSView {
    var onHoverUpdate: ((CGPoint, CGFloat?) -> Void)?
    var onHoverEnd: (() -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onScaleUpdate: ((CGFloat) -> Void)?
    var onRotationUpdate: ((CGFloat) -> Void)?

    // macOS does not have Pencil roll; keep API surface but unused
    private(set) var baselineRollAngle: CGFloat?

    // Tracking area for mouse hover
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }

    override var acceptsFirstResponder: Bool { true }

    func resetBaseline() {
        baselineRollAngle = nil
    }

    private func setupTracking() {
        updateTrackingAreas()
        // Enable mouse moved events
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    // Hover/move
    override func mouseEntered(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onHoverUpdate?(location, nil)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onHoverUpdate?(location, nil)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverEnd?()
    }

    // Click/tap
    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onTap?(location)
    }

    // macOS trackpad magnification (pinch) gesture
    override func magnify(with event: NSEvent) {
        let newScale = 1.0 + event.magnification
        onScaleUpdate?(newScale)
    }

    // macOS trackpad rotation gesture
    override func rotate(with event: NSEvent) {
        // Convert degrees to radians
        let radians = CGFloat(event.rotation) * .pi / 180
        onRotationUpdate?(radians)
    }
}

#endif

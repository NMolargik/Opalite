#if canImport(UIKit)
import UIKit

class HoverDetectionView: UIView {
    var onHoverUpdate: ((CGPoint, CGFloat?) -> Void)?
    var onHoverEnd: (() -> Void)?
    var onTap: ((CGPoint) -> Void)?

    // Baseline roll angle captured on first touch - rotation is relative to this
    private(set) var baselineRollAngle: CGFloat?

    // Haptic feedback for Apple Pencil Pro rotation (iOS only)
    private lazy var canvasFeedbackGenerator: UICanvasFeedbackGenerator = {
        UICanvasFeedbackGenerator(view: self)
    }()

    // Track the last 10-degree threshold crossed for haptic feedback
    private var lastHapticThreshold: Int = 0

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
        lastHapticThreshold = 0
    }

    private func setupGestures() {
        // Hover gesture for Apple Pencil / Pointer
        let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hoverGesture)

        // Tap gesture for placement
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: self)
            // Hover only provides location - roll angle comes from touch events
            onHoverUpdate?(location, nil)
        case .ended, .cancelled:
            onHoverEnd?()
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        onTap?(location)
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
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let rollAngle = relativeRollAngle(from: touch)
        onHoverUpdate?(location, rollAngle)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        let rollAngle = relativeRollAngle(from: touch)

        // Trigger haptic every 10 degrees of rotation
        let degrees = rollAngle * 180 / .pi
        checkRotationHaptic(degrees: degrees, at: location)

        onHoverUpdate?(location, rollAngle)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        onTap?(location)
    }
}
#elseif canImport(AppKit)
import AppKit

class HoverDetectionView: NSView {
    var onHoverUpdate: ((CGPoint, CGFloat?) -> Void)?
    var onHoverEnd: (() -> Void)?
    var onTap: ((CGPoint) -> Void)?

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
}

#endif


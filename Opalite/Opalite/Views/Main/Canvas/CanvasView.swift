//
//  CanvasView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftUI
import SwiftData
import PencilKit

// MARK: - Canvas Shape Types
enum CanvasShape: String, CaseIterable {
    case square
    case circle
    case triangle
    case line
    case arrow
    case star

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .square: return "square"
        case .circle: return "circle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .star: return "star"
        }
    }
}

struct CanvasView: View {
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(\.dismiss) private var dismiss

    let canvasFile: CanvasFile

    @State private var drawing: PKDrawing = PKDrawing()
    @State private var selectedInkColor: UIColor = .label
    @State private var forceColorUpdate: UUID = UUID()
    @State private var appearTrigger: UUID = UUID()
    @State private var pendingShape: CanvasShape? = nil
    @State private var shapePreviewLocation: CGPoint? = nil
    @State private var shapeRotation: Angle = .zero
    @State private var isEditingTitle: Bool = false
    @State private var editedTitle: String = ""
    @FocusState private var isTitleFieldFocused: Bool
    @State private var showClearConfirmation: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    // MARK: - Image Placement State
    @State private var pendingImage: UIImage? = nil
    @State private var imagePreviewLocation: CGPoint? = nil
    @State private var imageRotation: Angle = .zero

    // MARK: - Image Picker Sheet State
    @State private var showPhotosPicker: Bool = false
    @State private var showFilesPicker: Bool = false

    // MARK: - Background Image (flattened placed images)
    @State private var backgroundImage: UIImage? = nil

    var body: some View {
        ZStack {
            // Background layer
            Color.white
                .ignoresSafeArea()

            // Drawing canvas with Apple Pencil support
            PencilKitCanvas(
                drawing: $drawing,
                inkColor: $selectedInkColor,
                forceColorUpdate: forceColorUpdate,
                appearTrigger: appearTrigger,
                backgroundImage: backgroundImage
            )

            // Shape placement overlay
            if let shape = pendingShape {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()

                    // Shape preview at hover location
                    if let location = shapePreviewLocation {
                        ShapePreviewView(shape: shape)
                            .rotationEffect(shapeRotation)
                            .position(location)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 8) {
                        Text("Tap to place \(shape.displayName)")
                            .font(.headline)
                        if shapeRotation != .zero {
                            Text("Rotation: \(Int(shapeRotation.degrees))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 80)
                }
                .overlay {
                    PencilHoverView(
                        hoverLocation: $shapePreviewLocation,
                        rollAngle: $shapeRotation,
                        onTap: { location in
                            placeShape(shape, at: location, rotation: shapeRotation)
                            pendingShape = nil
                            shapePreviewLocation = nil
                            shapeRotation = .zero
                        }
                    )
                }
            }

            // Image placement overlay
            if let image = pendingImage {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()

                    // Image preview at hover location
                    if let location = imagePreviewLocation {
                        ImagePreviewView(image: image)
                            .rotationEffect(imageRotation)
                            .position(location)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 8) {
                        Text("Tap to place image")
                            .font(.headline)
                        if imageRotation != .zero {
                            Text("Rotation: \(Int(imageRotation.degrees))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 80)
                }
                .overlay {
                    PencilHoverView(
                        hoverLocation: $imagePreviewLocation,
                        rollAngle: $imageRotation,
                        onTap: { location in
                            placeImage(image, at: location, rotation: imageRotation)
                            pendingImage = nil
                            imagePreviewLocation = nil
                            imageRotation = .zero
                        }
                    )
                }
            }
        }
        .environment(\.colorScheme, .light)
        .id(canvasFile.id)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            drawing = canvasManager.loadDrawing(from: canvasFile)
            backgroundImage = canvasManager.loadBackgroundImage(from: canvasFile)
            appearTrigger = UUID()
        }
        .onChange(of: canvasFile.id) { _, _ in
            drawing = canvasManager.loadDrawing(from: canvasFile)
            backgroundImage = canvasManager.loadBackgroundImage(from: canvasFile)
        }
        .onChange(of: drawing) { _, newValue in
            // TODO: debounce?
            do {
                try canvasManager.saveDrawing(newValue, to: canvasFile)
            } catch {
                // TODO: error handling
            }
        }
        .overlay(alignment: .top) {
            CanvasSwatchPickerView { color in
                selectedInkColor = color.uiColor
                forceColorUpdate = UUID()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditingTitle {
                    HStack(spacing: 8) {
                        TextField("Canvas Title", text: $editedTitle)
                            .textFieldStyle(.plain)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .submitLabel(.done)
                            .focused($isTitleFieldFocused)
                            .onSubmit {
                                saveTitle()
                            }

                        Button {
                            saveTitle()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(maxWidth: 200)
                } else {
                    Button {
                        editedTitle = canvasFile.title
                        isEditingTitle = true
                        DispatchQueue.main.async {
                            isTitleFieldFocused = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(canvasFile.title)
                                .font(.headline)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Import") {
                        Button {
                            showPhotosPicker = true
                        } label: {
                            Label("Image from Photos", systemImage: "photo.on.rectangle")
                        }

                        Button {
                            showFilesPicker = true
                        } label: {
                            Label("Image from Files", systemImage: "folder")
                        }
                    }

                    Section("Shapes") {
                        ForEach(CanvasShape.allCases, id: \.self) { shape in
                            Button {
                                pendingShape = shape
                            } label: {
                                Label(shape.displayName, systemImage: shape.systemImage)
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Canvas", systemImage: "eraser")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Canvas", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        .alert("Clear Canvas?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                drawing = PKDrawing()
            }
        } message: {
            Text("This will remove all content from the canvas. This action cannot be undone.")
        }
        .alert("Delete Canvas?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
                do {
                    try canvasManager.deleteCanvas(canvasFile)
                } catch {
                    // TODO: error handling
                }
            }
        } message: {
            Text("This will permanently delete \"\(canvasFile.title)\". This action cannot be undone.")
        }
        .sheet(isPresented: $showPhotosPicker) {
            PhotoPickerView(selectedImage: Binding(
                get: { nil },
                set: { image in
                    if let image {
                        pendingImage = image
                    }
                }
            ))
        }
        .sheet(isPresented: $showFilesPicker) {
            FilePickerView(selectedImage: Binding(
                get: { nil },
                set: { image in
                    if let image {
                        pendingImage = image
                    }
                }
            ))
        }
    }

    // MARK: - Title Editing
    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isTitleFieldFocused = false
            isEditingTitle = false
            return
        }

        do {
            try canvasManager.updateCanvas(canvasFile) { canvas in
                canvas.title = trimmed
            }
        } catch {
            // TODO: error handling
        }
        isTitleFieldFocused = false
        isEditingTitle = false
    }

    // MARK: - Shape Placement
    private func placeShape(_ shape: CanvasShape, at center: CGPoint, rotation: Angle = .zero) {
        let shapeSize: CGFloat = 100
        let ink = PKInk(.pen, color: .black)
        var newStrokes: [PKStroke] = []

        // For shapes that need multiple strokes (like arrow), we handle them separately
        switch shape {
        case .star:
            newStrokes = createStarStrokes(center: center, size: shapeSize, ink: ink, rotation: rotation)
        case .arrow:
            newStrokes = createArrowStrokes(center: center, size: shapeSize, ink: ink, rotation: rotation)
        default:
            let strokePoints = generateShapePoints(for: shape, center: center, size: shapeSize, rotation: rotation)
            if let stroke = createStroke(from: strokePoints, ink: ink) {
                newStrokes.append(stroke)
            }
        }

        guard !newStrokes.isEmpty else { return }

        // Add strokes to existing drawing
        var updatedDrawing = drawing
        for stroke in newStrokes {
            updatedDrawing.strokes.append(stroke)
        }
        drawing = updatedDrawing
    }

    private func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: Angle) -> CGPoint {
        let radians = CGFloat(angle.radians)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosAngle = CoreGraphics.cos(radians)
        let sinAngle = CoreGraphics.sin(radians)
        let rotatedX = dx * cosAngle - dy * sinAngle
        let rotatedY = dx * sinAngle + dy * cosAngle
        return CGPoint(x: center.x + rotatedX, y: center.y + rotatedY)
    }

    private func generateShapePoints(for shape: CanvasShape, center: CGPoint, size: CGFloat, rotation: Angle = .zero) -> [CGPoint] {
        let halfSize = size / 2

        var points: [CGPoint]

        switch shape {
        case .square:
            let topLeft = CGPoint(x: center.x - halfSize, y: center.y - halfSize)
            let topRight = CGPoint(x: center.x + halfSize, y: center.y - halfSize)
            let bottomRight = CGPoint(x: center.x + halfSize, y: center.y + halfSize)
            let bottomLeft = CGPoint(x: center.x - halfSize, y: center.y + halfSize)
            // Triple duplicate corner points for truly sharp edges
            points = [
                topLeft, topLeft, topLeft,
                topRight, topRight, topRight,
                bottomRight, bottomRight, bottomRight,
                bottomLeft, bottomLeft, bottomLeft,
                topLeft, topLeft, topLeft
            ]

        case .circle:
            points = []
            let segments = 36
            for i in 0...segments {
                let angle = (CGFloat(i) / CGFloat(segments)) * 2 * .pi
                let x = center.x + cos(angle) * halfSize
                let y = center.y + sin(angle) * halfSize
                points.append(CGPoint(x: x, y: y))
            }

        case .triangle:
            let height = size * 0.866 // Equilateral triangle height
            let top = CGPoint(x: center.x, y: center.y - height / 2)
            let bottomRight = CGPoint(x: center.x + halfSize, y: center.y + height / 2)
            let bottomLeft = CGPoint(x: center.x - halfSize, y: center.y + height / 2)
            // Triple duplicate corner points for truly sharp edges
            points = [
                top, top, top,
                bottomRight, bottomRight, bottomRight,
                bottomLeft, bottomLeft, bottomLeft,
                top, top, top
            ]

        case .line:
            points = [
                CGPoint(x: center.x - halfSize, y: center.y),
                CGPoint(x: center.x + halfSize, y: center.y)
            ]

        case .arrow, .star:
            // Handled separately with multiple strokes
            return []
        }

        // Apply rotation if needed
        if rotation != .zero {
            points = points.map { rotatePoint($0, around: center, by: rotation) }
        }

        return points
    }

    private func createStroke(from points: [CGPoint], ink: PKInk) -> PKStroke? {
        guard points.count >= 2 else { return nil }

        var strokePoints: [PKStrokePoint] = []
        for (index, point) in points.enumerated() {
            let timeOffset = TimeInterval(index) * 0.01
            let strokePoint = PKStrokePoint(
                location: point,
                timeOffset: timeOffset,
                size: CGSize(width: 3, height: 3),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
            strokePoints.append(strokePoint)
        }

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    private func createArrowStrokes(center: CGPoint, size: CGFloat, ink: PKInk, rotation: Angle = .zero) -> [PKStroke] {
        let halfSize = size / 2
        let arrowHeadSize = size * 0.25

        var strokes: [PKStroke] = []

        // Main line
        var linePoints = [
            CGPoint(x: center.x - halfSize, y: center.y),
            CGPoint(x: center.x + halfSize, y: center.y)
        ]
        if rotation != .zero {
            linePoints = linePoints.map { rotatePoint($0, around: center, by: rotation) }
        }
        if let lineStroke = createStroke(from: linePoints, ink: ink) {
            strokes.append(lineStroke)
        }

        // Arrow head top
        var headTop = [
            CGPoint(x: center.x + halfSize, y: center.y),
            CGPoint(x: center.x + halfSize - arrowHeadSize, y: center.y - arrowHeadSize)
        ]
        if rotation != .zero {
            headTop = headTop.map { rotatePoint($0, around: center, by: rotation) }
        }
        if let topStroke = createStroke(from: headTop, ink: ink) {
            strokes.append(topStroke)
        }

        // Arrow head bottom
        var headBottom = [
            CGPoint(x: center.x + halfSize, y: center.y),
            CGPoint(x: center.x + halfSize - arrowHeadSize, y: center.y + arrowHeadSize)
        ]
        if rotation != .zero {
            headBottom = headBottom.map { rotatePoint($0, around: center, by: rotation) }
        }
        if let bottomStroke = createStroke(from: headBottom, ink: ink) {
            strokes.append(bottomStroke)
        }

        return strokes
    }

    private func createStarStrokes(center: CGPoint, size: CGFloat, ink: PKInk, rotation: Angle = .zero) -> [PKStroke] {
        let outerRadius = size / 2
        let innerRadius = size / 4
        let pointCount = 5

        var starPoints: [CGPoint] = []
        for i in 0..<(pointCount * 2 + 1) {
            let angle = (CGFloat(i) * .pi / CGFloat(pointCount)) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            var point = CGPoint(x: x, y: y)
            // Apply rotation if needed
            if rotation != .zero {
                point = rotatePoint(point, around: center, by: rotation)
            }
            // Triple duplicate each point for truly sharp edges
            starPoints.append(point)
            starPoints.append(point)
            starPoints.append(point)
        }

        if let stroke = createStroke(from: starPoints, ink: ink) {
            return [stroke]
        }
        return []
    }

    // MARK: - Image Placement

    private func placeImage(_ image: UIImage, at center: CGPoint, rotation: Angle) {
        // Get the canvas size (use screen bounds as approximation)
        let canvasSize = UIScreen.main.bounds.size

        // Calculate the image size (max 200pt dimension, preserving aspect ratio)
        let maxDimension: CGFloat = 200
        let aspectRatio = image.size.width / image.size.height
        let imageSize: CGSize
        if aspectRatio > 1 {
            imageSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            imageSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Flatten the image to the background
        flattenToBackground(image: image, at: center, rotation: rotation, size: imageSize, canvasSize: canvasSize)
    }

    private func flattenToBackground(image: UIImage, at center: CGPoint, rotation: Angle, size: CGSize, canvasSize: CGSize) {
        // Create a new image context
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))

        // Draw existing background image if any
        if let existingBackground = backgroundImage {
            existingBackground.draw(at: .zero)
        }

        // Save state before transformations
        context.saveGState()

        // Move to center point and apply rotation
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(rotation.radians))

        // Draw the new image centered at the origin (which is now at center point)
        let drawRect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: drawRect)

        // Restore state
        context.restoreGState()

        // Get the composited image
        guard let compositeImage = UIGraphicsGetImageFromCurrentImageContext() else { return }

        // Update the background image state
        backgroundImage = compositeImage

        // Save to the canvas file
        do {
            try canvasManager.saveBackgroundImage(compositeImage, to: canvasFile)
        } catch {
            // TODO: error handling
        }
    }
}

// MARK: - Shape Preview View
struct ShapePreviewView: View {
    let shape: CanvasShape
    private let size: CGFloat = 100

    var body: some View {
        Group {
            switch shape {
            case .square:
                Rectangle()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size)

            case .circle:
                Circle()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size)

            case .triangle:
                TriangleShape()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size * 0.866)

            case .line:
                Rectangle()
                    .fill(.black)
                    .frame(width: size, height: 2)

            case .arrow:
                ArrowShape()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size * 0.5)

            case .star:
                StarShape()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
        .opacity(0.6)
    }
}

// MARK: - Custom Shape Paths for Preview
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let arrowHeadSize = rect.width * 0.25

        // Main line
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))

        // Arrow head
        path.move(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: midY - arrowHeadSize))
        path.move(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: midY + arrowHeadSize))

        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius / 2
        let pointCount = 5

        var path = Path()
        for i in 0..<(pointCount * 2) {
            let angle = (CGFloat(i) * .pi / CGFloat(pointCount)) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Pencil Hover Detection
struct PencilHoverView: UIViewRepresentable {
    @Binding var hoverLocation: CGPoint?
    @Binding var rollAngle: Angle
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> HoverDetectionView {
        let view = HoverDetectionView()
        view.backgroundColor = .clear
        view.onHoverUpdate = { location, relativeAngle in
            DispatchQueue.main.async {
                self.hoverLocation = location
                if let angle = relativeAngle {
                    self.rollAngle = Angle(radians: Double(angle))
                }
            }
        }
        view.onHoverEnd = {
            DispatchQueue.main.async {
                self.hoverLocation = nil
            }
        }
        view.onTap = { location in
            self.onTap(location)
        }
        return view
    }

    func updateUIView(_ uiView: HoverDetectionView, context: Context) {
        // Reset baseline when rollAngle is reset to zero (new placement session)
        if rollAngle == .zero && uiView.baselineRollAngle != nil {
            uiView.resetBaseline()
        }
    }
}

class HoverDetectionView: UIView {
    var onHoverUpdate: ((CGPoint, CGFloat?) -> Void)?
    var onHoverEnd: (() -> Void)?
    var onTap: ((CGPoint) -> Void)?

    // Baseline roll angle captured on first touch - rotation is relative to this
    private(set) var baselineRollAngle: CGFloat?

    // Haptic feedback for Apple Pencil Pro rotation
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
        // Hover gesture for Apple Pencil
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
            // During hover, we don't update rotation (API limitation: rollAngle requires touch)
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

struct PencilKitCanvas: View {
    @Binding var drawing: PKDrawing
    @Binding var inkColor: UIColor
    var forceColorUpdate: UUID
    var appearTrigger: UUID
    var backgroundImage: UIImage?

    var body: some View {
        CanvasDetail_PencilKitRepresentable(
            drawing: $drawing,
            inkColor: $inkColor,
            forceColorUpdate: forceColorUpdate,
            appearTrigger: appearTrigger,
            backgroundImage: backgroundImage
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

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.backgroundColor = .clear
        view.isOpaque = false
        view.alwaysBounceVertical = true
        view.drawingPolicy = .default
        view.delegate = context.coordinator

        // Add background image view
        let imageView = UIImageView()
        imageView.contentMode = .topLeft
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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

        // Update background image if changed
        if context.coordinator.backgroundImageView?.image !== backgroundImage {
            context.coordinator.backgroundImageView?.image = backgroundImage
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
                // Also update the tool picker's selected tool to reflect the color visually
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
            guard let window = canvasView.window else {
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

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        CanvasFile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    let canvasManager = CanvasManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
        try canvasManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return CanvasView(canvasFile: CanvasFile())
        .modelContainer(container)
        .environment(colorManager)
        .environment(canvasManager)
}


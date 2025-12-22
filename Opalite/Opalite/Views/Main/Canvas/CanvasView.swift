//
//  CanvasView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftUI
import SwiftData
import PencilKit

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
    @State private var editedTitle: String = ""
    @State private var showRenameTitleAlert: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    // MARK: - Image Placement State
    @State private var pendingImage: UIImage? = nil
    @State private var imagePreviewLocation: CGPoint? = nil
    @State private var imageRotation: Angle = .zero

    // MARK: - Image Picker Sheet State
    @State private var showPhotosPicker: Bool = false
    @State private var showFilesPicker: Bool = false

    // MARK: - Color Sampling State
    @State private var isColorSampling: Bool = false
    @State private var sampledColor: UIColor? = nil
    @State private var samplingLocation: CGPoint? = nil

    // MARK: - Background Image (flattened placed images)
    @State private var backgroundImage: UIImage? = nil

    // MARK: - Canvas Size
    @State private var effectiveCanvasSize: CGSize? = nil

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
                backgroundImage: backgroundImage,
                canvasSize: effectiveCanvasSize
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

            // Color sampling overlay
            if isColorSampling {
                colorSamplingOverlay
            }
        }
        .environment(\.colorScheme, .light)
        .id(canvasFile.id)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            drawing = canvasManager.loadDrawing(from: canvasFile)
            backgroundImage = canvasManager.loadBackgroundImage(from: canvasFile)
            initializeCanvasSize()
            appearTrigger = UUID()
        }
        .onChange(of: canvasFile.id) { _, _ in
            drawing = canvasManager.loadDrawing(from: canvasFile)
            backgroundImage = canvasManager.loadBackgroundImage(from: canvasFile)
            initializeCanvasSize()
        }
        .onChange(of: drawing) { _, newValue in
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
            ToolbarItem(placement: .principal) {
                Text(canvasFile.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editedTitle = canvasFile.title
                    showRenameTitleAlert = true
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isColorSampling = true
                } label: {
                    Label("Sample Color", systemImage: "eyedropper")
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
                        Button {
                            flattenCanvas()
                        } label: {
                            Label("Flatten Canvas", systemImage: "square.on.square.squareshape.controlhandles")
                        }
                        .disabled(drawing.strokes.isEmpty)

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
        .onChange(of: colorManager.selectedCanvasColor) { _, newColor in
            // Apply color from SwatchBar window to current drawing tool
            if let color = newColor {
                selectedInkColor = color.uiColor
                forceColorUpdate = UUID()
                // Clear the selection so it can be set again
                colorManager.selectedCanvasColor = nil
            }
        }
        .alert("Rename Canvas", isPresented: $showRenameTitleAlert) {
            TextField("Canvas Title", text: $editedTitle)

            Button("Cancel", role: .cancel) {
                editedTitle = ""
            }

            Button("Save") {
                saveTitle()
            }
        } message: {
            Text("Enter a new title for this canvas.")
        }
    }

    // MARK: - Title Editing
    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showRenameTitleAlert = false
            return
        }

        do {
            try canvasManager.updateCanvas(canvasFile) { canvas in
                canvas.title = trimmed
            }
        } catch {
            // TODO: error handling
        }
        showRenameTitleAlert = false
    }

    // MARK: - Canvas Size Management
    private func initializeCanvasSize() {
        // Use stored canvas size if available, otherwise use current screen size
        if let storedSize = canvasFile.canvasSize {
            effectiveCanvasSize = storedSize
        } else {
            // First time opening - set the canvas size to current screen
            let screenSize = UIScreen.main.bounds.size
            canvasFile.setCanvasSize(screenSize)
            effectiveCanvasSize = screenSize
            do {
                try canvasManager.saveContext()
            } catch {
                // Ignore save errors for canvas size
            }
        }
    }

    private func getEffectiveCanvasSize() -> CGSize {
        effectiveCanvasSize ?? UIScreen.main.bounds.size
    }

    /// Flattens current strokes into the background image, making them permanent and scalable.
    private func flattenCanvas() {
        guard !drawing.strokes.isEmpty else { return }

        let canvasSize = getEffectiveCanvasSize()
        let scale: CGFloat = 2.0

        UIGraphicsBeginImageContextWithOptions(canvasSize, true, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))

        // Draw existing background if any
        if let existingBackground = backgroundImage {
            existingBackground.draw(in: CGRect(origin: .zero, size: canvasSize))
        }

        // Draw current strokes
        let drawingImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
        drawingImage.draw(at: .zero)

        guard let compositeImage = UIGraphicsGetImageFromCurrentImageContext() else { return }

        // Clear strokes and update background
        drawing = PKDrawing()
        backgroundImage = compositeImage

        do {
            try canvasManager.saveBackgroundImage(compositeImage, to: canvasFile)
            try canvasManager.saveDrawing(drawing, to: canvasFile)
        } catch {
            // TODO: error handling
        }
    }

    // MARK: - Color Sampling

    @ViewBuilder
    private var colorSamplingOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                // Crosshair and color preview at sampling location
                if let location = samplingLocation, let color = sampledColor {
                    VStack(spacing: 0) {
                        // Color preview circle
                        Circle()
                            .fill(Color(uiColor: color))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(radius: 4)

                        // Crosshair line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 20)
                    }
                    .position(x: location.x, y: location.y - 50)
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    Text("Tap to sample a color")
                        .font(.headline)

                    if sampledColor != nil {
                        Text("Tap again to save, or drag to adjust")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Cancel") {
                        isColorSampling = false
                        sampledColor = nil
                        samplingLocation = nil
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 80)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        samplingLocation = value.location
                        sampledColor = sampleColor(at: value.location, in: geometry.size)
                    }
                    .onEnded { value in
                        if let color = sampledColor {
                            saveColorToPortfolio(color)
                        }
                        isColorSampling = false
                        sampledColor = nil
                        samplingLocation = nil
                    }
            )
        }
    }

    private func sampleColor(at point: CGPoint, in viewSize: CGSize) -> UIColor? {
        // First, try to sample from the background image
        if let bgImage = backgroundImage {
            // Convert point to image coordinates
            let imageSize = bgImage.size
            let scaleX = imageSize.width / viewSize.width
            let scaleY = imageSize.height / viewSize.height
            let imagePoint = CGPoint(x: point.x * scaleX, y: point.y * scaleY)

            if let color = bgImage.pixelColor(at: imagePoint) {
                return color
            }
        }

        // If no background or point is outside, sample from the drawing
        // Create a snapshot of the current canvas state
        let canvasSize = getEffectiveCanvasSize()
        UIGraphicsBeginImageContextWithOptions(canvasSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return .white }

        // Draw white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))

        // Draw background image if present
        if let bgImage = backgroundImage {
            bgImage.draw(in: CGRect(origin: .zero, size: canvasSize))
        }

        // Draw the PKDrawing
        let drawingImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1.0)
        drawingImage.draw(at: .zero)

        guard let snapshot = UIGraphicsGetImageFromCurrentImageContext() else { return .white }

        // Convert view point to snapshot coordinates
        let scaleX = canvasSize.width / viewSize.width
        let scaleY = canvasSize.height / viewSize.height
        let snapshotPoint = CGPoint(x: point.x * scaleX, y: point.y * scaleY)

        return snapshot.pixelColor(at: snapshotPoint) ?? .white
    }

    private func saveColorToPortfolio(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        do {
            _ = try colorManager.createColor(
                name: nil,
                notes: "Sampled from \(canvasFile.title)",
                device: nil,
                red: Double(r),
                green: Double(g),
                blue: Double(b),
                alpha: Double(a)
            )
        } catch {
            // TODO: error handling
        }
    }

    // MARK: - Shape Placement
    private func placeShape(_ shape: CanvasShape, at center: CGPoint, rotation: Angle = .zero) {
        let shapeSize: CGFloat = 100
        let ink = PKInk(.pen, color: .black)
        var newStrokes: [PKStroke] = []

        // For shapes that need multiple strokes (like arrow), we handle them separately
        switch shape {
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

        case .arrow:
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
        // Use the stored canvas size
        let canvasSize = getEffectiveCanvasSize()

        // Calculate the image size (max 200pt dimension, preserving aspect ratio)
        let maxDimension: CGFloat = 200
        let aspectRatio = image.size.width / image.size.height
        let imageSize: CGSize
        if aspectRatio > 1 {
            imageSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            imageSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Flatten everything into the drawing
        flattenImageIntoDrawing(image: image, at: center, rotation: rotation, size: imageSize, canvasSize: canvasSize)
    }

    /// Flattens the placed image along with existing strokes into a new composite drawing.
    /// This ensures images scale properly with the canvas.
    private func flattenImageIntoDrawing(image: UIImage, at center: CGPoint, rotation: Angle, size: CGSize, canvasSize: CGSize) {
        // Use a consistent scale for quality
        let scale: CGFloat = 2.0

        // Create a composite image of everything
        UIGraphicsBeginImageContextWithOptions(canvasSize, true, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))

        // Draw existing flattened content if any
        if let existingBackground = backgroundImage {
            existingBackground.draw(in: CGRect(origin: .zero, size: canvasSize))
        }

        // Draw existing PKDrawing strokes
        let drawingImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
        drawingImage.draw(at: .zero)

        // Save state before transformations for the new image
        context.saveGState()

        // Move to center point and apply rotation
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(rotation.radians))

        // Draw the new image centered at the origin
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

        // Clear the PKDrawing strokes (they're now in the composite)
        drawing = PKDrawing()

        // Update the background image state
        backgroundImage = compositeImage

        // Save both the cleared drawing and new background
        do {
            try canvasManager.saveBackgroundImage(compositeImage, to: canvasFile)
            try canvasManager.saveDrawing(drawing, to: canvasFile)
        } catch {
            // TODO: error handling
        }
    }
}

// MARK: - UIImage Color Sampling Extension

private extension UIImage {
    func pixelColor(at point: CGPoint) -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Ensure point is within bounds
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        // Create a 1x1 pixel context to read the color
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData: [UInt8] = [0, 0, 0, 0]

        guard let context = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the single pixel
        context.draw(cgImage, in: CGRect(x: -CGFloat(x), y: -CGFloat(y), width: CGFloat(width), height: CGFloat(height)))

        // Extract color components
        let red = CGFloat(pixelData[0]) / 255.0
        let green = CGFloat(pixelData[1]) / 255.0
        let blue = CGFloat(pixelData[2]) / 255.0
        let alpha = CGFloat(pixelData[3]) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
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

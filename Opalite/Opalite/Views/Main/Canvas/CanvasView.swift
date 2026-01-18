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
    @Environment(ToastManager.self) private var toastManager

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
    @State private var showToolPickerTrigger: UUID = UUID()
    @State private var externalTool: PKTool? = nil

    // Color sampling state
    @State private var isColorSamplingMode: Bool = false
    @State private var colorSampleLocation: CGPoint? = nil
    @State private var sampledColor: OpaliteColor? = nil

    // Mac Catalyst custom tool picker state
    #if targetEnvironment(macCatalyst)
    @State private var selectedTool: PKTool = PKInkingTool(.pen, color: .label, width: 4)
    @State private var strokeWidth: CGFloat = 4
    #endif

    // MARK: - Canvas Size & Scroll State
    @State private var effectiveCanvasSize: CGSize? = nil
    @State private var canvasContentOffset: CGPoint = .zero
    @State private var canvasZoomScale: CGFloat = 1.0

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
                canvasSize: effectiveCanvasSize,
                contentOffset: $canvasContentOffset,
                zoomScale: $canvasZoomScale,
                showToolPickerTrigger: showToolPickerTrigger,
                externalTool: $externalTool
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

            // Color sampling overlay
            if isColorSamplingMode {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()

                    // Color preview at hover location
                    if let location = colorSampleLocation, let color = sampledColor {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                            Text(color.hexString)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .position(x: location.x, y: location.y - 60)
                        .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 8) {
                        Text("Tap to sample color")
                            .font(.headline)
                        Text("Touch and drag to preview colors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 80)
                }
                .overlay {
                    colorSamplingGestureOverlay
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 16) {
                        Button {
                            HapticsManager.shared.selection()
                            isColorSamplingMode = false
                            colorSampleLocation = nil
                            sampledColor = nil
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.red, in: RoundedRectangle(cornerRadius: 12))
                        }

                        if let color = sampledColor {
                            Button {
                                HapticsManager.shared.impact()
                                saveColorFromSample(color)
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(color.swiftUIColor)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                                        )
                                    Text("Save Color")
                                        .font(.headline)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 100)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .id(canvasFile.id)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            drawing = canvasManager.loadDrawing(from: canvasFile)
            initializeCanvasSize()
            appearTrigger = UUID()
        }
        .onChange(of: canvasFile.id) { _, _ in
            drawing = canvasManager.loadDrawing(from: canvasFile)
            initializeCanvasSize()
        }
        .onChange(of: drawing) { _, newValue in
            do {
                try canvasManager.saveDrawing(newValue, to: canvasFile)
            } catch {
                toastManager.show(error: .canvasSaveFailed)
            }
        }
        .overlay(alignment: .top) {
            CanvasSwatchPickerView { color in
                selectedInkColor = color.uiColor
                forceColorUpdate = UUID()
                #if targetEnvironment(macCatalyst)
                // Update the selected tool color, switching from eraser to pen if needed
                if let inkTool = selectedTool as? PKInkingTool {
                    selectedTool = PKInkingTool(inkTool.inkType, color: color.uiColor, width: inkTool.width)
                } else {
                    // Currently on eraser or other non-inking tool, switch to pen
                    selectedTool = PKInkingTool(.pen, color: color.uiColor, width: strokeWidth)
                    externalTool = selectedTool
                }
                #endif
            }
        }
        #if targetEnvironment(macCatalyst)
        .overlay(alignment: .bottom) {
            MacCatalystToolPicker(
                selectedTool: Binding(
                    get: { selectedTool },
                    set: { newTool in
                        selectedTool = newTool
                        externalTool = newTool
                    }
                ),
                selectedColor: $selectedInkColor,
                strokeWidth: $strokeWidth
            )
            .padding(.bottom, 20)
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticsManager.shared.impact()
                    editedTitle = canvasFile.title
                    showRenameTitleAlert = true
                } label: {
                    Text(canvasFile.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(width: 180)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.impact()
                    editedTitle = canvasFile.title
                    showRenameTitleAlert = true
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
                .toolbarButtonTint()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Shapes") {
                        ForEach(CanvasShape.allCases, id: \.self) { shape in
                            Button {
                                HapticsManager.shared.impact()
                                pendingShape = shape
                            } label: {
                                Label(shape.displayName, systemImage: shape.systemImage)
                            }
                        }
                    }

                    Section("Tools") {
                        Button {
                            HapticsManager.shared.impact()
                            isColorSamplingMode = true
                        } label: {
                            Label("Sample Color From Canvas", systemImage: "eyedropper")
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            HapticsManager.shared.impact()
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Canvas", systemImage: "eraser")
                        }

                        Button(role: .destructive) {
                            HapticsManager.shared.impact()
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Canvas", systemImage: "trash.fill")
                        }
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
                .toolbarButtonTint()
            }

            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
        }
        .alert("Clear Canvas?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.impact()
            }
            Button("Clear", role: .destructive) {
                HapticsManager.shared.impact()
                drawing = PKDrawing()
            }
        } message: {
            Text("This will remove all content from the canvas. This action cannot be undone.")
        }
        .alert("Delete Canvas?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.impact()
            }
            Button("Delete", role: .destructive) {
                HapticsManager.shared.impact()
                do {
                    try canvasManager.deleteCanvas(canvasFile)
                    // MainView observes canvasManager.canvases and will switch to portfolio
                } catch {
                    toastManager.show(error: .canvasDeletionFailed)
                }
            }
        } message: {
            Text("This will permanently delete \"\(canvasFile.title)\". This action cannot be undone.")
        }
        .onChange(of: canvasManager.pendingShape) { _, newShape in
            // Apply shape from menu bar command
            if let shape = newShape {
                pendingShape = shape
                canvasManager.pendingShape = nil
            }
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
                HapticsManager.shared.impact()
                editedTitle = ""
            }

            Button("Save") {
                HapticsManager.shared.impact()
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
            toastManager.show(error: .canvasUpdateFailed)
        }
        showRenameTitleAlert = false
    }

    // MARK: - Canvas Size Management
    private func initializeCanvasSize() {
        // Use stored canvas size if available, otherwise use default iPad-sized canvas
        if let storedSize = canvasFile.canvasSize {
            effectiveCanvasSize = storedSize
        } else {
            // First time opening - set to default canvas size (iPad-ish)
            // This ensures consistency across devices; smaller screens can pan/zoom
            let defaultSize = CanvasFile.defaultCanvasSize
            canvasFile.setCanvasSize(defaultSize)
            effectiveCanvasSize = defaultSize
            do {
                try canvasManager.saveContext()
            } catch {
                // Ignore save errors for canvas size
            }
        }
    }

    // MARK: - Shape Placement

    /// Places a geometric shape on the canvas at the specified location.
    ///
    /// Transforms view coordinates to canvas content coordinates accounting for
    /// scroll offset and zoom scale, then generates PencilKit strokes for the shape.
    ///
    /// - Parameters:
    ///   - shape: The type of shape to place
    ///   - center: The tap location in view coordinates
    ///   - rotation: Optional rotation angle from Apple Pencil roll
    private func placeShape(_ shape: CanvasShape, at center: CGPoint, rotation: Angle = .zero) {
        // Transform from view coordinates to canvas content coordinates:
        // contentOffset is where the visible area starts in content space
        // center / zoomScale converts screen distance to content distance
        let canvasCenter = CGPoint(
            x: canvasContentOffset.x + (center.x / canvasZoomScale),
            y: canvasContentOffset.y + (center.y / canvasZoomScale)
        )

        let shapeSize: CGFloat = 100
        let ink = PKInk(.pen, color: .black)
        let shapeGenerator = CanvasShapeGenerator()

        let newStrokes = shapeGenerator.generateStrokes(
            for: shape,
            center: canvasCenter,
            size: shapeSize,
            ink: ink,
            rotation: rotation
        )

        guard !newStrokes.isEmpty else { return }

        // Add strokes to existing drawing
        var updatedDrawing = drawing
        for stroke in newStrokes {
            updatedDrawing.strokes.append(stroke)
        }
        drawing = updatedDrawing
    }

    // MARK: - Color Sampling

    /// Gesture overlay for sampling colors from the canvas
    @ViewBuilder
    private var colorSamplingGestureOverlay: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sampleColorAt(value.location, in: geometry.size)
                        }
                        .onEnded { value in
                            sampleColorAt(value.location, in: geometry.size)
                        }
                )
        }
    }

    /// Samples the color at the given view location
    private func sampleColorAt(_ location: CGPoint, in viewSize: CGSize) {
        colorSampleLocation = location

        // Transform view coordinates to canvas content coordinates
        let canvasPoint = CGPoint(
            x: canvasContentOffset.x + (location.x / canvasZoomScale),
            y: canvasContentOffset.y + (location.y / canvasZoomScale)
        )

        // Render the drawing to an image with white background
        guard let canvasSize = effectiveCanvasSize else {
            // Fall back to white if no canvas size
            sampledColor = OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
            return
        }

        // Create image from drawing with white background
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let scale: CGFloat = 1.0

        // Render drawing to image
        let drawingImage = drawing.image(from: bounds, scale: scale)

        // Sample the color from the rendered image
        if let color = samplePixelColor(from: drawingImage, at: canvasPoint, canvasSize: canvasSize) {
            sampledColor = color
            HapticsManager.shared.selection()
        } else {
            // Default to white (canvas background) if sampling fails
            sampledColor = OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
        }
    }

    /// Extracts the pixel color at the given point from an image
    private func samplePixelColor(from image: UIImage, at point: CGPoint, canvasSize: CGSize) -> OpaliteColor? {
        // Ensure point is within bounds
        guard point.x >= 0 && point.x < canvasSize.width &&
              point.y >= 0 && point.y < canvasSize.height else {
            return OpaliteColor(name: nil, red: 1, green: 1, blue: 1) // White for out of bounds
        }

        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Scale point to image pixel coordinates
        let pixelX = Int(point.x * CGFloat(width) / canvasSize.width)
        let pixelY = Int(point.y * CGFloat(height) / canvasSize.height)

        // Ensure pixel is within image bounds
        guard pixelX >= 0 && pixelX < width && pixelY >= 0 && pixelY < height else {
            return OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
        }

        // Create a 1x1 bitmap context to sample the pixel
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: 4)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixelData,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        // Draw the specific pixel into our 1x1 context
        context.draw(cgImage, in: CGRect(x: -pixelX, y: -(height - pixelY - 1), width: width, height: height))

        // Extract RGBA values
        let r = CGFloat(pixelData[0]) / 255.0
        let g = CGFloat(pixelData[1]) / 255.0
        let b = CGFloat(pixelData[2]) / 255.0
        let a = CGFloat(pixelData[3]) / 255.0

        // Handle premultiplied alpha
        let red: Double
        let green: Double
        let blue: Double

        if a > 0 {
            red = Double(r / a)
            green = Double(g / a)
            blue = Double(b / a)
        } else {
            // Transparent pixel - return white (canvas background)
            red = 1.0
            green = 1.0
            blue = 1.0
        }

        return OpaliteColor(
            name: nil,
            red: min(1, red),
            green: min(1, green),
            blue: min(1, blue)
        )
    }

    /// Saves the sampled color to the color manager
    private func saveColorFromSample(_ color: OpaliteColor) {
        do {
            _ = try colorManager.createColor(existing: color)
            toastManager.showSuccess("Color saved: \(color.hexString)")
        } catch {
            toastManager.show(error: .colorCreationFailed)
        }

        isColorSamplingMode = false
        colorSampleLocation = nil
        sampledColor = nil
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

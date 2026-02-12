//
//  CanvasView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftUI
import SwiftData
import PencilKit
import UniformTypeIdentifiers

struct CanvasView: View {
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let canvasFile: CanvasFile

    @State private var drawing: PKDrawing = PKDrawing()
    @State private var selectedInkColor: UIColor = .label
    @State private var forceColorUpdate: UUID = UUID()
    @State private var appearTrigger: UUID = UUID()
    @State private var pendingShape: CanvasShape?
    @State private var editedTitle: String = ""
    @State private var showRenameTitleAlert: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showToolPickerTrigger: UUID = UUID()
    @State private var externalTool: PKTool?
    #if targetEnvironment(macCatalyst)
    @State private var catalystStrokeWidth: CGFloat = 4
    @State private var catalystInkType: PKInkingTool.InkType = .pen
    #endif

    // Color sampling state
    @State private var isColorSamplingMode: Bool = false

    // SVG placement state
    @State private var isShowingSVGImporter: Bool = false
    @State private var pendingSVGPaths: [CGPath]?
    @State private var pendingSVGBounds: CGRect?

    // Export state
    @State private var exportedImage: UIImage?
    @State private var showShareSheet: Bool = false

    // MARK: - Canvas Size & Scroll State
    @State private var effectiveCanvasSize: CGSize?
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

            // Shape placement overlay — drag-to-define with 3-phase state machine
            if let shape = pendingShape {
                ShapePlacementOverlay(
                    shape: shape,
                    onPlace: { rect, rotation in
                        placeShape(shape, in: rect, rotation: rotation)
                        pendingShape = nil
                    },
                    onCancel: {
                        pendingShape = nil
                    }
                )
            }

            // SVG placement overlay — drag-to-define with 3-phase state machine
            if let paths = pendingSVGPaths, let bounds = pendingSVGBounds {
                SVGPlacementOverlay(
                    paths: paths,
                    svgBounds: bounds,
                    onPlace: { rect, rotation in
                        placeSVG(paths: paths, bounds: bounds, in: rect, rotation: rotation)
                        pendingSVGPaths = nil
                        pendingSVGBounds = nil
                    },
                    onCancel: {
                        pendingSVGPaths = nil
                        pendingSVGBounds = nil
                    }
                )
            }

            // Color sampling overlay - isolated view for performance
            if isColorSamplingMode {
                ColorSamplingOverlay(
                    drawing: drawing,
                    canvasSize: effectiveCanvasSize,
                    canvasContentOffset: canvasContentOffset,
                    canvasZoomScale: canvasZoomScale,
                    onSave: { color in
                        saveColorFromSample(color)
                    },
                    onCancel: {
                        isColorSamplingMode = false
                    }
                )
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
                // Force tool picker to reappear after selecting a swatch
                showToolPickerTrigger = UUID()
            }
        }
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
                        .frame(maxWidth: 150)
                }
            }

            if horizontalSizeClass == .compact {
                // Compact: Single "Tools" menu containing everything
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
                                isShowingSVGImporter = true
                            } label: {
                                Label("Place SVG Shape", systemImage: "square.on.circle")
                            }

                            Button {
                                HapticsManager.shared.impact()
                                isColorSamplingMode = true
                            } label: {
                                Label("Sample Color From Canvas", systemImage: "eyedropper")
                            }

                            Button {
                                HapticsManager.shared.impact()
                                exportCanvasAsImage()
                            } label: {
                                Label("Export as Image", systemImage: "square.and.arrow.up")
                            }
                        }

                        #if targetEnvironment(macCatalyst)
                        Section("Drawing Tools") {
                            drawingToolMenuItems
                        }
                        #endif

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
                        Label("Tools", systemImage: "ellipsis.circle")
                    }
                    .toolbarButtonTint()
                }
            } else {
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        drawingToolMenuItems
                    } label: {
                        Label("Drawing Tools", systemImage: "pencil.and.ruler")
                    }
                    .toolbarButtonTint()
                }
                #endif

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsManager.shared.impact()
                        isColorSamplingMode = true
                    } label: {
                        Label("Sample Color", systemImage: "eyedropper")
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
                        
                        Section {
                            Button {
                                HapticsManager.shared.impact()
                                isShowingSVGImporter = true
                            } label: {
                                Label("Place SVG Shape", systemImage: "square.on.circle")
                            }
                        }
                    } label: {
                        Label("Shapes", systemImage: "xmark.triangle.circle.square.fill")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsManager.shared.impact()
                        exportCanvasAsImage()
                    } label: {
                        Label("Export as Image", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }

            #if !os(visionOS)
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            #endif
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
        .fileImporter(
            isPresented: $isShowingSVGImporter,
            allowedContentTypes: [.svg],
            allowsMultipleSelection: false
        ) { result in
            handleSVGImport(result)
        }
        .background {
            ShareSheetPresenter(
                image: exportedImage,
                title: canvasFile.title,
                isPresented: $showShareSheet
            )
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

    /// Places a geometric shape on the canvas using the drag-to-define bounding rect.
    ///
    /// Transforms the view-coordinate rect to canvas content coordinates accounting for
    /// scroll offset and zoom scale, then generates PencilKit strokes for the shape.
    ///
    /// - Parameters:
    ///   - shape: The type of shape to place
    ///   - rect: The bounding rect in view coordinates (from ShapePlacementOverlay)
    ///   - rotation: The rotation angle from two-finger gesture
    private func placeShape(_ shape: CanvasShape, in rect: CGRect, rotation: Angle) {
        // Transform rect from view coordinates to canvas content coordinates
        let canvasCenter = CGPoint(
            x: canvasContentOffset.x + (rect.midX / canvasZoomScale),
            y: canvasContentOffset.y + (rect.midY / canvasZoomScale)
        )
        let canvasWidth = rect.width / canvasZoomScale
        let canvasHeight = rect.height / canvasZoomScale

        let ink = PKInk(.pen, color: .black)
        let shapeGenerator = CanvasShapeGenerator()

        let newStrokes = shapeGenerator.generateStrokes(
            for: shape,
            center: canvasCenter,
            width: canvasWidth,
            height: canvasHeight,
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

    // MARK: - SVG Placement

    /// Handles the result of the SVG file importer
    private func handleSVGImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Gain security-scoped access
            guard url.startAccessingSecurityScopedResource() else {
                toastManager.show(message: "Unable to access the selected file.", style: .error)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let parser = SVGPathParser()
                let parseResult = try parser.parse(from: url)

                // Store paths and bounds for placement
                pendingSVGPaths = parseResult.paths
                pendingSVGBounds = parseResult.bounds

                // Log any warnings
                for warning in parseResult.warnings {
                    print("[SVG Parser] \(warning)")
                }
            } catch {
                toastManager.show(message: "Failed to parse SVG: \(error.localizedDescription)", style: .error)
            }

        case .failure(let error):
            toastManager.show(message: "Failed to import SVG: \(error.localizedDescription)", style: .error)
        }
    }

    /// Places an SVG shape on the canvas using the drag-to-define bounding rect.
    ///
    /// - Parameters:
    ///   - paths: The CGPath objects from the parsed SVG
    ///   - bounds: The bounds of the original SVG
    ///   - rect: The bounding rect in view coordinates (from SVGPlacementOverlay)
    ///   - rotation: The rotation angle from two-finger or pencil gesture
    private func placeSVG(paths: [CGPath], bounds: CGRect, in rect: CGRect, rotation: Angle) {
        // Transform rect from view coordinates to canvas content coordinates
        let canvasCenter = CGPoint(
            x: canvasContentOffset.x + (rect.midX / canvasZoomScale),
            y: canvasContentOffset.y + (rect.midY / canvasZoomScale)
        )
        // Use height as the SVG size (generateSVGStrokes scales by height)
        let canvasHeight = rect.height / canvasZoomScale

        let ink = PKInk(.pen, color: .black)
        let shapeGenerator = CanvasShapeGenerator()

        let newStrokes = shapeGenerator.generateSVGStrokes(
            from: paths,
            svgBounds: bounds,
            center: canvasCenter,
            size: canvasHeight,
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

    /// Saves the sampled color to the color manager
    private func saveColorFromSample(_ color: OpaliteColor) {
        do {
            _ = try colorManager.createColor(existing: color)
            toastManager.showSuccess("Color saved: \(color.hexString)")
        } catch {
            toastManager.show(error: .colorCreationFailed)
        }

        isColorSamplingMode = false
    }

    // MARK: - Mac Catalyst Drawing Tools

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var drawingToolMenuItems: some View {
        Section("Ink Type") {
            Button {
                catalystInkType = .pen
                externalTool = PKInkingTool(.pen, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Pen", systemImage: catalystInkType == .pen ? "checkmark" : "pencil")
            }

            Button {
                catalystInkType = .pencil
                externalTool = PKInkingTool(.pencil, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Pencil", systemImage: catalystInkType == .pencil ? "checkmark" : "pencil.line")
            }

            Button {
                catalystInkType = .marker
                externalTool = PKInkingTool(.marker, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Marker", systemImage: catalystInkType == .marker ? "checkmark" : "highlighter")
            }

            Button {
                catalystInkType = .monoline
                externalTool = PKInkingTool(.monoline, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Monoline", systemImage: catalystInkType == .monoline ? "checkmark" : "line.diagonal")
            }

            Button {
                catalystInkType = .fountainPen
                externalTool = PKInkingTool(.fountainPen, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Fountain Pen", systemImage: catalystInkType == .fountainPen ? "checkmark" : "paintbrush.pointed")
            }

            Button {
                catalystInkType = .watercolor
                externalTool = PKInkingTool(.watercolor, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Watercolor", systemImage: catalystInkType == .watercolor ? "checkmark" : "drop")
            }

            Button {
                catalystInkType = .crayon
                externalTool = PKInkingTool(.crayon, color: selectedInkColor, width: catalystStrokeWidth)
            } label: {
                Label("Crayon", systemImage: catalystInkType == .crayon ? "checkmark" : "pencil.tip")
            }
        }

        Section("Eraser") {
            Button {
                externalTool = PKEraserTool(.bitmap)
            } label: {
                Label("Pixel Eraser", systemImage: "eraser")
            }

            Button {
                externalTool = PKEraserTool(.vector)
            } label: {
                Label("Object Eraser", systemImage: "eraser.line.dashed")
            }
        }

        Section("Stroke Width") {
            ForEach([2, 4, 8, 12, 20], id: \.self) { (width: Int) in
                Button {
                    catalystStrokeWidth = CGFloat(width)
                    externalTool = PKInkingTool(catalystInkType, color: selectedInkColor, width: CGFloat(width))
                } label: {
                    Label("\(width)pt", systemImage: catalystStrokeWidth == CGFloat(width) ? "checkmark" : "circle")
                }
            }
        }
    }
    #endif

    // MARK: - Export

    /// Exports the canvas drawing as an image and presents the share sheet.
    /// The image is cropped to fit the actual content with padding and has a white background.
    private func exportCanvasAsImage() {
        // Get the bounds of the actual drawing content
        let contentBounds = drawing.bounds

        // If the drawing is empty, show an error
        guard !contentBounds.isEmpty else {
            toastManager.show(message: "Canvas is empty.", style: .error)
            return
        }

        // Add padding around the content
        let padding: CGFloat = 40
        let exportBounds = contentBounds.insetBy(dx: -padding, dy: -padding)

        // Render the drawing
        #if os(visionOS)
        let scale: CGFloat = 2.0
        #else
        let scale = UIScreen.main.scale
        #endif
        let drawingImage = drawing.image(from: exportBounds, scale: scale)

        // Create a new image with white background
        let size = exportBounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let finalImage = renderer.image { context in
            // Fill with white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw the PencilKit content on top
            drawingImage.draw(at: .zero)
        }

        exportedImage = finalImage
        showShareSheet = true
    }
}

// MARK: - Color Sampling Overlay

/// Isolated view for color sampling to prevent parent re-renders during drag gestures.
/// Caches the rendered drawing image for efficient pixel sampling.
private struct ColorSamplingOverlay: View {
    let drawing: PKDrawing
    let canvasSize: CGSize?
    let canvasContentOffset: CGPoint
    let canvasZoomScale: CGFloat
    let onSave: (OpaliteColor) -> Void
    let onCancel: () -> Void

    // Local state - isolated from parent
    @State private var sampleLocation: CGPoint?
    @State private var sampledColor: OpaliteColor?
    @State private var cachedImage: UIImage?
    @State private var viewHeight: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()

            // Color preview at hover location
            if let location = sampleLocation, let color = sampledColor {
                colorPreview(color: color, at: location)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        viewHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        viewHeight = newHeight
                    }
            }
        )
        .overlay(alignment: .top) {
            instructionsView
        }
        .overlay {
            gestureOverlay
        }
        .overlay(alignment: .bottom) {
            buttonsView
        }
        .onAppear {
            cacheDrawingImage()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func colorPreview(color: OpaliteColor, at location: CGPoint) -> some View {
        // If touching the top half, show preview below finger; otherwise show above
        let isInTopHalf = location.y < viewHeight / 2
        let previewOffset: CGFloat = isInTopHalf ? 140 : -140

        VStack(spacing: 12) {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 180, height: 180)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            Text(color.hexString)
                .font(.headline.monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .position(x: location.x, y: location.y + previewOffset)
        .allowsHitTesting(false)
    }

    private var instructionsView: some View {
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

    private var gestureOverlay: some View {
        GeometryReader { _ in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sampleColorAt(value.location)
                        }
                        .onEnded { value in
                            sampleColorAt(value.location)
                        }
                )
        }
    }

    private var buttonsView: some View {
        HStack(spacing: 16) {
            Button {
                HapticsManager.shared.selection()
                onCancel()
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
                    onSave(color)
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

    // MARK: - Color Sampling Logic

    /// Caches the drawing as an image once when overlay appears
    private func cacheDrawingImage() {
        guard let canvasSize else { return }
        let bounds = CGRect(origin: .zero, size: canvasSize)
        cachedImage = drawing.image(from: bounds, scale: 1.0)
    }

    /// Samples color from the cached image at the given view location
    private func sampleColorAt(_ location: CGPoint) {
        sampleLocation = location

        // Transform view coordinates to canvas content coordinates
        let canvasPoint = CGPoint(
            x: canvasContentOffset.x + (location.x / canvasZoomScale),
            y: canvasContentOffset.y + (location.y / canvasZoomScale)
        )

        guard let canvasSize, let image = cachedImage else {
            sampledColor = OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
            return
        }

        if let color = samplePixelColor(from: image, at: canvasPoint, canvasSize: canvasSize) {
            // Only trigger haptic if color changed significantly
            if let previous = sampledColor {
                let colorChanged = abs(color.red - previous.red) > 0.05 ||
                                   abs(color.green - previous.green) > 0.05 ||
                                   abs(color.blue - previous.blue) > 0.05
                if colorChanged {
                    HapticsManager.shared.selection()
                }
            } else {
                HapticsManager.shared.selection()
            }
            sampledColor = color
        } else {
            sampledColor = OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
        }
    }

    /// Extracts the pixel color at the given point from an image
    private func samplePixelColor(from image: UIImage, at point: CGPoint, canvasSize: CGSize) -> OpaliteColor? {
        // Ensure point is within bounds
        guard point.x >= 0 && point.x < canvasSize.width &&
              point.y >= 0 && point.y < canvasSize.height else {
            return OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
        }

        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Scale point to image pixel coordinates
        let pixelX = Int(point.x * CGFloat(width) / canvasSize.width)
        let pixelY = Int(point.y * CGFloat(height) / canvasSize.height)

        guard pixelX >= 0 && pixelX < width && pixelY >= 0 && pixelY < height else {
            return OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
        }

        // Create a 1x1 bitmap context to sample the pixel
        var pixelData = [UInt8](repeating: 0, count: 4)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixelData,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
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
            return OpaliteColor(name: nil, red: 1, green: 1, blue: 1)
        }

        return OpaliteColor(
            name: nil,
            red: min(1, red),
            green: min(1, green),
            blue: min(1, blue)
        )
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

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
                zoomScale: $canvasZoomScale
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
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(canvasFile.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 180)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.impact()
                    editedTitle = canvasFile.title
                    showRenameTitleAlert = true
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
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
                            Label("Delete Canvas", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
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

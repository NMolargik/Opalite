//
//  CanvasView.swift
//  OpaliteFeatureCanvas
//
//  The PencilKit editor. Edge-to-edge canvas; a floating glass toolbar (tool picker,
//  shapes, insert image, undo/redo, swatches); the ink strip as a bottom glass bar that
//  sits above the system tool picker; drag-to-define placement; placed-image editing;
//  autosave through `CanvasModel`; rename, link to palette, PNG share, clear, delete.
//

import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct CanvasView: View {
    private let canvasID: UUID

    public init(canvasID: UUID) {
        self.canvasID = canvasID
    }

    public var body: some View {
        #if canImport(PencilKit) && (os(iOS) || os(visionOS))
        CanvasResolverView(canvasID: canvasID)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(PencilKit) && (os(iOS) || os(visionOS))
import PencilKit
import UIKit
#if canImport(PhotosUI)
import PhotosUI
#endif

/// Looks the canvas up and recreates the editor when the id changes.
private struct CanvasResolverView: View {
    @Environment(CanvasModel.self) private var canvases
    let canvasID: UUID

    var body: some View {
        if let canvas = canvases.canvas(withID: canvasID) {
            CanvasEditorView(canvas: canvas)
                .id(canvas.id)
        } else {
            ContentUnavailableView("Canvas Not Found", systemImage: "scribble.variable", description: Text("This canvas may have been deleted on another device."))
        }
    }
}

struct CanvasEditorView: View {
    @Environment(CanvasModel.self) private var canvases
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var model: CanvasEditorModel
    @State private var deleting: CanvasFile?
    #if canImport(PhotosUI)
    @State private var photoItem: PhotosPickerItem?
    #endif

    init(canvas: CanvasFile) {
        _model = State(initialValue: CanvasEditorModel(canvas: canvas))
    }

    var body: some View {
        presentations(for: observed(chrome(for: canvasStack)))
            .background(Color.white.ignoresSafeArea())
    }

    /// Overlays, navigation chrome, and lifecycle.
    private func chrome(for content: some View) -> some View {
        content
            .overlay(alignment: .top) { topChrome }
            .overlay(alignment: .bottom) { bottomChrome }
            .navigationTitle(model.canvas.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            // The PencilKit tool picker docks at the bottom edge; the floating tab bar
            // would sit on top of it.
            .toolbar(.hidden, for: .tabBar)
            .toolbarRole(.editor)
            .task { attachAndLoad() }
            .onDisappear { model.flush() }
    }

    /// Reactions to the shell and the scene.
    private func observed(_ content: some View) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.flush() }
            }
            .onChange(of: canvases.pendingShape) { _, shape in
                guard let shape else { return }
                model.beginPlacing(shape)
                canvases.pendingShape = nil
            }
            .onChange(of: canvases.selectedInkColor) { _, rgba in
                guard let rgba else { return }
                model.setInk(rgba)
                canvases.selectedInkColor = nil
            }
    }

    /// Alerts, dialogs, and importers.
    private func presentations(for content: some View) -> some View {
        content
            .alert("Rename Canvas", isPresented: $model.isPresentingRename) {
                TextField("Canvas name", text: $model.renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { model.commitRename() }
            }
            .confirmationDialog("Clear Canvas?", isPresented: $model.isConfirmingClear, titleVisibility: .visible) {
                Button("Clear Everything", role: .destructive) { model.clearCanvas() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes every stroke and placed image. You can undo this.")
            }
            .canvasDeleteConfirmation(for: $deleting) { dismiss() }
            .fileImporter(isPresented: $model.isImportingSVG, allowedContentTypes: [.svg]) { model.importSVG($0.map { [$0] }) }
            .fileImporter(isPresented: $model.isImportingImageFile, allowedContentTypes: [.image]) { model.importImageFile($0.map { [$0] }) }
            .photoPicker(isPresented: $model.isPickingPhoto, onImage: { model.insertImage(data: $0) })
    }

    // MARK: - Canvas

    private var canvasStack: some View {
        ZStack {
            Color.white

            if !model.isEditingImages {
                imagesLayer
            }

            PencilCanvasRepresentable(
                drawing: model.drawing,
                canvasSize: model.canvasSize,
                inkColor: model.inkColor.uiColor,
                inkStamp: model.inkStamp,
                externalTool: model.externalTool,
                externalToolStamp: model.externalToolStamp,
                isToolPickerVisible: model.isToolPickerVisible,
                suppressToolPicker: model.isPresentingRename || model.isConfirmingClear || deleting != nil,
                isInteractionEnabled: model.isDrawingEnabled,
                onDrawingChanged: { model.drawingDidChange($0) },
                onViewportChanged: { offset, zoom, size in
                    model.contentOffset = offset
                    model.zoomScale = zoom
                    model.viewportSize = size
                },
                onObscuredInsetChanged: { model.obscuredBottomInset = $0 },
                onUserToolChanged: { model.userSelectedTool($0) }
            )
            .accessibilityIdentifier("canvas.drawing")

            if model.isEditingImages {
                imagesLayer
            }

            if let placement = model.placement {
                ShapePlacementOverlay(
                    subject: placement,
                    onPlace: { rect, rotation in model.place(viewRect: rect, rotation: rotation) },
                    onCancel: { model.cancelPlacement() }
                )
                .id(placement.id)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.isPlacing)
    }

    private var imagesLayer: some View {
        CanvasPlacedImagesLayer(
            images: model.placedImages,
            canvasSize: model.canvasSize,
            contentOffset: model.contentOffset,
            zoomScale: model.zoomScale,
            isEditing: model.isEditingImages,
            selectedImageID: model.selectedImageID,
            onSelect: { model.selectedImageID = $0 },
            onBeginEdit: { model.beginImageEdit() },
            onChange: { model.updateImage($0) },
            onEndEdit: { model.endImageEdit($0) },
            onDelete: { model.deleteImage(id: $0) }
        )
    }

    // MARK: - Floating chrome

    private var topChrome: some View {
        VStack(spacing: Brand.Space.sm) {
            if model.isEditingImages {
                imageEditingBar
            } else if !model.isPlacing {
                floatingToolbar
                #if targetEnvironment(macCatalyst)
                if !model.isToolPickerVisible {
                    CatalystToolPicker(inkColor: model.inkColor) { model.apply(externalTool: $0) }
                }
                #endif
            }
        }
        .padding(.top, Brand.Space.sm)
        .padding(.horizontal, Brand.Space.lg)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: model.isEditingImages)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: model.isPlacing)
    }

    private var floatingToolbar: some View {
        HStack(spacing: Brand.Space.xs) {
            toolButton(model.isToolPickerVisible ? String(localized: "Hide Tools") : String(localized: "Show Tools"), symbol: "pencil.tip.crop.circle", isOn: model.isToolPickerVisible, identifier: "canvas.tools") {
                model.isToolPickerVisible.toggle()
            }

            Divider().frame(height: 22)

            Menu {
                shapesMenu
            } label: {
                toolGlyph("square.on.circle", isOn: false)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Shapes"))
            .accessibilityIdentifier("canvas.shapes")

            Menu {
                insertMenu
            } label: {
                toolGlyph("photo.badge.plus", isOn: false)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Insert Image"))
            .accessibilityIdentifier("canvas.insert")

            Divider().frame(height: 22)

            toolButton(String(localized: "Undo"), symbol: "arrow.uturn.backward", isOn: false, identifier: "canvas.undo", disabled: !model.canUndo) {
                model.undo()
            }
            .keyboardShortcut("z", modifiers: .command)

            toolButton(String(localized: "Redo"), symbol: "arrow.uturn.forward", isOn: false, identifier: "canvas.redo", disabled: !model.canRedo) {
                model.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider().frame(height: 22)

            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { model.isSwatchStripVisible.toggle() }
            } label: {
                HStack(spacing: Brand.Space.xs) {
                    Circle()
                        .fill(model.inkColor.color)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2)))
                        .frame(width: 18, height: 18)
                    Image(systemName: model.isSwatchStripVisible ? "chevron.down" : "chevron.up")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 36)
                .padding(.horizontal, Brand.Space.sm)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Swatches"))
            .accessibilityValue(Text("Ink \(model.inkColor.hexString), \(model.isSwatchStripVisible ? "shown" : "hidden")"))
            .accessibilityIdentifier("canvas.swatches")
            .hoverHighlight()
        }
        .padding(.horizontal, Brand.Space.sm)
        .padding(.vertical, Brand.Space.xs)
        .adaptiveGlassCapsule()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Canvas tools"))
    }

    private var imageEditingBar: some View {
        HStack(spacing: Brand.Space.md) {
            Group {
                if model.selectedImage == nil {
                    Label("Tap an image to edit", systemImage: "photo")
                } else {
                    Label("Drag to move · corners resize · two fingers rotate", systemImage: "photo")
                }
            }
            .font(.subheadline.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            if model.selectedImage != nil {
                Button {
                    model.bringSelectedImageToFront()
                } label: {
                    Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("canvas.image.front")
            }
            Button("Done") {
                Haptics.selection()
                model.finishEditingImages()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("canvas.image.done")
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.sm)
        .adaptiveGlassCapsule(tint: .opalitePurple)
    }

    private var bottomChrome: some View {
        Group {
            if model.isSwatchStripVisible, !model.isPlacing, !model.isEditingImages {
                CanvasSwatchPickerView(preferredPaletteID: model.canvas.palette?.id, selected: model.inkColor) { rgba in
                    model.setInk(rgba)
                }
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.sm + swatchStripBottomInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: model.obscuredBottomInset)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: model.isSwatchStripVisible)
    }

    /// The compact tool picker collapses to a floating pen at the bottom edge and reports
    /// no obscured frame, so keep the strip clear of it by a fixed amount there.
    private var swatchStripBottomInset: CGFloat {
        let collapsedPickerHeight: CGFloat = sizeClass == .compact && model.isToolPickerVisible ? 72 : 0
        return max(model.obscuredBottomInset, collapsedPickerHeight)
    }

    // MARK: - Menus

    @ContentBuilder
    private var shapesMenu: some View {
        Section("Shapes") {
            ForEach(CanvasShape.allCases) { shape in
                Button {
                    model.beginPlacing(shape)
                } label: {
                    Label(shape.displayName, systemImage: shape.systemImage)
                }
                .if(shape.keyboardNumber != nil) { button in
                    button.keyboardShortcut(KeyEquivalent(Character(String(shape.keyboardNumber ?? 0))), modifiers: [.command, .shift])
                }
            }
        }
        Section {
            Button {
                model.isImportingSVG = true
            } label: {
                Label("Place SVG File…", systemImage: "square.on.circle")
            }
        }
    }

    @ContentBuilder
    private var insertMenu: some View {
        Button {
            model.isPickingPhoto = true
        } label: {
            Label("Photo Library…", systemImage: "photo.on.rectangle")
        }
        Button {
            model.isImportingImageFile = true
        } label: {
            Label("Choose File…", systemImage: "folder")
        }
        if !model.placedImages.isEmpty {
            Divider()
            Button {
                Haptics.selection()
                model.startEditingImages()
            } label: {
                Label("Edit Placed Images", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.selection()
                    model.beginRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Menu {
                    PaletteLinkMenuContent(canvas: model.canvas)
                } label: {
                    Label(model.canvas.palette == nil ? "Link Palette" : "Linked: \(model.canvas.palette?.name ?? "")", systemImage: "link")
                }
                ShareLink(item: model.makeExport(), preview: sharePreview) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                }
                .disabled(model.isEmpty)
                Divider()
                Button(role: .destructive) {
                    model.isConfirmingClear = true
                } label: {
                    Label("Clear Canvas", systemImage: "eraser")
                }
                .disabled(model.isEmpty)
                .destructiveMenuItem()
                Button(role: .destructive) {
                    deleting = model.canvas
                } label: {
                    Label("Delete Canvas", systemImage: "trash")
                }
                .destructiveMenuItem()
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .toolbarButtonTint()
            .accessibilityIdentifier("canvas.more")
        }
    }

    private var sharePreview: SharePreview<Image, Never> {
        if let data = model.canvas.thumbnailData, let image = UIImage(data: data) {
            return SharePreview(model.canvas.title, image: Image(uiImage: image))
        }
        return SharePreview(model.canvas.title, image: Image(systemName: "scribble.variable"))
    }

    // MARK: - Helpers

    private func toolButton(_ label: String, symbol: String, isOn: Bool, identifier: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            toolGlyph(symbol, isOn: isOn)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
        .hoverHighlight()
    }

    private func toolGlyph(_ symbol: String, isOn: Bool) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: 36, height: 36)
            .background(Circle().fill(isOn ? Color.opalitePurple : Color.clear))
            .contentShape(Circle())
    }

    private func attachAndLoad() {
        model.attach(canvases: canvases, toasts: toasts)
        model.load()
        if let shape = canvases.pendingShape {
            model.beginPlacing(shape)
            canvases.pendingShape = nil
        }
        if let rgba = canvases.selectedInkColor {
            model.setInk(rgba)
            canvases.selectedInkColor = nil
        }
    }
}

// MARK: - Photo picking

extension View {
    /// Presents the photo library and returns the chosen image's bytes.
    @ContentBuilder
    func photoPicker(isPresented: Binding<Bool>, onImage: @escaping (Data) -> Void) -> some View {
        #if canImport(PhotosUI)
        modifier(PhotoPickerModifier(isPresented: isPresented, onImage: onImage))
        #else
        self
        #endif
    }
}

#if canImport(PhotosUI)
private struct PhotoPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImage: (Data) -> Void
    @State private var item: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $item, matching: .images)
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        onImage(data)
                    }
                    item = nil
                }
            }
    }
}
#endif

#if DEBUG
#Preview("Editor") {
    let environment = PreviewEnvironment()
    return NavigationStack {
        if let canvas = environment.canvases.canvases.first {
            CanvasView(canvasID: canvas.id)
        }
    }
    .previewEnvironment(environment)
}
#endif
#endif

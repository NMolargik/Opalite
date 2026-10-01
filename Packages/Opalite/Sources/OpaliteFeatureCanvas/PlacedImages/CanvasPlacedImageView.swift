//
//  CanvasPlacedImageView.swift
//  OpaliteFeatureCanvas
//
//  Placed images on the canvas: the layer that positions every image in canvas space
//  (scaled and offset with the scroll view), and the per-image view with selection,
//  move, aspect-locked corner resize, two-finger rotation, and a mini toolbar.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UIKit
import OpaliteCore
import OpaliteDesignSystem

/// Every placed image, laid out in canvas coordinates and mapped into the viewport.
struct CanvasPlacedImagesLayer: View {
    let images: [CanvasPlacedImage]
    let canvasSize: CGSize
    let contentOffset: CGPoint
    let zoomScale: CGFloat
    let isEditing: Bool
    let selectedImageID: UUID?
    let onSelect: (UUID?) -> Void
    let onBeginEdit: () -> Void
    let onChange: (CanvasPlacedImage) -> Void
    let onEndEdit: (CanvasPlacedImage) -> Void
    let onDelete: (UUID) -> Void

    private static let spaceName = "canvasViewport"

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isEditing {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(nil) }
                    .accessibilityHidden(true)
            }
            ZStack(alignment: .topLeading) {
                ForEach(images.sorted { $0.zIndex < $1.zIndex }) { image in
                    CanvasPlacedImageView(
                        image: image,
                        isSelected: isEditing && selectedImageID == image.id,
                        isInteractive: isEditing,
                        zoomScale: zoomScale,
                        coordinateSpace: .named(Self.spaceName),
                        onSelect: { onSelect(image.id) },
                        onBeginEdit: onBeginEdit,
                        onChange: onChange,
                        onEndEdit: onEndEdit,
                        onDelete: { onDelete(image.id) }
                    )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
            .scaleEffect(zoomScale, anchor: .topLeading)
            .offset(x: -contentOffset.x, y: -contentOffset.y)
        }
        .coordinateSpace(name: Self.spaceName)
        .clipped()
        .allowsHitTesting(isEditing)
    }
}

struct CanvasPlacedImageView: View {
    let image: CanvasPlacedImage
    let isSelected: Bool
    let isInteractive: Bool
    let zoomScale: CGFloat
    let coordinateSpace: CoordinateSpace
    let onSelect: () -> Void
    let onBeginEdit: () -> Void
    let onChange: (CanvasPlacedImage) -> Void
    let onEndEdit: (CanvasPlacedImage) -> Void
    let onDelete: () -> Void

    @State private var dragStart: CanvasPlacedImage?
    @State private var resizeStart: CanvasPlacedImage?
    @State private var rotationStart: Double?
    @State private var uiImage: UIImage?

    /// Chrome is drawn in canvas space, so it's divided by zoom to stay constant on screen.
    private var inverseZoom: CGFloat { 1 / max(zoomScale, 0.0001) }
    private var handleSize: CGFloat { 22 * inverseZoom }

    var body: some View {
        ZStack {
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: image.size.width, height: image.size.height)
            .clipped()
            .overlay {
                if isSelected {
                    Rectangle().strokeBorder(Color.opalitePurple, lineWidth: 2 * inverseZoom)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard isInteractive else { return }
                Haptics.selection()
                onSelect()
            }
            .gesture(isSelected ? moveGesture : nil)
            .simultaneousGesture(isSelected ? rotateGesture : nil)

            if isSelected {
                ForEach(PlacedImageHandle.allCases, id: \.self) { handle in
                    let offset = handle.offset(for: image.size)
                    resizeHandle(handle)
                        .offset(x: offset.x, y: offset.y)
                }
                miniToolbar
                    .offset(y: -image.size.height / 2 - 28 * inverseZoom)
            }
        }
        .rotationEffect(.degrees(image.rotation))
        .position(image.position)
        .task(id: image.imageData.count) { uiImage = UIImage(data: image.imageData) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Placed image"))
        .accessibilityValue(isSelected ? Text("Selected") : Text(""))
        .accessibilityHint(isInteractive ? Text("Double-tap to select") : Text(""))
    }

    // MARK: - Gestures

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: coordinateSpace)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = image
                    onBeginEdit()
                }
                guard let dragStart else { return }
                onChange(PlacedImageGeometry.moved(dragStart, by: value.translation, zoomScale: zoomScale))
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                onEndEdit(PlacedImageGeometry.moved(start, by: value.translation, zoomScale: zoomScale))
            }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                if rotationStart == nil {
                    rotationStart = image.rotation
                    onBeginEdit()
                }
                guard let rotationStart else { return }
                var updated = image
                updated.rotation = 0
                onChange(PlacedImageGeometry.rotated(updated, by: rotationStart + value.rotation.degrees))
            }
            .onEnded { _ in
                rotationStart = nil
                onEndEdit(image)
            }
    }

    private func resizeHandle(_ handle: PlacedImageHandle) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(Color.opalitePurple, lineWidth: 2 * inverseZoom))
            .shadow(color: .black.opacity(0.2), radius: 2 * inverseZoom, y: inverseZoom)
            .frame(width: handleSize, height: handleSize)
            .contentShape(Circle().scale(2))
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: coordinateSpace)
                    .onChanged { value in
                        if resizeStart == nil {
                            resizeStart = image
                            onBeginEdit()
                        }
                        guard let resizeStart else { return }
                        onChange(PlacedImageGeometry.resized(resizeStart, handle: handle, translation: value.translation, zoomScale: zoomScale, startSize: resizeStart.size, startPosition: resizeStart.position))
                    }
                    .onEnded { value in
                        guard let start = resizeStart else { return }
                        resizeStart = nil
                        onEndEdit(PlacedImageGeometry.resized(start, handle: handle, translation: value.translation, zoomScale: zoomScale, startSize: start.size, startPosition: start.position))
                    }
            )
            .accessibilityLabel(Text(handle.accessibilityName))
            .accessibilityHint(Text("Drag to resize"))
    }

    // MARK: - Mini toolbar

    private var miniToolbar: some View {
        HStack(spacing: 2) {
            toolbarButton(String(localized: "Rotate left"), symbol: "rotate.left") {
                onBeginEdit()
                onEndEdit(PlacedImageGeometry.rotated(image, by: -15))
                Haptics.selection()
            }
            toolbarButton(String(localized: "Rotate right"), symbol: "rotate.right") {
                onBeginEdit()
                onEndEdit(PlacedImageGeometry.rotated(image, by: 15))
                Haptics.selection()
            }
            toolbarButton(String(localized: "Delete image"), symbol: "trash", tint: .red) {
                onDelete()
            }
        }
        .padding(4 * inverseZoom)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .scaleEffect(inverseZoom)
        .fixedSize()
    }

    private func toolbarButton(_ label: String, symbol: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
#endif

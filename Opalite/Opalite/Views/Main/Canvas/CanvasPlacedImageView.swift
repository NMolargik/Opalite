//
//  CanvasPlacedImageView.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A view that displays a placed image on the canvas with selection and manipulation capabilities.
struct CanvasPlacedImageView: View {
    let image: CanvasPlacedImage
    let isSelected: Bool
    let zoomScale: CGFloat
    let onSelect: () -> Void
    let onUpdate: (CanvasPlacedImage) -> Void
    let onDelete: () -> Void

    // Local drag state for responsive movement
    @State private var dragOffset: CGSize = .zero
    @State private var isResizing: Bool = false
    @State private var resizeStartSize: CGSize = .zero
    @State private var activeHandle: ResizeHandle?

    private enum ResizeHandle {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    // Handle size adjusted for zoom
    private var handleSize: CGFloat {
        max(20, 30 / zoomScale)
    }

    private var handleHitSize: CGFloat {
        max(44, 60 / zoomScale)
    }

    var body: some View {
        let currentPosition = CGPoint(
            x: image.position.x + dragOffset.width,
            y: image.position.y + dragOffset.height
        )

        ZStack {
            // Image content
            if let uiImage = image.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: image.size.width, height: image.size.height)
                    .clipped()
                    .rotationEffect(.degrees(image.rotation))
            }

            // Selection overlay and handles
            if isSelected {
                // Border outline
                Rectangle()
                    .strokeBorder(Color.blue, lineWidth: max(2, 3 / zoomScale))
                    .frame(width: image.size.width, height: image.size.height)

                // Resize handles
                ForEach([ResizeHandle.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { handle in
                    resizeHandleView(for: handle)
                        .position(handlePosition(for: handle))
                }

                // Delete button
                deleteButton
                    .position(x: image.size.width / 2, y: -handleSize - 10)
            }
        }
        .frame(width: image.size.width, height: image.size.height)
        .position(currentPosition)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticsManager.shared.selection()
            onSelect()
        }
        .gesture(
            isSelected ? dragGesture : nil
        )
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging if not resizing
                guard activeHandle == nil else { return }
                dragOffset = CGSize(
                    width: value.translation.width / zoomScale,
                    height: value.translation.height / zoomScale
                )
            }
            .onEnded { value in
                guard activeHandle == nil else { return }
                var updated = image
                updated.position = CGPoint(
                    x: image.position.x + value.translation.width / zoomScale,
                    y: image.position.y + value.translation.height / zoomScale
                )
                onUpdate(updated)
                dragOffset = .zero
            }
    }

    // MARK: - Resize Handle View

    @ViewBuilder
    private func resizeHandleView(for handle: ResizeHandle) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .strokeBorder(Color.blue, lineWidth: max(2, 2 / zoomScale))
            )
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .contentShape(Rectangle().size(width: handleHitSize, height: handleHitSize))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            activeHandle = handle
                            resizeStartSize = image.size
                        }
                        handleResize(value: value, handle: handle)
                    }
                    .onEnded { value in
                        finalizeResize(value: value, handle: handle)
                        isResizing = false
                        activeHandle = nil
                        resizeStartSize = .zero
                    }
            )
    }

    private func handlePosition(for handle: ResizeHandle) -> CGPoint {
        let halfWidth = image.size.width / 2
        let halfHeight = image.size.height / 2

        switch handle {
        case .topLeft:
            return CGPoint(x: -halfWidth, y: -halfHeight)
        case .topRight:
            return CGPoint(x: halfWidth, y: -halfHeight)
        case .bottomLeft:
            return CGPoint(x: -halfWidth, y: halfHeight)
        case .bottomRight:
            return CGPoint(x: halfWidth, y: halfHeight)
        }
    }

    private func handleResize(value: DragGesture.Value, handle: ResizeHandle) {
        let delta = CGSize(
            width: value.translation.width / zoomScale,
            height: value.translation.height / zoomScale
        )

        var newSize = resizeStartSize
        var newPosition = image.position

        let aspectRatio = resizeStartSize.width / resizeStartSize.height

        switch handle {
        case .topLeft:
            let deltaSize = min(delta.width, delta.height * aspectRatio)
            newSize.width = max(50, resizeStartSize.width - deltaSize)
            newSize.height = newSize.width / aspectRatio
            newPosition.x = image.position.x + (resizeStartSize.width - newSize.width) / 2
            newPosition.y = image.position.y + (resizeStartSize.height - newSize.height) / 2
        case .topRight:
            let deltaSize = max(delta.width, -delta.height * aspectRatio)
            newSize.width = max(50, resizeStartSize.width + deltaSize)
            newSize.height = newSize.width / aspectRatio
            newPosition.x = image.position.x + (newSize.width - resizeStartSize.width) / 2
            newPosition.y = image.position.y - (newSize.height - resizeStartSize.height) / 2
        case .bottomLeft:
            newSize.width = max(50, resizeStartSize.width - (-delta.width))
            newSize.height = newSize.width / aspectRatio
            newPosition.x = image.position.x - (newSize.width - resizeStartSize.width) / 2
            newPosition.y = image.position.y + (newSize.height - resizeStartSize.height) / 2
        case .bottomRight:
            let deltaSize = max(delta.width, delta.height * aspectRatio)
            newSize.width = max(50, resizeStartSize.width + deltaSize)
            newSize.height = newSize.width / aspectRatio
            newPosition.x = image.position.x + (newSize.width - resizeStartSize.width) / 2
            newPosition.y = image.position.y + (newSize.height - resizeStartSize.height) / 2
        }

        var updated = image
        updated.size = newSize
        updated.position = newPosition
        onUpdate(updated)
    }

    private func finalizeResize(value: DragGesture.Value, handle: ResizeHandle) {
        // The final state is already applied in handleResize
    }

    // MARK: - Delete Button

    @ViewBuilder
    private var deleteButton: some View {
        Button {
            HapticsManager.shared.impact()
            onDelete()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: max(24, 28 / zoomScale)))
                .foregroundStyle(.white, .red)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
    }
}

/// A container view that renders all placed images on the canvas
struct CanvasPlacedImagesLayer: View {
    let images: [CanvasPlacedImage]
    let selectedImageId: UUID?
    let zoomScale: CGFloat
    let onSelectImage: (UUID?) -> Void
    let onUpdateImage: (CanvasPlacedImage) -> Void
    let onDeleteImage: (UUID) -> Void

    var body: some View {
        ZStack {
            ForEach(images.sorted(by: { $0.zIndex < $1.zIndex })) { image in
                CanvasPlacedImageView(
                    image: image,
                    isSelected: selectedImageId == image.id,
                    zoomScale: zoomScale,
                    onSelect: {
                        onSelectImage(image.id)
                    },
                    onUpdate: { updated in
                        onUpdateImage(updated)
                    },
                    onDelete: {
                        onDeleteImage(image.id)
                    }
                )
            }
        }
    }
}

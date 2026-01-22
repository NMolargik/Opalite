//
//  ShapePlacementOverlay.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

/// Overlay view for shape placement that manages its own gesture state
/// to avoid causing parent view re-renders during drag/pinch/rotate gestures.
struct ShapePlacementOverlay: View {
    let shape: CanvasShape
    /// Callback when shape is placed: (location, rotation, scale, aspectRatio)
    let onPlace: (CGPoint, Angle, CGFloat, CGFloat) -> Void
    let onCancel: () -> Void

    // Local state - changes don't propagate to parent
    @State private var previewLocation: CGPoint?
    @State private var rotation: Angle = .zero
    @State private var scale: CGFloat = 1.0
    @State private var aspectRatio: CGFloat = 1.0

    /// Whether this shape supports non-uniform (independent width/height) scaling
    private var useNonUniformScale: Bool {
        shape.supportsNonUniformScale
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()

            // Shape preview at current location
            if let location = previewLocation {
                ShapePreviewView(shape: shape, scale: scale, aspectRatio: aspectRatio)
                    .rotationEffect(rotation)
                    .position(location)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            instructionsView
        }
        .overlay {
            PencilHoverView(
                hoverLocation: $previewLocation,
                rollAngle: $rotation,
                shapeScale: $scale,
                aspectRatio: $aspectRatio,
                useNonUniformScale: useNonUniformScale,
                onTap: { location in
                    // Use the actual touch/gesture location for placement
                    // This ensures accuracy even if hover events interfere
                    onPlace(location, rotation, scale, aspectRatio)
                }
            )
        }
        .overlay(alignment: .bottom) {
            cancelButton
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 8) {
            Text("Drag to position, release to place")
                .font(.headline)
            if useNonUniformScale {
                Text("Use two fingers to resize and rotate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Use two fingers to pinch and rotate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if rotation != .zero {
                    Text("Rotation: \(Int(rotation.degrees))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if scale != 1.0 {
                    Text("Scale: \(String(format: "%.1fx", scale))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if useNonUniformScale && aspectRatio != 1.0 {
                    Text("Aspect: \(String(format: "%.2f", aspectRatio))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 80)
    }

    private var cancelButton: some View {
        Button {
            HapticsManager.shared.impact()
            onCancel()
        } label: {
            Text("Cancel")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 100)
    }
}

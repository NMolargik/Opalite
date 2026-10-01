//
//  ShapePlacementOverlay.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

/// Overlay view for drag-to-define shape placement.
///
/// Three phases:
/// 1. **Idle** — dimmed overlay, instructions, waiting for first touch.
/// 2. **Drawing** — drag from A to B to define bounding box; shape preview stretches in real-time.
/// 3. **Adjusting** — shape at final size; one-finger drag repositions, two-finger rotates.
///    Place/Cancel buttons visible.
struct ShapePlacementOverlay: View {
    let shape: CanvasShape
    /// Called when the user commits the shape: (bounding rect in view coords, rotation angle).
    let onPlace: (CGRect, Angle) -> Void
    let onCancel: () -> Void

    // Local state — isolated from parent to prevent re-renders
    @State private var phase: ShapePlacementPhase = .idle
    @State private var shapeRect: CGRect = .zero
    @State private var rotation: CGFloat = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.1)
                .ignoresSafeArea()

            // Shape preview — visible during drawing and adjusting phases
            if phase == .drawing || phase == .adjusting {
                shapePreview
            }
        }
        .overlay(alignment: .top) {
            instructionsView
        }
        .overlay {
            // Gesture layer
            ShapeDrawingRepresentable(
                shapeRect: $shapeRect,
                rotation: $rotation,
                phase: $phase,
                constrainedAspectRatio: shape.constrainedAspectRatio
            )
        }
        .overlay(alignment: .bottom) {
            buttonsView
        }
    }

    // MARK: - Shape Preview

    private var shapePreview: some View {
        ShapePreviewView(
            shape: shape,
            explicitWidth: max(shapeRect.width, 1),
            explicitHeight: max(shapeRect.height, 1)
        )
        .rotationEffect(Angle(radians: Double(rotation)))
        .position(
            x: shapeRect.midX,
            y: shapeRect.midY
        )
        .allowsHitTesting(false)
    }

    // MARK: - Instructions

    private var instructionsView: some View {
        VStack(spacing: 8) {
            switch phase {
            case .idle:
                Text("Drag to draw \(shape.displayName.lowercased())")
                    .font(.headline)
                Text("Draw from corner to corner to define size")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .drawing:
                Text("Release to finalize size")
                    .font(.headline)
                dimensionLabel

            case .adjusting:
                Text("Drag to reposition, rotate with two fingers or Apple Pencil Pro")
                    .font(.headline)
                HStack(spacing: 16) {
                    dimensionLabel
                    if rotation != 0 {
                        let degrees = rotation * 180 / .pi
                        let snapped = (degrees / 5).rounded() * 5
                        Text("\(Int(snapped))°")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 80)
        .animation(.easeInOut(duration: 0.2), value: phase == .idle)
    }

    private var dimensionLabel: some View {
        Text("\(Int(shapeRect.width)) × \(Int(shapeRect.height))")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
    }

    // MARK: - Buttons

    private var buttonsView: some View {
        HStack(spacing: 16) {
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
            .buttonStyle(.plain)

            if phase == .adjusting {
                Button {
                    HapticsManager.shared.impact()
                    onPlace(shapeRect, Angle(radians: Double(rotation)))
                } label: {
                    Text("Place")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 100)
        .animation(.easeInOut(duration: 0.2), value: phase == .adjusting)
    }
}

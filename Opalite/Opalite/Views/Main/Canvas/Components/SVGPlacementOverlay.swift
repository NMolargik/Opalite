//
//  SVGPlacementOverlay.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CoreGraphics

/// Overlay view for drag-to-define SVG placement.
///
/// Uses the same 3-phase system as `ShapePlacementOverlay`:
/// 1. **Idle** — dimmed overlay, instructions, waiting for first touch.
/// 2. **Drawing** — drag from A to B to define bounding box (locked to SVG aspect ratio).
/// 3. **Adjusting** — SVG at final size; one-finger drag repositions, two-finger or pencil rotates.
///    Place/Cancel buttons visible.
struct SVGPlacementOverlay: View {
    let paths: [CGPath]
    let svgBounds: CGRect
    /// Called when the user commits the SVG: (bounding rect in view coords, rotation angle).
    let onPlace: (CGRect, Angle) -> Void
    let onCancel: () -> Void

    // Local state — isolated from parent to prevent re-renders
    @State private var phase: ShapePlacementPhase = .idle
    @State private var shapeRect: CGRect = .zero
    @State private var rotation: CGFloat = 0

    /// Lock the drag to the SVG's natural aspect ratio.
    private var svgAspectRatio: CGFloat {
        guard svgBounds.height > 0 else { return 1.0 }
        return svgBounds.width / svgBounds.height
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()

            if phase == .drawing || phase == .adjusting {
                svgPreview
            }
        }
        .overlay(alignment: .top) {
            instructionsView
        }
        .overlay {
            ShapeDrawingRepresentable(
                shapeRect: $shapeRect,
                rotation: $rotation,
                phase: $phase,
                constrainedAspectRatio: svgAspectRatio
            )
        }
        .overlay(alignment: .bottom) {
            buttonsView
        }
    }

    // MARK: - SVG Preview

    private var svgPreview: some View {
        SVGPreviewView(
            paths: paths,
            svgBounds: svgBounds,
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
                Text("Drag to draw SVG shape")
                    .font(.headline)
                Text("Draw from corner to corner to define size")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .drawing:
                Text("Release to finalize size")
                    .font(.headline)
                dimensionLabel

            case .adjusting:
                Text("Drag to reposition, rotate with two fingers or Pencil")
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
            }
        }
        .padding(.bottom, 100)
        .animation(.easeInOut(duration: 0.2), value: phase == .adjusting)
    }
}

// MARK: - SVG Preview View

/// Preview of an SVG shape during placement
struct SVGPreviewView: View {
    let paths: [CGPath]
    let svgBounds: CGRect
    var scale: CGFloat = 1.0
    /// Explicit width override (used by drag-to-define). When set, `scale` is ignored.
    var explicitWidth: CGFloat?
    /// Explicit height override (used by drag-to-define). When set, `scale` is ignored.
    var explicitHeight: CGFloat?

    /// Base size for the preview (height)
    private let baseSize: CGFloat = 100

    /// The actual size based on scale
    private var size: CGFloat {
        baseSize * scale
    }

    /// The aspect ratio of the SVG
    private var svgAspectRatio: CGFloat {
        guard svgBounds.height > 0 else { return 1.0 }
        return svgBounds.width / svgBounds.height
    }

    /// Width based on aspect ratio (scale mode)
    private var scaledWidth: CGFloat {
        size * svgAspectRatio
    }

    private var displayWidth: CGFloat {
        explicitWidth ?? scaledWidth
    }

    private var displayHeight: CGFloat {
        explicitHeight ?? size
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / svgBounds.width
            let scaleY = canvasSize.height / svgBounds.height
            let fitScale = min(scaleX, scaleY)

            let scaledW = svgBounds.width * fitScale
            let scaledH = svgBounds.height * fitScale
            let offsetX = (canvasSize.width - scaledW) / 2 - svgBounds.minX * fitScale
            let offsetY = (canvasSize.height - scaledH) / 2 - svgBounds.minY * fitScale

            var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            transform = transform.scaledBy(x: fitScale, y: fitScale)

            for cgPath in paths {
                if let transformedPath = cgPath.copy(using: &transform) {
                    let path = Path(transformedPath)
                    context.stroke(path, with: .color(.black), lineWidth: 2)
                }
            }
        }
        .frame(width: displayWidth, height: displayHeight)
        .opacity(0.6)
    }
}

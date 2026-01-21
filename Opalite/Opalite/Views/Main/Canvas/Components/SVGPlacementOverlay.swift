//
//  SVGPlacementOverlay.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CoreGraphics

/// Overlay view for SVG placement that manages its own gesture state
/// to avoid causing parent view re-renders during drag/pinch/rotate gestures.
struct SVGPlacementOverlay: View {
    /// The parsed SVG paths to display
    let paths: [CGPath]
    /// The bounds of the SVG for proper scaling
    let svgBounds: CGRect
    /// Callback when SVG is placed: (location, rotation, scale)
    let onPlace: (CGPoint, Angle, CGFloat) -> Void
    let onCancel: () -> Void

    // Local state - changes don't propagate to parent
    @State private var previewLocation: CGPoint?
    @State private var rotation: Angle = .zero
    @State private var scale: CGFloat = 1.0
    @State private var aspectRatio: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()

            // SVG preview at current location
            if let location = previewLocation {
                SVGPreviewView(paths: paths, svgBounds: svgBounds, scale: scale)
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
                useNonUniformScale: false,
                onTap: { _ in
                    // Use our tracked previewLocation instead of the tap location
                    // to ensure the shape is placed exactly where the preview was shown
                    guard let location = previewLocation else { return }
                    onPlace(location, rotation, scale)
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
            Text("Use two fingers to pinch and rotate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

// MARK: - SVG Preview View

/// Preview of an SVG shape during placement
struct SVGPreviewView: View {
    let paths: [CGPath]
    let svgBounds: CGRect
    var scale: CGFloat = 1.0

    /// Base size for the preview (height)
    private let baseSize: CGFloat = 100

    /// The actual size based on scale
    private var size: CGFloat {
        baseSize * scale
    }

    /// The aspect ratio of the SVG
    private var aspectRatio: CGFloat {
        guard svgBounds.height > 0 else { return 1.0 }
        return svgBounds.width / svgBounds.height
    }

    /// Width based on aspect ratio
    private var width: CGFloat {
        size * aspectRatio
    }

    var body: some View {
        Canvas { context, canvasSize in
            // Calculate transform to fit SVG into preview size
            let scaleX = canvasSize.width / svgBounds.width
            let scaleY = canvasSize.height / svgBounds.height
            let fitScale = min(scaleX, scaleY)

            // Center the SVG in the canvas
            let scaledWidth = svgBounds.width * fitScale
            let scaledHeight = svgBounds.height * fitScale
            let offsetX = (canvasSize.width - scaledWidth) / 2 - svgBounds.minX * fitScale
            let offsetY = (canvasSize.height - scaledHeight) / 2 - svgBounds.minY * fitScale

            var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            transform = transform.scaledBy(x: fitScale, y: fitScale)

            for cgPath in paths {
                if let transformedPath = cgPath.copy(using: &transform) {
                    let path = Path(transformedPath)
                    context.stroke(path, with: .color(.black), lineWidth: 2)
                }
            }
        }
        .frame(width: width, height: size)
        .opacity(0.6)
    }
}

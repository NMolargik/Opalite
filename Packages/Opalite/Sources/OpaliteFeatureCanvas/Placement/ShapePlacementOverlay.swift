//
//  ShapePlacementOverlay.swift
//  OpaliteFeatureCanvas
//
//  The drag-to-define overlay for shapes and imported SVGs: a dimmed canvas, a hover
//  ghost before the first touch, the live outline while sizing, a glass instruction pill,
//  and Place / Cancel. Touch handling is `ShapeDrawingView`; this is presentation.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct ShapePlacementOverlay: View {
    let subject: PlacementSubject
    /// Called with the rect in overlay (viewport) points and the rotation in radians.
    let onPlace: (CGRect, CGFloat) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: ShapePlacementPhase = .idle
    @State private var shapeRect: CGRect = .zero
    @State private var rotation: CGFloat = 0
    @State private var hoverLocation: CGPoint?
    @State private var placeAtCenterStamp = UUID()

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .accessibilityHidden(true)

            if phase == .idle, let hoverLocation {
                let ghost = ShapePlacementGeometry.defaultRect(centeredAt: hoverLocation, aspectRatio: subject.aspectRatio)
                ShapePreviewView(subject: subject, width: ghost.width, height: ghost.height, tint: .opalitePurple, dashed: true)
                    .opacity(0.6)
                    .position(x: ghost.midX, y: ghost.midY)
                    .allowsHitTesting(false)
            }

            if phase != .idle {
                ShapePreviewView(subject: subject, width: shapeRect.width, height: shapeRect.height, lineWidth: phase == .adjusting ? 2.5 : 2)
                    .rotationEffect(.radians(rotation))
                    .position(x: shapeRect.midX, y: shapeRect.midY)
                    .allowsHitTesting(false)
            }

            ShapeDrawingRepresentable(
                shapeRect: $shapeRect,
                rotation: $rotation,
                phase: $phase,
                hoverLocation: $hoverLocation,
                constrainedAspectRatio: subject.aspectRatio,
                placeAtCenterStamp: placeAtCenterStamp
            )
            .accessibilityAction(named: Text("Place at center")) {
                placeAtCenterStamp = UUID()
            }
        }
        .overlay(alignment: .top) { instructions.padding(.top, Brand.Space.sm).allowsHitTesting(false) }
        .overlay(alignment: .bottom) { actions.padding(.bottom, Brand.Space.xl) }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: phase)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .adjusting { Haptics.lightImpact() }
        }
    }

    // MARK: - Instructions

    private var instructions: some View {
        VStack(spacing: Brand.Space.xs) {
            Label(headline, systemImage: subject.systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            HStack(spacing: Brand.Space.md) {
                Text(detail)
                if phase != .idle {
                    Text("\(Int(shapeRect.width.rounded())) × \(Int(shapeRect.height.rounded()))")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                if phase == .adjusting, rotation != 0 {
                    Text("\(Int((rotation * 180 / .pi).rounded()))°")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.sm)
        .adaptiveGlassCapsule()
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch phase {
        case .idle: String(localized: "Drag to draw \(subject.title.lowercased())")
        case .drawing: String(localized: "Release to set the size")
        case .adjusting: String(localized: "Adjust \(subject.title.lowercased())")
        }
    }

    private var detail: String {
        switch phase {
        case .idle: String(localized: "Corner to corner, or tap for a default size")
        case .drawing: String(localized: "Sizing")
        case .adjusting: String(localized: "Drag to move · two fingers or Pencil Pro to rotate")
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: Brand.Space.md) {
            Button(role: .cancel) {
                onCancel()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
            }
            .glassActionButton(tint: .secondary, prominent: false)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("canvas.placement.cancel")

            if phase == .adjusting {
                Button {
                    onPlace(shapeRect, rotation)
                } label: {
                    Label("Place", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                }
                .glassActionButton(tint: .opalitePurple, prominent: true)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("canvas.placement.place")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .controlSize(.large)
    }
}
#endif

//
//  ShapeDrawingRepresentable.swift
//  Opalite
//
//  Created by Nick Molargik on 2/8/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// SwiftUI wrapper for `ShapeDrawingView` that bridges its gesture state
/// to SwiftUI bindings for the shape placement overlay.
struct ShapeDrawingRepresentable: UIViewRepresentable {
    @Binding var shapeRect: CGRect
    @Binding var rotation: CGFloat
    @Binding var phase: ShapePlacementPhase

    /// Locked aspect ratio passed through to the underlying view.
    var constrainedAspectRatio: CGFloat?

    func makeUIView(context: Context) -> ShapeDrawingView {
        let view = ShapeDrawingView()
        view.constrainedAspectRatio = constrainedAspectRatio
        view.onRectUpdate = { rect in
            shapeRect = rect
        }
        view.onPhaseChange = { newPhase in
            phase = newPhase
        }
        view.onRotationUpdate = { radians in
            rotation = radians
        }
        return view
    }

    func updateUIView(_ uiView: ShapeDrawingView, context: Context) {
        uiView.constrainedAspectRatio = constrainedAspectRatio

        // If parent resets phase to idle, reset the view
        if phase == .idle && uiView.phase != .idle {
            uiView.reset()
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct ShapeDrawingRepresentable: NSViewRepresentable {
    @Binding var shapeRect: CGRect
    @Binding var rotation: CGFloat
    @Binding var phase: ShapePlacementPhase

    var constrainedAspectRatio: CGFloat?

    func makeNSView(context: Context) -> ShapeDrawingView {
        let view = ShapeDrawingView()
        view.constrainedAspectRatio = constrainedAspectRatio
        view.onRectUpdate = { rect in
            shapeRect = rect
        }
        view.onPhaseChange = { newPhase in
            phase = newPhase
        }
        view.onRotationUpdate = { radians in
            rotation = radians
        }
        return view
    }

    func updateNSView(_ nsView: ShapeDrawingView, context: Context) {
        nsView.constrainedAspectRatio = constrainedAspectRatio
        if phase == .idle && nsView.phase != .idle {
            nsView.reset()
        }
    }
}
#endif

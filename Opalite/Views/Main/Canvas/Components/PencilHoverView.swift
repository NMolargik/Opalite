//
//  PencilHoverView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct PencilHoverView: UIViewRepresentable {
    @Binding var hoverLocation: CGPoint?
    @Binding var rollAngle: Angle
    @Binding var shapeScale: CGFloat
    @Binding var aspectRatio: CGFloat
    var useNonUniformScale: Bool = false
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> HoverDetectionView {
        let view = HoverDetectionView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.useNonUniformScale = useNonUniformScale
        view.onHoverUpdate = { [self] location, relativeAngle in
            hoverLocation = location
            if let angle = relativeAngle {
                rollAngle = Angle(radians: Double(angle))
            }
        }
        view.onHoverEnd = { [self] in
            hoverLocation = nil
        }
        view.onTap = { [self] location in
            onTap(location)
        }
        view.onScaleUpdate = { [self] scale in
            shapeScale = scale
        }
        view.onRotationUpdate = { [self] rotation in
            rollAngle = Angle(radians: Double(rotation))
        }
        view.onAspectRatioUpdate = { [self] ratio in
            aspectRatio = ratio
        }
        return view
    }

    func updateUIView(_ uiView: HoverDetectionView, context: Context) {
        // Update non-uniform scale mode if it changes
        uiView.useNonUniformScale = useNonUniformScale

        // Reset baseline when starting a new placement session
        if rollAngle == .zero && shapeScale == 1.0 && aspectRatio == 1.0 && uiView.baselineRollAngle != nil {
            uiView.resetBaseline()
        }
    }
}
#elseif canImport(AppKit)
import AppKit

// On macOS, we don't need Pencil support. Provide a no-op SwiftUI view
// that maintains the same API surface and compiles everywhere.
struct PencilHoverView: View {
    @Binding var hoverLocation: CGPoint?
    @Binding var rollAngle: Angle
    @Binding var shapeScale: CGFloat
    @Binding var aspectRatio: CGFloat
    var useNonUniformScale: Bool = false
    let onTap: (CGPoint) -> Void

    var body: some View {
        // Transparent, hit-testing view; forward simple click to onTap
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    TapGesture().onEnded {
                        // Use center point of the available rect as a reasonable default
                        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        onTap(center)
                    }
                )
                .onHover { isHovering in
                    if isHovering {
                        // We cannot get precise pointer location without NSViewRepresentable; leave nil
                        // Keep API consistent and no-op for macOS
                    } else {
                        hoverLocation = nil
                    }
                }
        }
    }
}

#endif

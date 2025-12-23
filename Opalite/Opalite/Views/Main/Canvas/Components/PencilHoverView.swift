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
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> HoverDetectionView {
        let view = HoverDetectionView()
        // Transparent background
        view.backgroundColor = .clear
        view.onHoverUpdate = { location, relativeAngle in
            DispatchQueue.main.async {
                self.hoverLocation = location
                if let angle = relativeAngle {
                    self.rollAngle = Angle(radians: Double(angle))
                }
            }
        }
        view.onHoverEnd = {
            DispatchQueue.main.async {
                self.hoverLocation = nil
            }
        }
        view.onTap = { location in
            self.onTap(location)
        }
        return view
    }

    func updateUIView(_ uiView: HoverDetectionView, context: Context) {
        // Reset baseline when rollAngle is reset to zero (new placement session)
        if rollAngle == .zero && uiView.baselineRollAngle != nil {
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


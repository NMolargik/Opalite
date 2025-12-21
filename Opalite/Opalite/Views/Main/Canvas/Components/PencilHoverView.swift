//
//  PencilHoverView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct PencilHoverView: UIViewRepresentable {
    @Binding var hoverLocation: CGPoint?
    @Binding var rollAngle: Angle
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> HoverDetectionView {
        let view = HoverDetectionView()
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

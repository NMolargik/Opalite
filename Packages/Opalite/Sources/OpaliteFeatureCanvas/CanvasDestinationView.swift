//
//  CanvasDestinationView.swift
//  OpaliteFeatureCanvas
//
//  Resolves a `CanvasDestination` pushed by the shell's NavigationStack.
//

import SwiftUI
import OpaliteCore

public struct CanvasDestinationView: View {
    private let destination: CanvasDestination

    public init(destination: CanvasDestination) {
        self.destination = destination
    }

    public var body: some View {
        switch destination {
        case .canvas(let id):
            CanvasView(canvasID: id)
        }
    }
}

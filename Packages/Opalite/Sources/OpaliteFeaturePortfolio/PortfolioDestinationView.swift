//
//  PortfolioDestinationView.swift
//  OpaliteFeaturePortfolio
//
//  Resolves a `PortfolioDestination` pushed onto the shell's NavigationStack. Canvases
//  are rendered by the shell (the Canvas feature), so `.canvas` is empty here.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore

public struct PortfolioDestinationView: View {
    private let destination: PortfolioDestination

    public init(destination: PortfolioDestination) {
        self.destination = destination
    }

    public var body: some View {
        switch destination {
        case .color(let id):
            // `.id` keeps a fresh screen (and view model) per color when the path is
            // replaced from one color to another (widget / Siri navigation).
            ColorDetailView(colorID: id)
                .id(id)
        case .palette(let id):
            PaletteDetailView(paletteID: id)
                .id(id)
        case .canvas:
            EmptyView()
        }
    }
}
#endif

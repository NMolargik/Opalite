//
//  TVDestinationView.swift
//  OpaliteFeatureTV
//
//  Resolves a `PortfolioDestination` pushed from any TV tab.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVDestinationView: View {
    let destination: PortfolioDestination

    var body: some View {
        switch destination {
        case .color(let id):
            TVColorDetailView(colorID: id)
        case .palette(let id):
            TVPaletteDetailView(paletteID: id)
        case .canvas:
            ContentUnavailableView(
                "Canvases Aren't Available on Apple TV",
                systemImage: "pencil.and.scribble",
                description: Text("Open this canvas on your iPhone, iPad, or Mac.")
            )
        }
    }
}
#endif

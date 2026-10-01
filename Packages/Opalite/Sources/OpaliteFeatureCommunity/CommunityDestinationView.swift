//
//  CommunityDestinationView.swift
//  OpaliteFeatureCommunity
//
//  Resolves a `CommunityDestination` pushed onto the shell's NavigationStack:
//
//      .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteFeatureShared

public struct CommunityDestinationView: View {
    let destination: CommunityDestination

    public init(destination: CommunityDestination) {
        self.destination = destination
    }

    public var body: some View {
        switch destination {
        case .color(let color):
            CommunityColorDetailView(color: color)
        case .palette(let palette):
            CommunityPaletteDetailView(palette: palette)
        case .publisher(let id, let displayName):
            CommunityPublisherProfileView(id: id, displayName: displayName)
        }
    }
}

#if DEBUG
#Preview("Destination: palette") {
    NavigationStack {
        CommunityDestinationView(destination: .palette(.sample))
            .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
    }
    .previewEnvironment()
}
#endif
#endif

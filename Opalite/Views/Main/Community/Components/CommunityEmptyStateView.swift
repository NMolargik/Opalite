//
//  CommunityEmptyStateView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

struct CommunityEmptyStateView: View {
    let segment: CommunitySegment

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: segment.icon)
        } description: {
            Text(description)
        } actions: {
            Text("Be the first to share!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch segment {
        case .colors:
            return "No Colors Yet"
        case .palettes:
            return "No Palettes Yet"
        }
    }

    private var description: String {
        switch segment {
        case .colors:
            return "The community hasn't shared any colors yet. Share your first color from the Portfolio tab!"
        case .palettes:
            return "The community hasn't shared any palettes yet. Share your first palette from the Portfolio tab!"
        }
    }
}

#Preview("Colors Empty") {
    CommunityEmptyStateView(segment: .colors)
}

#Preview("Palettes Empty") {
    CommunityEmptyStateView(segment: .palettes)
}

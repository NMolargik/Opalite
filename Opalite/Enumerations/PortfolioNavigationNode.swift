//
//  PortfolioNavigationNode.swift
//  Opalite
//
//  Created by Nick Molargik on 12/19/25.
//

import Foundation

enum PortfolioNavigationNode: Hashable, Identifiable {
    case palette(OpalitePalette)
    case color(OpaliteColor)

    var id: UUID {
        switch self {
        case .palette(let palette): palette.id
        case .color(let color): color.id
        }
    }
}

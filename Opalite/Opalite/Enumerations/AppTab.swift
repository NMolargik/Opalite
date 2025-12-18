//
//  AppTab.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case portfolio = "Portfolio"
    case canvas = "Canvas"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    func iconName() -> String {
        switch self {
        case .portfolio:
            return "paintpalette"
        case .canvas:
            return "pencil.and.scribble"
        case .settings:
            return "gear"
        }
    }
    
    @ViewBuilder
    func destinationView() -> some View {
        switch self {
        case .portfolio:
            PortfolioView()
                .navigationTitle(self.rawValue)
        case .canvas:
            CanvasView()
                .navigationTitle(self.rawValue)
        case .settings:
            SettingsView()
                .navigationTitle(self.rawValue)
        }
    }
}

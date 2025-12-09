//
//  ContentView-ViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

extension ContentView {
    @Observable
    class ViewModel {
        var appStage: AppStage = .splash
        
        var leadingTransition: AnyTransition {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
    }
}

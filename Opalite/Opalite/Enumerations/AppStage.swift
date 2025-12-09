//
//  AppStage.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import Foundation

enum AppStage: String, Identifiable {
    case splash
    case onboarding
    case main
    
    var id: String { self.rawValue }
}

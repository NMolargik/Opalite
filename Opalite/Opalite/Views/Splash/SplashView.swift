//
//  SplashView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct SplashView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack {
            Text("Splash Not Ready")
            
            Button("Skip") {
                HapticsManager.shared.selection()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
        }
        .background {
            SwatchStarfieldView(starCount: 15, totalDuration: 200)
        }
    }
}

#Preview {
    SplashView(
        onContinue: {}
    )
}

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
        Button("Splash") {
            HapticsManager.shared.selection()
            onContinue()
        }
    }
}

#Preview {
    SplashView(
        onContinue: {}
    )
}

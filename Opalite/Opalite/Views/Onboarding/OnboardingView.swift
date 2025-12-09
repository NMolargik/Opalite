//
//  OnboardingView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct OnboardingView: View {
    var onContinue: () -> Void

    var body: some View {
        Button("Continue") {
            onContinue()
        }
    }
}

#Preview {
    OnboardingView(
        onContinue: {}
    )
}

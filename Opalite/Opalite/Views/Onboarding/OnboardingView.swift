//
//  OnboardingView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false
    var onContinue: () -> Void

    var body: some View {
        VStack {
            Text("Onboarding Not Ready")
            
            Button("Skip") {
                HapticsManager.shared.selection()
                onContinue()
                isOnboardingComplete = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    OnboardingView(
        onContinue: {}
    )
}

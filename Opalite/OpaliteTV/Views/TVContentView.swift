//
//  TVContentView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Root view for OpaliteTV.
/// Shows syncing screen on launch, then transitions to main view.
struct TVContentView: View {
    @Environment(ColorManager.self) private var colorManager

    @State private var isSyncing: Bool = true

    var body: some View {
        ZStack {
            if isSyncing {
                TVSyncingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isSyncing = false
                    }
                }
                .transition(.opacity)
                .accessibilityIdentifier("tvSyncingView")
            } else {
                TVMainView()
                    .transition(.opacity)
                    .accessibilityIdentifier("tvMainView")
            }
        }
    }
}

#Preview {
    TVContentView()
}

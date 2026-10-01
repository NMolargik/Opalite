//
//  TVContentView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Root view for OpaliteTV. CloudKit hydration happens in the background via
/// the `NSPersistentStoreRemoteChange` observer in `OpaliteTVApp`, so the
/// portfolio populates as records arrive — no launch gate required.
struct TVContentView: View {
    var body: some View {
        TVMainView()
            .accessibilityIdentifier("tvMainView")
    }
}

#Preview {
    TVContentView()
}

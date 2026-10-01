//
//  TVRootHost.swift
//  OpaliteComposition
//
//  The tvOS app's root: the TV feature's UI with the session environment.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureTV

public struct TVRootHost: View {
    private let session: SessionController

    public init(session: SessionController) {
        self.session = session
    }

    public var body: some View {
        TVRootView()
            .sessionEnvironment(session)
            .task { session.start() }
    }
}
#endif

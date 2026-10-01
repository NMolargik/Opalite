//
//  SwatchBarScene.swift
//  OpaliteComposition
//
//  The SwatchBar's window content: the feature view with the session environment, sized
//  as a narrow tall panel. The app target declares the `WindowGroup(id:)` scene.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureSwatchBar

public enum SwatchBarScene {
    public static let windowID = "swatchBar"
    public static let defaultSize = CGSize(width: 280, height: 900)
}

public struct SwatchBarRootView: View {
    private let session: SessionController

    public init(session: SessionController) {
        self.session = session
    }

    public var body: some View {
        SwatchBarView()
            .sessionEnvironment(session)
            .onAppear { session.portfolio.refresh() }
    }
}
#endif

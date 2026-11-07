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
#if canImport(UIKit)
import UIKit
#endif

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
        if SwatchBarSupport.isAvailable {
            SwatchBarView()
                .sessionEnvironment(session)
                .onAppear { session.portfolio.refresh() }
        } else {
            // iPhone, including iPhone Duo: nothing in the app opens this window, but state
            // restoration can bring back a SwatchBar session that was opened before the
            // device lost the feature. Show the normal app in it and, when the main session
            // is also open, tear this one down so it does not come back again.
            RootView(session: session)
                #if os(iOS)
                .background(RestoredSceneCloser())
                #endif
        }
    }
}

#if os(iOS)
/// Destroys the scene session this view lands in, as long as another session stays open.
/// `dismissWindow` is a no-op where the system reports no multiple-window support (the
/// closed iPhone Duo), so this goes through UIKit's session API instead.
private struct RestoredSceneCloser: UIViewRepresentable {
    func makeUIView(context: Context) -> CloserView { CloserView() }
    func updateUIView(_ uiView: CloserView, context: Context) {}

    final class CloserView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let session = window?.windowScene?.session else { return }
            let application = UIApplication.shared
            guard application.openSessions.count > 1 else { return }
            application.requestSceneSessionDestruction(session, options: nil)
        }
    }
}
#endif
#endif

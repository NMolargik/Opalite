//
//  PreviewHelpers.swift
//  OpaliteFeaturePortfolio
//
//  Preview wiring for this module's screens: the shared in-memory graph plus the naming
//  service the color detail reads from the environment.
//

#if DEBUG && (os(iOS) || os(visionOS))
import SwiftUI
import OpaliteServices
import OpaliteFeatureShared

extension View {
    /// The shared preview graph plus a `ColorNameSuggestionService`.
    func portfolioPreviewEnvironment(hasOnyx: Bool = true, seeded: Bool = true) -> some View {
        previewEnvironment(hasOnyx: hasOnyx, seeded: seeded)
            .environment(ColorNameSuggestionService())
    }
}
#endif

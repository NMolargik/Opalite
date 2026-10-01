//
//  AppSeams.swift
//  Opalite
//
//  Production conformances for the Core seams whose framework types can't live in the
//  package: Spotlight indexing (AppEntity), intent donation (AppIntents), Siri's
//  on-screen awareness (entity identifiers on NSUserActivity), the App Shortcuts
//  vocabulary refresh, and the App Store review prompt (needs the window scene).
//

import AppIntents
import CoreSpotlight
import Foundation
import StoreKit
import UIKit
import OpaliteCore
import os

/// Indexes colors and palettes into Spotlight so the system can semantically search them.
struct SpotlightIndexer: PortfolioIndexing {
    nonisolated init() {}

    func reindex(colors: [OpaliteColor], palettes: [OpalitePalette]) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let colorEntities = colors.map(ColorEntity.init)
        let paletteEntities = palettes.map(PaletteEntity.init)
        Task.detached(priority: .utility) {
            do {
                let index = CSSearchableIndex.default()
                try await index.deleteAllSearchableItems()
                if !colorEntities.isEmpty { try await index.indexAppEntities(colorEntities) }
                if !paletteEntities.isEmpty { try await index.indexAppEntities(paletteEntities) }
                Log.spotlight.info("Indexed \(colorEntities.count) colors and \(paletteEntities.count) palettes")
            } catch {
                Log.spotlight.error("Spotlight indexing failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Donates intents so Siri can suggest them from the user's behavior.
struct IntentDonor: IntentDonating {
    nonisolated init() {}

    func donate(_ action: DonatableAction) {
        Task {
            do {
                switch action {
                case .createColor: _ = try await CreateColorIntent().donate()
                case .createPalette: _ = try await CreatePaletteIntent().donate()
                case .copyHex: _ = try await CopyColorHexIntent().donate()
                }
            } catch {
                Log.intents.error("Intent donation failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Tags detail-screen user activities with the entity identifier so Siri can resolve
/// "this color" / "this palette" from what's on screen.
struct EntityActivityAnnotator: EntityActivityAnnotating {
    nonisolated init() {}

    func annotateColor(_ activity: NSUserActivity, colorID: UUID) {
        guard #available(iOS 18.2, *) else { return }
        activity.appEntityIdentifier = EntityIdentifier(for: ColorEntity.self, identifier: colorID)
    }

    func annotatePalette(_ activity: NSUserActivity, paletteID: UUID) {
        guard #available(iOS 18.2, *) else { return }
        activity.appEntityIdentifier = EntityIdentifier(for: PaletteEntity.self, identifier: paletteID)
    }
}

/// Asks Siri to re-read the entity queries after names change so voice resolution stays
/// current ("Show Dusty Rose in Opalite").
struct ShortcutVocabularyUpdater: ShortcutVocabularyUpdating {
    nonisolated init() {}

    func updateAppShortcutParameters() {
        OpaliteShortcuts.updateAppShortcutParameters()
    }
}

/// Requests a review in the foreground window scene.
struct AppStoreReviewRequester: ReviewRequesting {
    nonisolated init() {}

    func requestReview() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let scene else { return }
        AppStore.requestReview(in: scene)
    }
}

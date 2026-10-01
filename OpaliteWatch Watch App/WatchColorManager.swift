//
//  WatchColorManager.swift
//  OpaliteWatch Watch App
//
//  The watch's view model: the mirrored portfolio, hex formatting per the user's
//  preference, deep-link routing from complications, and haptics.
//

import Foundation
import Observation
import WatchKit
import OpaliteCore

@MainActor
@Observable
final class WatchColorManager {
    let session: WatchSessionManager
    var pendingDeepLinkColorID: UUID?

    init(session: WatchSessionManager = WatchSessionManager()) {
        self.session = session
    }

    var colors: [WatchColor] { session.snapshot.colors.sorted { $0.createdAt > $1.createdAt } }
    var palettes: [WatchPalette] { session.snapshot.palettes.sorted { $0.createdAt > $1.createdAt } }
    var looseColors: [WatchColor] { session.snapshot.looseColors.sorted { $0.createdAt > $1.createdAt } }
    func colors(for palette: WatchPalette) -> [WatchColor] { session.snapshot.colors(in: palette) }
    var isPhoneReachable: Bool { session.isReachable }
    var isSyncing: Bool { session.isSyncing }
    var hasCachedData: Bool { session.hasCachedData }
    var lastSyncDate: Date? { session.lastSyncDate }

    var includeHexPrefix: Bool {
        get { HexFormat.stored(in: UserDefaults.standard).includesPrefix }
        set { HexFormat(includesPrefix: newValue).save(to: UserDefaults.standard) }
    }

    var highContrastEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKeys.watchHighContrastEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageKeys.watchHighContrastEnabled) }
    }

    func formattedHex(for color: WatchColor) -> String {
        HexFormat(includesPrefix: includeHexPrefix).format(color.hexString)
    }

    func start() {
        session.activate()
    }

    func refreshAll() async {
        let received = await session.refresh()
        if !received { playFailureHaptic() }
    }

    func handle(url: URL) {
        if case .color(let id) = DeepLink(url: url) { pendingDeepLinkColorID = id }
    }

    func copyHex(for color: WatchColor) {
        playTapHaptic()
        session.copyHexToPhone(formattedHex(for: color), colorName: color.name)
    }

    func playTapHaptic() { WKInterfaceDevice.current().play(.click) }
    func playSuccessHaptic() { WKInterfaceDevice.current().play(.success) }
    func playFailureHaptic() { WKInterfaceDevice.current().play(.failure) }
    func playNavigationHaptic() { WKInterfaceDevice.current().play(.directionUp) }
}

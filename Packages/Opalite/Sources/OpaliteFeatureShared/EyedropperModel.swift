//
//  EyedropperModel.swift
//  OpaliteFeatureShared
//
//  Mac Catalyst only: the global-hotkey eyedropper. The hotkey (a design-system preference,
//  registered through `GlobalHotkey`) starts the system color sampler, which brings its own
//  magnifier loupe; the pick is saved to the portfolio, auto-copied in the preferred format
//  with a toast, and handed to `onPicked` so the shell can surface the SwatchBar unless the
//  user asked to keep it hidden.
//

#if targetEnvironment(macCatalyst)
import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices

@MainActor
@Observable
public final class EyedropperModel {
    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private let portfolio: PortfolioModel
    @ObservationIgnored private let hexCopy: HexCopyModel
    @ObservationIgnored private let hotkey = GlobalHotkey()

    /// Called after a successful pick with the color; the shell opens the SwatchBar here
    /// unless `keepsSwatchBarHidden`.
    @ObservationIgnored public var onPicked: (@MainActor (RGBA) -> Void)?

    public private(set) var isPicking = false
    /// False when the OS refused the hotkey (another app owns it, or Carbon was unavailable).
    public private(set) var hotkeyRegistered = false

    public init(defaults: any KeyValueStoring = UserDefaults.standard, portfolio: PortfolioModel, hexCopy: HexCopyModel) {
        self.defaults = defaults
        self.portfolio = portfolio
        self.hexCopy = hexCopy
    }

    public var keepsSwatchBarHidden: Bool { EyedropperPreferences.keepsSwatchBarHidden(in: defaults) }

    /// (Re)registers the stored hotkey; call at launch and whenever the preference changes.
    public func refreshHotkey() {
        let choice = EyedropperHotkey.stored(in: defaults)
        hotkeyRegistered = hotkey.register(choice) { [weak self] in
            Task { await self?.pick() }
        }
    }

    /// Runs one pick: sample, save, auto-copy, notify.
    public func pick() async {
        guard !isPicking else { return }
        isPicking = true
        defer { isPicking = false }
        guard let rgba = await SystemColorSampler.sample() else { return }
        portfolio.createColor(rgba)
        if EyedropperPreferences.autoCopies(in: defaults) {
            let text = EyedropperCopyFormat.stored(in: defaults).string(for: rgba, hexFormat: hexCopy.format)
            hexCopy.copy(text: text, label: text)
        }
        onPicked?(rgba)
    }
}
#endif

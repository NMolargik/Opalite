//
//  HexCopyModel.swift
//  OpaliteFeatureShared
//
//  Copies hex codes per the user's "#" preference. The first copy asks which form they
//  want; afterwards it copies straight away, toasts, and lets Siri learn the action.
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem

@MainActor
@Observable
public final class HexCopyModel {
    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private let pasteboard: any Pasteboarding
    @ObservationIgnored private let toastManager: ToastManager
    @ObservationIgnored private let donor: (any IntentDonating)?

    /// Whether the first-time preference question is showing.
    public var isAskingPreference = false
    /// The hex waiting on the preference answer.
    public private(set) var pendingHex: String?

    public init(defaults: any KeyValueStoring = UserDefaults.standard, pasteboard: any Pasteboarding, toastManager: ToastManager, donor: (any IntentDonating)? = nil) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        self.toastManager = toastManager
        self.donor = donor
    }

    public var format: HexFormat {
        get { HexFormat.stored(in: defaults) }
        set { newValue.save(to: defaults) }
    }

    public var includesPrefix: Bool {
        get { format.includesPrefix }
        set { format = HexFormat(includesPrefix: newValue) }
    }

    private var hasAskedPreference: Bool {
        get { defaults.bool(forKey: AppStorageKeys.hasAskedHexPreference) }
        set { defaults.set(newValue, forKey: AppStorageKeys.hasAskedHexPreference) }
    }

    /// The hex as it would be copied.
    public func formatted(_ hex: String) -> String { format.format(hex) }
    public func formatted(_ color: OpaliteColor) -> String { formatted(color.hexString) }

    /// Copies the color's hex, asking the preference question the first time.
    public func copyHex(for color: OpaliteColor) { copy(hex: color.hexString) }

    public func copy(hex: String) {
        if hasAskedPreference {
            perform(hex)
        } else {
            pendingHex = hex
            isAskingPreference = true
        }
    }

    /// Answers the first-time question and completes the pending copy.
    public func choosePrefix(_ include: Bool) {
        hasAskedPreference = true
        includesPrefix = include
        isAskingPreference = false
        if let hex = pendingHex {
            pendingHex = nil
            perform(hex)
        }
    }

    private func perform(_ hex: String) {
        let text = formatted(hex)
        pasteboard.copy(string: text)
        Haptics.lightImpact()
        toastManager.showSuccess(String(localized: "Copied \(text)"), systemImage: "doc.on.doc.fill")
        donor?.donate(.copyHex)
    }

    /// Copies arbitrary text (RGB, HSL, code snippets) with a toast.
    public func copy(text: String, label: String) {
        pasteboard.copy(string: text)
        Haptics.lightImpact()
        toastManager.showSuccess(String(localized: "Copied \(label)"), systemImage: "doc.on.doc.fill")
    }
}

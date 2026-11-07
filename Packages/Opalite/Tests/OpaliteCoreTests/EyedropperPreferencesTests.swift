import Testing
@testable import OpaliteCore

@Suite struct EyedropperPreferencesTests {
    @Test func defaults() {
        let store = FakeKeyValueStore()
        #expect(EyedropperHotkey.stored(in: store) == .controlOptionC)
        #expect(EyedropperCopyFormat.stored(in: store) == .hex)
        #expect(EyedropperPreferences.autoCopies(in: store))
        #expect(!EyedropperPreferences.keepsSwatchBarHidden(in: store))
    }

    @Test func storedValuesAndGarbage() {
        let store = FakeKeyValueStore()
        store.set("controlShiftC", forKey: AppStorageKeys.eyedropperHotkey)
        store.set("oklch", forKey: AppStorageKeys.eyedropperCopyFormat)
        store.set(false, forKey: AppStorageKeys.eyedropperAutoCopy)
        store.set(true, forKey: AppStorageKeys.eyedropperKeepSwatchBarHidden)
        #expect(EyedropperHotkey.stored(in: store) == .controlShiftC)
        #expect(EyedropperCopyFormat.stored(in: store) == .oklch)
        #expect(!EyedropperPreferences.autoCopies(in: store))
        #expect(EyedropperPreferences.keepsSwatchBarHidden(in: store))
        store.set("nonsense", forKey: AppStorageKeys.eyedropperHotkey)
        #expect(EyedropperHotkey.stored(in: store) == .default)
    }

    @Test func hotkeyCodes() {
        #expect(EyedropperHotkey.controlOptionC.keyCode == 8)
        #expect(EyedropperHotkey.controlOptionC.carbonModifiers == 6144)
        #expect(EyedropperHotkey.off.keyCode == nil)
        #expect(Set(EyedropperHotkey.allCases.filter { $0 != .off }.map { "\($0.keyCode!)-\($0.carbonModifiers)" }).count == 5)
    }

    @Test func copyFormats() {
        let color = RGBA(hex: "#FF0000")!
        #expect(EyedropperCopyFormat.hex.string(for: color, hexFormat: HexFormat(includesPrefix: false)) == "FF0000")
        #expect(EyedropperCopyFormat.hex.string(for: color, hexFormat: HexFormat(includesPrefix: true)) == "#FF0000")
        #expect(EyedropperCopyFormat.rgb.string(for: color, hexFormat: HexFormat(includesPrefix: true)) == "rgb(255, 0, 0)")
        #expect(EyedropperCopyFormat.oklch.string(for: color, hexFormat: HexFormat(includesPrefix: true)).hasPrefix("oklch("))
        #expect(EyedropperCopyFormat.displayP3.string(for: color, hexFormat: HexFormat(includesPrefix: true)).hasPrefix("color(display-p3"))
    }
}

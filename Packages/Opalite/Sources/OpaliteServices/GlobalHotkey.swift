//
//  GlobalHotkey.swift
//  OpaliteServices
//
//  A system-wide keyboard shortcut on Mac Catalyst. Carbon's RegisterEventHotKey needs no
//  Accessibility permission and no third-party package, but Carbon isn't importable from
//  Catalyst code, so the symbols are looked up with dlopen/dlsym (the same trick the
//  eyedropper uses for AppKit). Everything degrades to "no hotkey" if a symbol is missing.
//

#if targetEnvironment(macCatalyst)
import Foundation
import OpaliteCore
import os

@MainActor
public final class GlobalHotkey {
    // C structs aren't expressible in @convention(c) signatures from Swift, so they travel as
    // layout-identical values: EventTypeSpec as a pointer to two UInt32s (class, kind) and
    // EventHotKeyID (two UInt32s, passed by value) as one little-endian UInt64.
    private typealias GetTarget = @convention(c) () -> OpaquePointer?
    private typealias Handler = @convention(c) (OpaquePointer?, OpaquePointer?, UnsafeMutableRawPointer?) -> Int32
    private typealias InstallHandler = @convention(c) (OpaquePointer?, Handler, UInt, UnsafePointer<UInt32>, UnsafeMutableRawPointer?, UnsafeMutablePointer<OpaquePointer?>?) -> Int32
    private typealias Register = @convention(c) (UInt32, UInt32, UInt64, OpaquePointer?, UInt32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32
    private typealias Unregister = @convention(c) (OpaquePointer?) -> Int32

    private static let signature: UInt32 = 0x4F504C54 // 'OPLT'
    /// The active instance the C callback forwards to (only one hotkey is ever registered).
    nonisolated(unsafe) private static var active: GlobalHotkey?

    private var hotKeyRef: OpaquePointer?
    private var handlerInstalled = false
    private var onPress: (@MainActor () -> Void)?

    public init() {}

    /// Registers `hotkey` (replacing any previous one). Returns false when unavailable or off.
    @discardableResult
    public func register(_ hotkey: EyedropperHotkey, onPress: @escaping @MainActor () -> Void) -> Bool {
        unregister()
        guard let keyCode = hotkey.keyCode else { return false }
        guard let carbon = dlopen("/System/Library/Frameworks/Carbon.framework/Carbon", RTLD_NOW),
              let targetSym = dlsym(carbon, "GetApplicationEventTarget"),
              let installSym = dlsym(carbon, "InstallEventHandler"),
              let registerSym = dlsym(carbon, "RegisterEventHotKey") else {
            Log.app.error("Carbon hotkey symbols unavailable")
            return false
        }
        let target = unsafeBitCast(targetSym, to: GetTarget.self)()
        if !handlerInstalled {
            let spec: [UInt32] = [0x6B657962 /* 'keyb' */, 5 /* kEventHotKeyPressed */]
            let handler: Handler = { _, _, _ in
                Task { @MainActor in GlobalHotkey.active?.onPress?() }
                return 0
            }
            let status = unsafeBitCast(installSym, to: InstallHandler.self)(target, handler, 1, spec, nil, nil)
            guard status == 0 else {
                Log.app.error("InstallEventHandler failed: \(status)")
                return false
            }
            handlerInstalled = true
        }
        var ref: OpaquePointer?
        let status = unsafeBitCast(registerSym, to: Register.self)(
            keyCode, hotkey.carbonModifiers, (UInt64(1) << 32) | UInt64(Self.signature), target, 0, &ref
        )
        guard status == 0, ref != nil else {
            Log.app.error("RegisterEventHotKey failed: \(status)")
            return false
        }
        hotKeyRef = ref
        self.onPress = onPress
        Self.active = self
        return true
    }

    public func unregister() {
        if let ref = hotKeyRef,
           let carbon = dlopen("/System/Library/Frameworks/Carbon.framework/Carbon", RTLD_NOW),
           let sym = dlsym(carbon, "UnregisterEventHotKey") {
            _ = unsafeBitCast(sym, to: Unregister.self)(ref)
        }
        hotKeyRef = nil
        onPress = nil
        if Self.active === self { Self.active = nil }
    }
}
#endif

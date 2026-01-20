//
//  StatusMenuController.swift
//  StatusMenuBundle
//
//  AppKit-based status menu controller for macOS menu bar icon.
//  Loaded as a plugin bundle by the Mac Catalyst app.
//

import AppKit

/// Controls the macOS menu bar status item for Opalite.
/// This class runs in a pure AppKit bundle and communicates with the
/// Mac Catalyst app via callbacks and distributed notifications.
@objc public class StatusMenuController: NSObject {

    // MARK: - Singleton

    @objc public static let shared = StatusMenuController()

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var openSwatchBarHandler: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Sets up the status menu with the provided handler for opening SwatchBar.
    /// - Parameter handler: Closure called when "Open SwatchBar" is selected.
    @objc public func setup(openSwatchBarHandler handler: @escaping () -> Void) {
        self.openSwatchBarHandler = handler
        createStatusItem()
    }

    // MARK: - Status Item Setup

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            return
        }

        // Use the swatchpalette.fill SF Symbol
        if let image = NSImage(systemSymbolName: "swatchpalette.fill", accessibilityDescription: "Open SwatchBar") {
            image.isTemplate = true
            button.image = image
        }

        // Set up direct click action (no menu)
        button.action = #selector(openSwatchBarAction)
        button.target = self
    }

    // MARK: - Actions

    @objc private func openSwatchBarAction() {
        openSwatchBarHandler?()
    }
}

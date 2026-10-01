//
//  OpaliteCommands.swift
//  Opalite
//
//  Menu-bar / hardware-keyboard commands (iPadOS 26+ menu bar and Mac Catalyst). Every
//  action goes through the same `AppRouter` / shared models the app uses for widgets,
//  quick actions, and App Intents, so every entry point behaves identically.
//

import SwiftUI
import OpaliteComposition
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct OpaliteCommands: Commands {
    let session: SessionController

    @Environment(\.openWindow) private var openWindow

    private var router: AppRouter { session.router }
    private var portfolio: PortfolioModel { session.portfolio }
    private var canvases: CanvasModel { session.canvases }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Color") { router.open(.createColor) }
                .keyboardShortcut("n", modifiers: .command)
            Button("New Palette") { router.open(.createPalette) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("New Canvas") {
                router.select(.canvas)
                _ = canvases.createCanvas()
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            Divider()
            Button("Sample Photo…") { router.open(.samplePhoto) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Divider()
            Button("Show SwatchBar") { openWindow(id: SwatchBarScene.windowID) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Refresh") {
                portfolio.refresh()
                canvases.refresh()
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        CommandMenu(Text("Go", comment: "Menu title for navigation commands")) {
            ForEach(AppTab.available) { tab in
                Button(tab.title) { router.select(tab) }
                    .keyboardShortcut(KeyEquivalent(Character(String(tab.keyboardNumber))), modifiers: .command)
            }
            Divider()
            Button("Onyx") { router.open(.onyx) }
        }

        CommandMenu(Text("Color", comment: "Menu title for the active color's actions")) {
            Button("Copy Hex") {
                if let color = portfolio.activeColor { session.hexCopy.copyHex(for: color) }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(portfolio.activeColor == nil)

            Button("Edit Color…") { portfolio.pendingCommand = .editActiveColor }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(portfolio.activeColor == nil)

            Button("Move to Palette…") { portfolio.pendingCommand = .moveActiveColorToPalette }
                .disabled(portfolio.activeColor == nil)

            Button("Remove from Palette") { portfolio.pendingCommand = .removeActiveColorFromPalette }
                .disabled(portfolio.activeColor?.palette == nil)

            Divider()

            Button("Rename Palette…") { portfolio.pendingCommand = .renameActivePalette }
                .disabled(portfolio.activePalette == nil)
        }

        CommandMenu(Text("Canvas", comment: "Menu title for canvas actions")) {
            ForEach(CanvasShape.allCases.filter { $0.keyboardNumber != nil }) { shape in
                Button {
                    canvases.pendingShape = shape
                } label: {
                    Label(shape.displayName, systemImage: shape.systemImage)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(shape.keyboardNumber ?? 0))), modifiers: [.command, .shift])
            }
        }

        CommandGroup(replacing: .help) {
            Link("Opalite Website", destination: URL(string: "https://www.molargiksoftware.com")!)
        }
    }
}

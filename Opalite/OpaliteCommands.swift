//
//  OpaliteCommands.swift
//  Opalite
//
//  Extracted from OpaliteApp.swift — all macOS/iPadOS menu bar commands.
//

import SwiftUI

@MainActor
struct OpaliteCommands: Commands {
    let colorManager: ColorManager
    let canvasManager: CanvasManager
    let subscriptionManager: SubscriptionManager
    let toastManager: ToastManager
    let quickActionManager: QuickActionManager
    let hexCopyManager: HexCopyManager
    let reviewRequestManager: ReviewRequestManager

    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppStorageKeys.paletteOrder) private var paletteOrderData: Data = Data()

    var body: some Commands {
        // Replace the New Item command group (Cmd+N)
        CommandGroup(replacing: .newItem) {
            Button {
                createNewColor()
            } label: {
                Label("New Color", systemImage: "paintpalette.fill")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button {
                createNewPalette()
            } label: {
                Label("New Palette", systemImage: "swatchpalette.fill")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button {
                createNewCanvas()
            } label: {
                Label("New Canvas", systemImage: "pencil.and.outline")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Divider()
        }

        // Add to the existing View menu
        CommandGroup(after: .toolbar) {
            Divider()

            Button {
                HapticsManager.shared.selection()
                #if os(iOS)
                AppDelegate.openSwatchBarWindow()
                #else
                openWindow(id: "swatchBar")
                #endif
            } label: {
                Label("SwatchBar", systemImage: "square.stack.fill")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button {
                HapticsManager.shared.selection()
                Task {
                    await colorManager.refreshAll()
                    await canvasManager.refreshAll()
                }
            } label: {
                Label("Refresh All", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        // Portfolio Menu
        CommandMenu("Portfolio") {
            Section("Colors") {
                Button {
                    createNewColor()
                } label: {
                    Label("New Color", systemImage: "paintpalette.fill")
                }

                Button {
                    Task { await colorManager.refreshAll() }
                } label: {
                    Label("Refresh Colors", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            Section("Palettes") {
                Button {
                    createNewPalette()
                } label: {
                    Label("New Palette", systemImage: "swatchpalette.fill")
                }
            }

            Divider()

            // Active Color Actions (only enabled when viewing a color detail)
            Section("Active Color") {
                Button {
                    HapticsManager.shared.selection()
                    if let color = colorManager.activeColor {
                        hexCopyManager.copyHex(for: color)
                    }
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }
                .disabled(colorManager.activeColor == nil)
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button {
                    HapticsManager.shared.selection()
                    colorManager.editColorTrigger = UUID()
                } label: {
                    Label("Edit Color", systemImage: "slider.horizontal.3")
                }
                .disabled(colorManager.activeColor == nil)
                .keyboardShortcut("e", modifiers: .command)

                Button {
                    HapticsManager.shared.selection()
                    colorManager.addToPaletteTrigger = UUID()
                } label: {
                    Label("Move To Palette", systemImage: "swatchpalette")
                }
                .disabled(colorManager.activeColor == nil || colorManager.activeColor?.palette != nil)

                Button {
                    HapticsManager.shared.selection()
                    colorManager.removeFromPaletteTrigger = UUID()
                } label: {
                    Label("Remove from Palette", systemImage: "minus.circle")
                }
                .disabled(colorManager.activeColor == nil || colorManager.activeColor?.palette == nil)
            }

            Divider()

            // Active Palette Actions (only enabled when viewing a palette detail)
            Section("Active Palette") {
                Button {
                    HapticsManager.shared.selection()
                    colorManager.renamePaletteTrigger = UUID()
                } label: {
                    Label("Rename Palette", systemImage: "character.cursor.ibeam")
                }
                .disabled(colorManager.activePalette == nil)
            }
        }

        // Canvas Menu
        CommandMenu("Canvas") {
            Button {
                createNewCanvas()
            } label: {
                Label("New Canvas", systemImage: "pencil.and.outline")
            }

            Button {
                Task { await canvasManager.refreshAll() }
            } label: {
                Label("Refresh Canvases", systemImage: "arrow.clockwise")
            }

            Divider()

            Section("Shapes") {
                Button {
                    HapticsManager.shared.selection()
                    canvasManager.pendingShape = .square
                } label: {
                    Label("Square", systemImage: "square")
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button {
                    HapticsManager.shared.selection()
                    canvasManager.pendingShape = .circle
                } label: {
                    Label("Circle", systemImage: "circle")
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button {
                    HapticsManager.shared.selection()
                    canvasManager.pendingShape = .triangle
                } label: {
                    Label("Triangle", systemImage: "triangle")
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])

                Button {
                    HapticsManager.shared.selection()
                    canvasManager.pendingShape = .line
                } label: {
                    Label("Line", systemImage: "line.diagonal")
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])

                Button {
                    HapticsManager.shared.selection()
                    canvasManager.pendingShape = .arrow
                } label: {
                    Label("Arrow", systemImage: "arrow.right")
                }
                .keyboardShortcut("5", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Shared Actions

    private func createNewColor() {
        HapticsManager.shared.selection()
        if !colorManager.isMainWindowOpen {
            openWindow(id: "main")
        }
        quickActionManager.requestCreateNewColor()
    }

    private func createNewPalette() {
        HapticsManager.shared.selection()
        if !colorManager.isMainWindowOpen {
            openWindow(id: "main")
        }
        if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
            withAnimation {
                do {
                    let newPalette = try colorManager.createPalette(name: "New Palette")
                    prependPaletteToOrder(newPalette.id)
                    OpaliteTipActions.advanceTipsAfterContentCreation()
                    reviewRequestManager.evaluateReviewRequest(
                        colorCount: colorManager.colors.count,
                        paletteCount: colorManager.palettes.count
                    )
                } catch {
                    toastManager.show(error: .paletteCreationFailed)
                }
            }
        } else {
            quickActionManager.requestPaywall(context: "Creating more palettes requires Onyx")
        }
    }

    private func createNewCanvas() {
        HapticsManager.shared.selection()
        if !colorManager.isMainWindowOpen {
            openWindow(id: "main")
        }
        if subscriptionManager.canCreateCanvas(currentCount: canvasManager.canvases.count) {
            do {
                let newCanvas = try canvasManager.createCanvas()
                canvasManager.pendingCanvasToOpen = newCanvas
            } catch {
                toastManager.show(error: .canvasCreationFailed)
            }
        } else {
            quickActionManager.requestPaywall(context: "Unlimited canvases require Onyx")
        }
    }

    private func prependPaletteToOrder(_ paletteID: UUID) {
        var currentOrder: [UUID] = []
        if !paletteOrderData.isEmpty,
           let decoded = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) {
            currentOrder = decoded
        }
        currentOrder.removeAll { $0 == paletteID }
        currentOrder.insert(paletteID, at: 0)
        if let encoded = try? JSONEncoder().encode(currentOrder) {
            paletteOrderData = encoded
        }
    }
}

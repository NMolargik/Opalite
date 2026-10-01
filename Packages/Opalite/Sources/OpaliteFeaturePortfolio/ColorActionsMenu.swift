//
//  ColorActionsMenu.swift
//  OpaliteFeaturePortfolio
//
//  The actions every swatch offers from its menu / context menu: copy, rename, move,
//  remove from palette, export, publish, delete. The owner decides what each does.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct ColorActionsMenu: View {
    @Environment(HexCopyModel.self) private var hexCopy

    let color: OpaliteColor
    var onRename: (() -> Void)?
    var onMove: (() -> Void)?
    var onRemoveFromPalette: (() -> Void)?
    var onExport: (() -> Void)?
    var onPublish: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Button {
            Haptics.selection()
            hexCopy.copyHex(for: color)
        } label: {
            Label("Copy Hex", systemImage: "number")
        }

        if let onRename {
            Button {
                Haptics.selection()
                onRename()
            } label: {
                Label("Rename…", systemImage: "character.cursor.ibeam")
            }
        }

        if let onMove {
            Button {
                Haptics.selection()
                onMove()
            } label: {
                Label(color.palette == nil ? "Add to Palette…" : "Move to Palette…", systemImage: "swatchpalette")
            }
        }

        if color.palette != nil, let onRemoveFromPalette {
            Button {
                Haptics.selection()
                onRemoveFromPalette()
            } label: {
                Label("Remove from Palette", systemImage: "minus.circle")
            }
        }

        if onExport != nil || onPublish != nil {
            Divider()
            if let onExport {
                Button {
                    Haptics.selection()
                    onExport()
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
            }
            if let onPublish {
                Button {
                    Haptics.selection()
                    onPublish()
                } label: {
                    Label("Publish to Community…", systemImage: "person.2")
                }
            }
        }

        if let onDelete {
            Divider()
            Button(role: .destructive) {
                Haptics.selection()
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
#endif

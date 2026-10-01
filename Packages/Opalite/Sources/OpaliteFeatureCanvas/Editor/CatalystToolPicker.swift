//
//  CatalystToolPicker.swift
//  OpaliteFeatureCanvas
//
//  Mac Catalyst's drawing tools: `PKToolPicker` is unreliable there, so the editor shows a
//  compact glass strip — ink types, erasers, stroke width — driving `externalTool`.
//

#if canImport(PencilKit) && os(iOS) && targetEnvironment(macCatalyst)
import SwiftUI
import UIKit
import PencilKit
import OpaliteCore
import OpaliteDesignSystem

struct CatalystToolPicker: View {
    let inkColor: RGBA
    let onSelect: (PKTool) -> Void

    @State private var inkType: PKInkingTool.InkType = .pen
    @State private var width: CGFloat = 4
    @State private var isErasing = false

    private static let inks: [(type: PKInkingTool.InkType, name: String, symbol: String)] = [
        (.pen, String(localized: "Pen"), "pencil.tip"),
        (.pencil, String(localized: "Pencil"), "pencil"),
        (.marker, String(localized: "Marker"), "highlighter"),
        (.monoline, String(localized: "Monoline"), "line.diagonal"),
        (.fountainPen, String(localized: "Fountain Pen"), "paintbrush.pointed"),
        (.watercolor, String(localized: "Watercolor"), "drop"),
        (.crayon, String(localized: "Crayon"), "scribble"),
    ]
    private static let widths: [CGFloat] = [1, 2, 4, 8, 12, 20]

    var body: some View {
        HStack(spacing: Brand.Space.xs) {
            ForEach(Self.inks, id: \.type) { ink in
                toolButton(ink.name, symbol: ink.symbol, isSelected: !isErasing && inkType == ink.type) {
                    inkType = ink.type
                    isErasing = false
                    emit()
                }
            }
            Divider().frame(height: 20)
            toolButton(String(localized: "Pixel Eraser"), symbol: "eraser", isSelected: isErasing) {
                isErasing = true
                onSelect(PKEraserTool(.bitmap, width: width))
            }
            toolButton(String(localized: "Object Eraser"), symbol: "eraser.line.dashed", isSelected: false) {
                isErasing = true
                onSelect(PKEraserTool(.vector))
            }
            Divider().frame(height: 20)
            Menu {
                ForEach(Self.widths, id: \.self) { candidate in
                    Button {
                        width = candidate
                        emit()
                    } label: {
                        Label("\(Int(candidate)) pt", systemImage: width == candidate ? "checkmark" : "circle.fill")
                    }
                }
            } label: {
                Label("Stroke Width", systemImage: "lineweight")
                    .labelStyle(.iconOnly)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(Text("Stroke width, \(Int(width)) points"))
        }
        .padding(.horizontal, Brand.Space.sm)
        .padding(.vertical, Brand.Space.xs)
        .adaptiveGlassCapsule()
        .onChange(of: inkColor) { emit() }
    }

    private func toolButton(_ name: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, height: 32)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(Circle().fill(isSelected ? Color.opalitePurple : Color.clear))
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func emit() {
        guard !isErasing else {
            onSelect(PKEraserTool(.bitmap, width: width))
            return
        }
        onSelect(PKInkingTool(inkType, color: inkColor.uiColor, width: width))
    }
}
#endif

//
//  MacCatalystToolPicker.swift
//  Opalite
//
//  Created by Nick Molargik on 1/1/26.
//

import SwiftUI
import PencilKit

#if targetEnvironment(macCatalyst)
/// A custom tool picker for Mac Catalyst since PKToolPicker doesn't reliably show
struct MacCatalystToolPicker: View {
    @Binding var selectedTool: PKTool
    @Binding var selectedColor: UIColor
    @Binding var strokeWidth: CGFloat

    @State private var showingWidthSlider = false

    private let tools: [(name: String, icon: String, tool: PKInkingTool.InkType)] = [
        ("Pen", "pencil.tip", .pen),
        ("Pencil", "pencil", .pencil),
        ("Marker", "highlighter", .marker)
    ]

    private let widths: [CGFloat] = [1, 2, 4, 6, 8, 12, 16, 24]

    var body: some View {
        HStack(spacing: 12) {
            // Drawing tools
            ForEach(tools, id: \.name) { tool in
                Button {
                    HapticsManager.shared.selection()
                    selectedTool = PKInkingTool(tool.tool, color: selectedColor, width: strokeWidth)
                } label: {
                    Image(systemName: tool.icon)
                        .font(.title2)
                        .foregroundStyle(isToolSelected(tool.tool) ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isToolSelected(tool.tool) ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(tool.name)
            }

            Divider()
                .frame(height: 30)

            // Eraser
            Button {
                HapticsManager.shared.selection()
                selectedTool = PKEraserTool(.bitmap, width: strokeWidth)
            } label: {
                Image(systemName: "eraser")
                    .font(.title2)
                    .foregroundStyle(selectedTool is PKEraserTool ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTool is PKEraserTool ? Color.accentColor : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Eraser")

            Divider()
                .frame(height: 30)

            // Stroke width
            Menu {
                ForEach(widths, id: \.self) { width in
                    Button {
                        HapticsManager.shared.selection()
                        strokeWidth = width
                        if let inkTool = selectedTool as? PKInkingTool {
                            selectedTool = PKInkingTool(inkTool.inkType, color: selectedColor, width: width)
                        } else if selectedTool is PKEraserTool {
                            selectedTool = PKEraserTool(.bitmap, width: width)
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: width, height: width)
                            Text("\(Int(width))pt")
                            if strokeWidth == width {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "lineweight")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }
            .menuStyle(.borderlessButton)
            .help("Stroke Width: \(Int(strokeWidth))pt")

            Divider()
                .frame(height: 30)

            // Color indicator (color selection is handled by CanvasSwatchPickerView)
            Circle()
                .fill(Color(selectedColor))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .help("Current Color")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func isToolSelected(_ inkType: PKInkingTool.InkType) -> Bool {
        guard let inkTool = selectedTool as? PKInkingTool else { return false }
        return inkTool.inkType == inkType
    }
}

#Preview {
    MacCatalystToolPicker(
        selectedTool: .constant(PKInkingTool(.pen, color: .black, width: 4)),
        selectedColor: .constant(.black),
        strokeWidth: .constant(4)
    )
    .padding()
}
#endif

//
//  GridPickerView.swift
//  OpaliteFeatureColorEditor
//
//  Mode 2: the named swatch grid — a grayscale row, then one hue per column with a tone
//  per row. The hovered or selected cell's name reads out beneath the grid.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct GridPickerView: View {
    let viewModel: ColorEditorViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered: GridPalette.Cell?

    private let cells = GridPalette.cells
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 3), count: GridPalette.columns) }
    private var selected: GridPalette.Cell? { GridPalette.cell(matching: viewModel.rgba) }
    private var captionCell: GridPalette.Cell? { hovered ?? selected }

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(cells) { cell in
                    cellView(cell, isSelected: cell.id == selected?.id)
                }
            }
            .padding(6)
            .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Color grid"))

            HStack(spacing: Brand.Space.sm) {
                if let cell = captionCell {
                    ColorChip(cell.rgba, size: 22, cornerRadius: 6)
                    Text(cell.name)
                        .font(.subheadline.weight(.medium))
                        .contentTransition(.opacity)
                    Text(cell.rgba.hexString)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.secondary)
                    Text("Tap a swatch to use it")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 24)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: captionCell?.id)
            .accessibilityElement(children: .combine)

            OpacitySlider(viewModel: viewModel)
        }
    }

    private func cellView(_ cell: GridPalette.Cell, isSelected: Bool) -> some View {
        Button {
            Haptics.lightImpact()
            viewModel.pick(cell.rgba)
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(cell.rgba.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(cell.rgba.idealTextColor, lineWidth: 2)
                            .padding(1.5)
                    }
                }
                .scaleEffect(isSelected && !reduceMotion ? 1.12 : 1)
                .zIndex(isSelected ? 1 : 0)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .onHover { hovered = $0 ? cell : (hovered?.id == cell.id ? nil : hovered) }
        .accessibilityLabel(Text(cell.name))
        .accessibilityValue(Text(cell.rgba.hexString))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
#Preview("Grid") {
    GridPickerView(viewModel: ColorEditorViewModel(mode: .create(initial: GridPalette.cells[30].rgba)))
        .padding()
}
#endif
#endif

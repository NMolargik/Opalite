//
//  ColorEditorSwatchPanel.swift
//  OpaliteFeatureColorEditor
//
//  The live half of the editor: the big swatch (its badge renames the color, with Apple
//  Intelligence suggestions), the sibling palette strip, the hex/RGB/HSL readouts (tap
//  to copy), and the notes field.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct ColorEditorSwatchPanel: View {
    let viewModel: ColorEditorViewModel
    /// A transient model the shared `SwatchView` renders; the editor keeps it in sync.
    let previewColor: OpaliteColor
    @Binding var isEditingName: Bool
    /// Compact stacks the readouts as pills; regular lists them as rows.
    var compact: Bool
    /// A fixed swatch height (compact); nil lets the swatch fill the column.
    var swatchHeight: CGFloat? = nil

    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var stripChip: CGFloat = 40

    var body: some View {
        VStack(spacing: Brand.Space.md) {
            swatch
            if viewModel.isShowingPaletteStrip, !viewModel.siblingColors.isEmpty {
                paletteStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if compact { readoutPills } else { readoutRows }
            notesField
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: viewModel.isShowingPaletteStrip)
    }

    // MARK: Swatch

    private var swatch: some View {
        SwatchView(
            color: previewColor,
            cornerRadius: Brand.Radius.sheet,
            isEditingBadge: $isEditingName,
            onRename: { viewModel.name = $0 },
            nameSuggestions: viewModel.nameSuggestions,
            isLoadingSuggestions: viewModel.isLoadingSuggestions,
            onSuggestionSelected: { suggestion in
                viewModel.applySuggestion(suggestion)
                isEditingName = false
            },
            menu: {
                Button {
                    isEditingName = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    hexCopy.copy(hex: viewModel.rgba.hexString)
                } label: {
                    Label("Copy Hex", systemImage: "doc.on.doc")
                }
                if viewModel.canUndo {
                    Button {
                        Haptics.lightImpact()
                        viewModel.undo()
                    } label: {
                        Label("Undo Last Pick", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        )
        .overlay(alignment: .bottomLeading) {
            HexBadge(viewModel.familyDescription, onDark: !viewModel.rgba.prefersDarkText, font: .caption.weight(.medium))
                .padding(Brand.Space.sm)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: swatchHeight)
        .frame(maxHeight: swatchHeight == nil ? .infinity : nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: viewModel.rgba)
        .accessibilityIdentifier("colorEditor.swatch")
    }

    // MARK: Palette strip

    private var paletteStrip: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xs) {
            Text("In this palette")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Brand.Space.sm) {
                    ForEach(Array(viewModel.siblingColors.enumerated()), id: \.offset) { index, sibling in
                        Button {
                            Haptics.lightImpact()
                            viewModel.pick(sibling)
                        } label: {
                            RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                .fill(sibling.color)
                                .frame(width: stripChip, height: stripChip)
                                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                        }
                        .buttonStyle(.plain)
                        .hoverLift()
                        .accessibilityLabel(Text("Palette color \(index + 1), \(sibling.hexString)"))
                        .accessibilityHint(Text("Starts from this color"))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Readouts

    private var readoutPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.sm) {
                pill(label: String(localized: "hex"), text: hexCopy.formatted(viewModel.rgba.hexString), isHex: true)
                pill(label: String(localized: "RGB"), text: viewModel.rgba.rgbString, isHex: false)
                pill(label: String(localized: "HSL"), text: viewModel.rgba.hslString, isHex: false)
            }
            .padding(.horizontal, 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func pill(label: String, text: String, isHex: Bool) -> some View {
        Button {
            if isHex { hexCopy.copy(hex: viewModel.rgba.hexString) } else { hexCopy.copy(text: text, label: label) }
        } label: {
            HStack(spacing: 6) {
                Text(text)
                    .font(.footnote.monospaced())
                    .lineLimit(1)
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm)
            .statPillBackground()
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityLabel(Text("Copy \(label), \(text)"))
    }

    private var readoutRows: some View {
        VStack(spacing: 0) {
            DetailRow(String(localized: "Hex"), value: hexCopy.formatted(viewModel.rgba.hexString), systemImage: "number", monospaced: true) {
                hexCopy.copy(hex: viewModel.rgba.hexString)
            }
            DetailRow(String(localized: "RGB"), value: viewModel.rgba.rgbString, systemImage: "slider.horizontal.3", monospaced: true) {
                hexCopy.copy(text: viewModel.rgba.rgbString, label: String(localized: "RGB"))
            }
            DetailRow(String(localized: "HSL"), value: viewModel.rgba.hslString, systemImage: "circle.lefthalf.filled", monospaced: true) {
                hexCopy.copy(text: viewModel.rgba.hslString, label: String(localized: "HSL"))
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.sm)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    // MARK: Notes

    private var notesField: some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            Image(systemName: "note.text")
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.top, 2)
                .accessibilityHidden(true)
            TextField(String(localized: "Notes"), text: Binding(get: { viewModel.notes }, set: { viewModel.notes = $0 }), axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .accessibilityLabel(Text("Notes"))
                .accessibilityIdentifier("colorEditor.notes")
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.md)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }
}

#if DEBUG
#Preview("Swatch panel") {
    struct Preview: View {
        @State private var editing = false
        private let color = OpaliteColor.sample
        var body: some View {
            ColorEditorSwatchPanel(viewModel: ColorEditorViewModel(mode: .edit(color)), previewColor: color, isEditingName: $editing, compact: false)
                .padding()
                .previewEnvironment()
        }
    }
    return Preview()
}
#endif
#endif

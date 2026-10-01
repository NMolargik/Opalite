//
//  ModePicker.swift
//  OpaliteFeatureColorEditor
//
//  The glass segmented control that switches picker modes. The selected segment grows a
//  title (tab-bar style); when the row would overflow, every segment is icon-only.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct ModePicker: View {
    let selection: ColorPickerTab
    let onSelect: (ColorPickerTab) -> Void

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(showsTitle: true)
            row(showsTitle: false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Color picker mode"))
        .accessibilityIdentifier("colorEditor.modePicker")
    }

    private func row(showsTitle: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(ColorPickerTab.allCases) { tab in
                segment(tab, showsTitle: showsTitle)
            }
        }
        .padding(4)
        .adaptiveGlassCapsule()
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: selection)
    }

    private func segment(_ tab: ColorPickerTab, showsTitle: Bool) -> some View {
        let isSelected = tab == selection
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            onSelect(tab)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.body.weight(.semibold))
                    .symbolEffect(.bounce, value: isSelected)
                if isSelected, showsTitle {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, isSelected && showsTitle ? 14 : 11)
            .padding(.vertical, 9)
            .frame(minWidth: 40)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.opalitePurple.opacity(0.32))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.opalitePurple.opacity(0.45)))
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityLabel(Text(tab.accessibilityLabel))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(Text("Press \(String(tab.keyboardShortcutKey)) to switch"))
        .accessibilityIdentifier("colorEditor.mode.\(tab.rawValue)")
    }
}

#if DEBUG
#Preview("Mode picker") {
    struct Preview: View {
        @State private var selection: ColorPickerTab = .spectrum
        var body: some View {
            VStack(spacing: 32) {
                ModePicker(selection: selection) { selection = $0 }
                ModePicker(selection: selection) { selection = $0 }
                    .frame(width: 300)
            }
            .padding()
        }
    }
    return Preview()
}
#endif
#endif

//
//  ColorEditorView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
import PhotosUI
import Observation
import TipKit

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Tip for keyboard shortcuts in the color editor (iPad/Mac)
struct ColorEditorKeyboardShortcutsTip: Tip {
    var title: Text {
        Text("Keyboard Shortcuts")
    }

    var message: Text? {
        Text("Press 1-6 on your keyboard to quickly switch between color picker modes.")
    }

    var image: Image? {
        Image(systemName: "keyboard")
    }
}

struct ColorEditorView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(HexCopyManager.self) private var hexCopyManager
    @Namespace private var swatchNamespace

    var onCancel: () -> Void
    var onApprove: (OpaliteColor) -> Void

    @State private var viewModel: ViewModel
    let palette: OpalitePalette?

    private let keyboardShortcutsTip = ColorEditorKeyboardShortcutsTip()

    private var paletteColors: [OpaliteColor] {
        palette?.colors ?? []
    }

    private var paletteColorsExcludingOriginal: [OpaliteColor] {
        guard let original = viewModel.originalColor else { return paletteColors }
        return paletteColors.filter { $0.id != original.id }
    }

    private var paletteStripColors: [OpaliteColor] {
        // Never show the current working color in the strip
        paletteColorsExcludingOriginal.filter { $0.id != viewModel.tempColor.id }
    }

    private var canShowPaletteStripToggle: Bool {
        !paletteStripColors.isEmpty
    }

    init(
        color: OpaliteColor? = nil,
        palette: OpalitePalette? = nil,
        onCancel: @escaping () -> Void = {},
        onApprove: @escaping (OpaliteColor) -> Void = { _ in }
    ) {
        let viewModel = ViewModel(
            color: color
        )
        _viewModel = State(initialValue: viewModel)
        self.palette = palette
        self.onCancel = onCancel
        self.onApprove = onApprove
    }

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .compact {
                    VStack(spacing: 16) {
                        swatchAreaCompact

                        if !viewModel.isColorExpanded {
                            VStack {
                                modeContentView
                                    .fixedSize(horizontal: false, vertical: true)

                                modePickerView
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    HStack(spacing: 16) {
                        swatchAreaRegular

                        if !viewModel.isColorExpanded {
                            VStack {
                                modeContentView
                                    .frame(maxHeight: .infinity)
                                modePickerView
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .frame(maxHeight: viewModel.isColorExpanded ? 0 : nil)
                        }
                    }
                    .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                }
            }
            .padding()
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.mode)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isColorExpanded)
            .toolbar {
                if canShowPaletteStripToggle {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.impact()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.isShowingPaletteStrip.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.isShowingPaletteStrip ? "swatchpalette.fill" : "swatchpalette")
                        }
                        .accessibilityLabel(viewModel.isShowingPaletteStrip ? "Hide palette colors" : "Show palette colors")
                    }
                    
                    #if !os(visionOS)
                    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                    #endif
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsManager.shared.impact()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.isColorExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isColorExpanded ? "pencil" : "rectangle.expand.diagonal")
                    }
                    .toolbarButtonTint()
                    .accessibilityLabel(viewModel.isColorExpanded ? "Show editor" : "Expand color preview")
                }

                #if os(iOS) || os(visionOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsManager.shared.impact()
                        hexCopyManager.copyHex(for: viewModel.tempColor)

                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.didCopyHex = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.didCopyHex = false
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.didCopyHex ? "checkmark" : "number")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .tint(viewModel.didCopyHex ? .green : .inverseTheme)
                    .accessibilityLabel(viewModel.didCopyHex ? "Hex code copied" : "Copy hex code")
                    .accessibilityValue(hexCopyManager.formattedHex(for: viewModel.tempColor))
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticsManager.shared.impact()
                        withAnimation(.easeInOut) {
                            onCancel()
                        }
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .tint(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsManager.shared.impact()
                        withAnimation(.easeInOut) {
                            onApprove(viewModel.tempColor)
                        }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .labelStyle(.titleOnly)
                    }
                    .tint(.blue)
                }

                #elseif os(macOS)
                if canShowPaletteStripToggle {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.isShowingPaletteStrip.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.isShowingPaletteStrip ? "swatchpalette.fill" : "swatchpalette")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.isColorExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isColorExpanded ? "pencil" : "rectangle.expand.diagonal")
                    }
                    .toolbarButtonTint()
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        hexCopyManager.copyHex(for: viewModel.tempColor)

                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.didCopyHex = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.didCopyHex = false
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.didCopyHex ? "checkmark" : "number")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .toolbarButtonTint()
                }

                ToolbarItemGroup(placement: .principal) {
                    Button {
                        withAnimation(.easeInOut) {
                            onCancel()
                        }
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .tint(.red)

                    Button {
                        withAnimation(.easeInOut) {
                            onApprove(viewModel.tempColor)
                        }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .tint(.green)

                }
                #endif
            }
            .background {
                // Hidden buttons for keyboard shortcuts (1-5) on iPad/Mac
                keyboardShortcutButtons
            }
        }
    }

    // MARK: - Subviews

    /// Hidden buttons that provide keyboard shortcuts (1-5) for switching color picker modes
    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        ForEach(ColorPickerTab.allCases) { tab in
            Button("") {
                guard !viewModel.isColorExpanded else { return }
                HapticsManager.shared.impact()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.mode = tab
                }
                keyboardShortcutsTip.invalidate(reason: .actionPerformed)
            }
            .keyboardShortcut(KeyEquivalent(tab.keyboardShortcutKey), modifiers: [])
            .hidden()
        }
    }

    @ViewBuilder
    private var modePickerView: some View {
        VStack(spacing: 8) {
            // Show keyboard shortcuts tip on iPad/Mac
            if horizontalSizeClass == .regular {
                TipView(keyboardShortcutsTip)
                    .tipCornerRadius(16)
            }

            Picker("Input Mode", selection: $viewModel.mode) {
                ForEach(ColorPickerTab.allCases) { option in
                    option.symbol
                        .tag(option)
                        .accessibilityLabel(option.accessibilityLabel)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Color picker mode")
        }
    }

    @ViewBuilder
    private var modeContentView: some View {
        Group {
            switch viewModel.mode {
            case .grid:
                ColorGridPickerView(color: $viewModel.tempColor)
            case .spectrum:
                ColorSpectrumPickerView(color: $viewModel.tempColor)
            case .shuffle:
                ColorShufflePickerView(color: $viewModel.tempColor)
            case .sliders:
                ColorChannelsPickerView(color: $viewModel.tempColor)
            case .codes:
                ColorCodesPickerView(color: $viewModel.tempColor)
            case .image:
                ColorImagePickerView(color: $viewModel.tempColor)
            }
        }
    }

    @ViewBuilder
    private var swatchAreaCompact: some View {
        Group {
            if viewModel.isShowingPaletteStrip, !paletteStripColors.isEmpty {
                HStack(spacing: 12) {
                    SwatchView(
                        color: viewModel.tempColor,
                        height: nil,
                        badgeText: "",
                        showOverlays: false
                    )
                        .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)

                    Divider()

                    ForEach(paletteStripColors, id: \.self) { color in
                        SwatchView(
                            color: color,
                            height: nil,
                            badgeText: "",
                            showOverlays: false
                        )
                            .transition(.scale(scale: 0.2, anchor: .bottom))
                    }
                }
            } else {
                SwatchView(
                    color: viewModel.tempColor,
                    height: nil,
                    badgeText: "",
                    showOverlays: false
                )
                    .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)
            }
        }
        .frame(maxHeight: .infinity)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                viewModel.isColorExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private var swatchAreaRegular: some View {
        Group {
            if viewModel.isShowingPaletteStrip, !paletteStripColors.isEmpty {
                let colors = paletteStripColors
                let midIndex = colors.count / 2

                VStack(spacing: 12) {
                    ForEach(0..<midIndex, id: \.self) { index in
                        SwatchView(
                            color: colors[index],
                            height: viewModel.isColorExpanded ? nil : 60,
                            badgeText: "",
                            showOverlays: false
                        )
                            .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                            .transition(.scale(scale: 0.2, anchor: .top))
                    }

                    SwatchView(
                        color: viewModel.tempColor,
                        height: viewModel.isColorExpanded ? nil : 60,
                        badgeText: "",
                        showOverlays: false
                    )
                        .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                        .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)

                    ForEach(midIndex..<colors.count, id: \.self) { index in
                        SwatchView(
                            color: colors[index],
                            height: viewModel.isColorExpanded ? nil : 60,
                            badgeText: "",
                            showOverlays: false
                        )
                            .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                            .transition(.scale(scale: 0.2, anchor: .bottom))
                    }
                }
                .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
            } else {
                SwatchView(
                    color: viewModel.tempColor,
                    height: viewModel.isColorExpanded ? nil : 60,
                    badgeText: "",
                    showOverlays: false
                )
                    .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                    .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ColorEditorView(
            color: OpaliteColor.sample2,
            onApprove: { _ in }
        )
        .environment(HexCopyManager())
    }
}

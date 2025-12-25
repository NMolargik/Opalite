//
//  ColorEditorView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
import PhotosUI
import Observation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

struct ColorEditorView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var swatchNamespace
    
    var onCancel: () -> Void
    var onApprove: (OpaliteColor) -> Void
    
    @State private var viewModel: ViewModel
    let palette: OpalitePalette?
    
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
                                ScrollView {
                                    modeContentView
                                }

                                modePickerView
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                } else {
                    HStack(spacing: 16) {
                        swatchAreaRegular

                        if !viewModel.isColorExpanded {
                            VStack {
                                Spacer()

                                modeContentView
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
                                .foregroundStyle(.purple, .orange, .red)
                        }
                        .accessibilityLabel(viewModel.isShowingPaletteStrip ? "Hide palette colors" : "Show palette colors")
                    }
                }
                
                #if os(iOS) || os(visionOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsManager.shared.impact()
                        let hex = viewModel.tempColor.hexString
                        #if os(iOS) || os(visionOS)
                        UIPasteboard.general.string = hex
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hex, forType: .string)
                        #endif

                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.didCopyHex = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.didCopyHex = false
                            }
                        }
                    } label: {
                        if viewModel.didCopyHex {
                            Text("Hex Copied")
                        } else {
                            Image(systemName: "number")
                        }
                    }
                    .tint(viewModel.didCopyHex ? .green : nil)
                    .accessibilityLabel(viewModel.didCopyHex ? "Hex code copied" : "Copy hex code")
                    .accessibilityValue(viewModel.tempColor.hexString)
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
                    .accessibilityLabel(viewModel.isColorExpanded ? "Show editor" : "Expand color preview")
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
                    }
                }
                
                #elseif os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let hex = viewModel.tempColor.hexString
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hex, forType: .string)
                        
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
                    }
                }
                
                if canShowPaletteStripToggle {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.isShowingPaletteStrip.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.isShowingPaletteStrip ? "swatchpalette.fill" : "swatchpalette")
                                .foregroundStyle(.purple, .orange, .red)
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
        }
    }
    
    // MARK: - Subviews

    @ViewBuilder
    private var modePickerView: some View {
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
    
    @ViewBuilder
    private var modeContentView: some View {
        Group {
            switch viewModel.mode {
            case .grid:
                ColorGridPickerView(color: $viewModel.tempColor)
            case .spectrum:
                ColorSpectrumPickerView(color: $viewModel.tempColor)
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
                        fill: [viewModel.tempColor],
                        height: viewModel.isColorExpanded ? nil : 60,
                        badgeText: "",
                        showOverlays: false,
                    )
                        .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)

                    Divider()

                    ForEach(paletteStripColors, id: \.self) { color in
                        SwatchView(
                            fill: [color],
                            height: viewModel.isColorExpanded ? nil : 60,
                            badgeText: "",
                            showOverlays: false,
                        )
                            .transition(.scale(scale: 0.2, anchor: .bottom))
                    }
                }
                .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
            } else {
                SwatchView(
                    fill: [viewModel.tempColor],
                    height: viewModel.isColorExpanded ? nil : 60,
                    badgeText: "",
                    showOverlays: false
                )
                    .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)
            }
        }
        .frame(maxHeight: viewModel.isColorExpanded ? nil : 100)
        .onTapGesture {
            viewModel.isColorExpanded.toggle()
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
                            fill: [colors[index]],
                            height: viewModel.isColorExpanded ? nil : 60,
                            badgeText: "",
                            showOverlays: false
                        )
                            .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                            .transition(.scale(scale: 0.2, anchor: .top))
                    }

                    SwatchView(
                        fill: [viewModel.tempColor],
                        height: viewModel.isColorExpanded ? nil : 60,
                        badgeText: "",
                        showOverlays: false
                    )
                        .frame(maxHeight: viewModel.isColorExpanded ? .infinity : nil)
                        .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)

                    ForEach(midIndex..<colors.count, id: \.self) { index in
                        SwatchView(
                            fill: [colors[index]],
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
                    fill: [viewModel.tempColor],
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
    }
}

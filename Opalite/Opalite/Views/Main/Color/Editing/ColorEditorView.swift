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
    var onCancel: () -> Void
    var onApprove: (OpaliteColor) -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var swatchNamespace
    
    @State private var viewModel: ViewModel
    
    init(
        color: OpaliteColor? = nil,
        palette: OpalitePalette? = nil,
        onCancel: @escaping () -> Void = {},
        onApprove: @escaping (OpaliteColor) -> Void = { _ in }
    ) {
        let viewModel = ViewModel(color: color, palette: palette)
        _viewModel = State(initialValue: viewModel)
        self.onCancel = onCancel
        self.onApprove = onApprove
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(spacing: 16) {
                    if viewModel.isShowingPaletteStrip,
                       let palette = viewModel.palette,
                       let rawColors = palette.colors,
                       !rawColors.isEmpty {
                        // Filter out the current tempColor so we don't duplicate it in the strip
                        let colors = rawColors.filter { $0.hexString != viewModel.tempColor.hexString }

                        HStack(spacing: 12) {
                            // Current working color in the middle
                            ColorSwatchView(color: viewModel.tempColor.swiftUIColor) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    viewModel.isExpanded.toggle()
                                }
                            }
                            .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)
                            
                            Divider()

                            // Trailing colors
                            ForEach(colors, id: \.self) { color in
                                ColorSwatchView(color: color.swiftUIColor) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        viewModel.isExpanded.toggle()
                                    }
                                }
                                .transition(.scale(scale: 0.2, anchor: .bottom))

                            }
                        }
                    } else {
                        ColorSwatchView(color: viewModel.tempColor.swiftUIColor) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.isExpanded.toggle()
                            }
                        }
                        .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)
                    }

                    if viewModel.isExpanded {
                        VStack {
                            modePickerView

                            modeContentView
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    if viewModel.isShowingPaletteStrip,
                       let palette = viewModel.palette,
                       let rawColors = palette.colors,
                       !rawColors.isEmpty {
                        // Filter out the current tempColor so we don't duplicate it in the strip
                        let colors = rawColors.filter { $0.id != viewModel.tempColor.id }

                        VStack(spacing: 12) {
                            let midIndex = colors.count / 2

                            // Leading colors
                            ForEach(0..<midIndex, id: \.self) { index in
                                let paletteColor = colors[index]
                                ColorSwatchView(color: paletteColor.swiftUIColor) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        viewModel.isExpanded.toggle()
                                    }
                                }
                                .transition(.scale(scale: 0.2, anchor: .top))

                            }

                            // Current working color in the middle
                            ColorSwatchView(color: viewModel.tempColor.swiftUIColor) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    viewModel.isExpanded.toggle()
                                }
                            }
                            .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)

                            // Trailing colors
                            ForEach(midIndex..<colors.count, id: \.self) { index in
                                let paletteColor = colors[index]
                                ColorSwatchView(color: paletteColor.swiftUIColor) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        viewModel.isExpanded.toggle()
                                    }
                                }
                                .transition(.scale(scale: 0.2, anchor: .bottom))
                            }
                        }
                    } else {
                        ColorSwatchView(color: viewModel.tempColor.swiftUIColor) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.isExpanded.toggle()
                            }
                        }
                        .matchedGeometryEffect(id: "currentSwatch", in: swatchNamespace)
                    }

                    if viewModel.isExpanded {
                        VStack {
                            Spacer()
                            
                            modeContentView

                            modePickerView
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .padding()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.mode)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isExpanded)
        .toolbar {
            #if os(iOS) || os(visionOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
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
                    Image(systemName: viewModel.didCopyHex ? "checkmark" : "number")
                }
            }

            if viewModel.palette != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.isShowingPaletteStrip.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isShowingPaletteStrip ? "swatchpalette.fill" : "swatchpalette")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isExpanded ? "rectangle.expand.diagonal" : "pencil")
                }
            }
            
            ToolbarItemGroup(placement: .topBarLeading) {
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

            if viewModel.palette != nil {
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
                        viewModel.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isExpanded ? "rectangle.expand.diagonal" : "pencil")
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
    
    // MARK: - Subviews

    @ViewBuilder
    private var modePickerView: some View {
        Picker("Input Mode", selection: $viewModel.mode) {
            ForEach(ColorPickerTab.allCases) { option in
                Label {
                    // Only show text for the currently selected mode
                    if option == viewModel.mode {
                        Text(option.rawValue)
                    }
                } icon: {
                    option.symbol
                }
                .tag(option)
            }
        }
        .pickerStyle(.segmented)
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
}

#Preview {
    NavigationStack {
        ColorEditorView(
            color: OpaliteColor.sample2,
            palette: OpalitePalette.sample,
            onCancel: {},
            onApprove: { _ in }
        )
    }
}

//
//  LargeSwatchView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct LargeSwatchView: View {
    @Environment(ColorManager.self) private var colorManager
    @Bindable var viewModel: ColorDetailView.ViewModel
    let isNameFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(viewModel.swatchColor)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .overlay(alignment: .bottomTrailing) {
                if viewModel.isEditingName {
                    HStack(spacing: 8) {
                        TextField("Name", text: $viewModel.draftName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused(isNameFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                isNameFieldFocused.wrappedValue = false
                                viewModel.commitEditName(using: colorManager)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThickMaterial, in: Capsule())
                        Button {
                            isNameFieldFocused.wrappedValue = false
                            viewModel.commitEditName(using: colorManager)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white, .green)
                                .font(.largeTitle)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    // Hex overlay chip
                    Text(viewModel.displayTitle)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThickMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
            .onDrag {
                dragItemProvider()
            }
    }

    private func dragItemProvider() -> NSItemProvider {
#if os(iOS) || os(visionOS)
        // Build a simple 512x512 solid-color tile (no overlays)
        let exportView = Rectangle()
            .fill(viewModel.swatchColor)
            .frame(width: 512, height: 512)

        let renderer = ImageRenderer(content: exportView)

        #if canImport(UIKit)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            return NSItemProvider(object: image)
        }
        #endif

        // Fallback empty provider if rendering fails
        return NSItemProvider()
#else
        // On non-iOS platforms, you could add an NSImage-based path here later.
        return NSItemProvider()
#endif
    }
}

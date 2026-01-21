//
//  ColorRowHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

/// Header for the loose colors section with title, edit mode toggle, and create button.
struct ColorRowHeaderView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    @Binding var isEditingColors: Bool
    @Binding var selectedColorIDs: Set<UUID>
    @State private var isShowingColorEditor: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(alignment: .center) {
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(.blue.gradient)
                    .accessibilityHidden(true)
                    .font(.title)

                Text("Colors")
                    .font(.title)
                    .padding(.trailing)

                Button {
                    HapticsManager.shared.selection()
                    withAnimation {
                        isEditingColors.toggle()
                        // Clear selections when exiting edit mode
                        if !isEditingColors {
                            selectedColorIDs.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: isEditingColors ? "checkmark" : "pencil")
                        .imageScale(.large)
                        .foregroundStyle(isEditingColors ? .green : .inverseTheme)
                        .frame(height: 20)
                        .padding(8)
                        .background(
                            Circle().fill(.clear)
                        )
                        .glassIfAvailable(
                            GlassConfiguration(style: .regular)
                        )
                        .contentShape(Circle())
                        .hoverEffect(.lift)
                }
                .buttonStyle(.plain)
            }
            .bold()
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Colors, \(colorManager.looseColors.count) items")

        }
        .padding(.horizontal)
        .fullScreenCover(isPresented: $isShowingColorEditor) {
            ColorEditorView(
                color: nil,
                palette: nil,
                onCancel: {
                    isShowingColorEditor = false
                },
                onApprove: { newColor in
                    do {
                        _ = try colorManager.createColor(existing: newColor)
                    } catch {
                        toastManager.show(error: .colorCreationFailed)
                    }
                    isShowingColorEditor = false
                }
            )
        }
    }
}

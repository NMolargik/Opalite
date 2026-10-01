//
//  ColorRowHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import SwiftData

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

                if !colorManager.looseColors.isEmpty {
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
                            .imageScale(.medium)
                            .foregroundStyle(isEditingColors ? .green : .inverseTheme)
                            .frame(width: 15, height: 15)
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

#Preview("Color Row Header") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        CanvasFile.self,
        configurations: config
    )
    let manager = ColorManager(context: container.mainContext)
    try? manager.loadSamples()

    return ColorRowHeaderView(
        isEditingColors: .constant(false),
        selectedColorIDs: .constant([])
    )
    .modelContainer(container)
    .environment(manager)
    .environment(ToastManager())
}

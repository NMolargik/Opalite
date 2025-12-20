//
//  SettingsView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(ColorManager.self) private var colorManager
    
    @State private var isShowingDeleteAllAlert: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title)
                .bold()

            Button {
                do {
                    try colorManager.loadSamples()
                } catch {
                    print("Failed to load samples: \(error)")
                }
            } label: {
                Label("Load Sample Data", systemImage: "tray.and.arrow.down")
            }

            Button(role: .destructive) {
                isShowingDeleteAllAlert = true
            } label: {
                Label("Delete Everything", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert("Delete All Colors?", isPresented: $isShowingDeleteAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                do {
                    for color in colorManager.colors {
                        try colorManager.deleteColor(color)
                    }
                    
                    for palette in colorManager.palettes {
                        try colorManager.deletePalette(palette)
                    }
                } catch {
                    print("Failed to delete all colors: \(error)")
                }
            }
        } message: {
            Text("This will permanently delete all Opalite colors. This action cannot be undone.")
        }
    }
    
    
}
//
//#Preview {
//    SettingsTabView()
//}


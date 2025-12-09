//
//  PaletteSelectionSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI

struct PaletteSelectionSheet: View {
    let palettes: [OpalitePalette]
    var onCancel: () -> Void
    var onCreateAndSelect: (String) -> Void
    var onSelect: (OpalitePalette) -> Void

    @State private var newPaletteName: String = Date.now.formatted(date: .numeric, time: .shortened)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if palettes.isEmpty {
                    ContentUnavailableView("No Palettes", systemImage: "swatchpalette")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    List {
                        Section("Select a Palette") {
                            Button {
                                let name: String = Date.now.formatted(date: .numeric, time: .shortened)
                                onCreateAndSelect(name.isEmpty ? Date.now.formatted(date: .numeric, time: .shortened) : name)
                            } label: {
                                Text("Create New & Add")
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            ForEach(palettes, id: \.id) { palette in
                                Button {
                                    onSelect(palette)
                                } label: {
                                    HStack {
                                        Text(palette.name)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(.black)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save to Palette")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .tint(.red)
                }
            }
        }
    }
}

#Preview {
    PaletteSelectionSheet(
        palettes: [OpalitePalette.sample],
        onCancel: {},
        onCreateAndSelect: { _ in },
        onSelect: { _ in }
    )
}

//
//  PaletteDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct PaletteDetailView: View {
    let palette: OpalitePalette
    
    var body: some View {
        Text("Palette Detail")
    }
}

#Preview {
    PaletteDetailView(palette: OpalitePalette.sample)
}

//
//  SearchView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
    
    var body: some View {
        Text("Search")
    }
}

#Preview("Search") {
    // In-memory container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpaliteColor.self,
            OpalitePalette.self,
            CanvasFile.self,
        configurations: config
    )

    let context = container.mainContext

    return SearchView()
        .modelContainer(container)
        .environment(ColorManager(context: context))
        .environment(CanvasManager(context: context))
}

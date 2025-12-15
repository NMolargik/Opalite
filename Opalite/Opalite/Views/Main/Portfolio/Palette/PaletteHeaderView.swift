//
//  PaletteHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData

struct PaletteHeaderView: View {
    @Environment(ColorManager.self) private var colorManager
    @State private var showDeleteConfirmation = false
    @State private var shareImage: UIImage?
    @State private var isShowingShareSheet = false
    let palette: OpalitePalette
    
    var body: some View {
        HStack {
            Menu {
                Button {
                    if let image = gradientImage(from: palette.colors ?? []) {
                        shareImage = image
                        isShowingShareSheet = true
                    }
                } label: {
                    Label("Share As Image", systemImage: "photo.on.rectangle")
                }

                Button {
                    // TODO: Share Palette
                } label: {
                    Label("Share Palette", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Palette", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .imageScale(.large)
                    .foregroundStyle(.inverseTheme)
                    .frame(height: 20)
                    .padding(8)
                    .background(
                        Circle().fill(.clear)
                    )
                    .glassEffect(.clear)
                    .contentShape(Circle())
                    .hoverEffect(.lift)
            }
            .padding(.leading)

            NavigationLink {
                PaletteDetailView(palette: palette)
            } label: {
                HStack {
                    Text(palette.name)
                        .bold()
                        .padding()

                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.blue)
                }
                .frame(height: 20)
                .padding(8)
                .glassEffect(.regular)
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .hoverEffect(.lift)
            }
            .buttonStyle(.plain)
        }
        .alert("Delete \(palette.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Delete Palette", role: .destructive) {
                do {
                    try colorManager.deletePalette(palette, andColors: false)
                } catch {
                    // TODO: error handling
                }
            }

            if (!(palette.colors?.isEmpty ?? false)) {
                Button("Delete Palette and Colors", role: .destructive) {
                    do {
                        try colorManager.deletePalette(palette, andColors: true)
                    } catch {
                        // TODO: error handling
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .background(shareSheet(image: shareImage))
    }
    
    @ViewBuilder
    private func shareSheet(image: UIImage?) -> some View {
        EmptyView()
            .background(
                ShareSheetPresenter(image: image, isPresented: $isShowingShareSheet)
            )
    }
    
    // MARK: - Helpers
    private func gradientImage(from colors: [OpaliteColor], size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        let uiColors: [Color] = colors.map { $0.swiftUIColor }
        let gradientColors = uiColors.isEmpty ? [Color.clear, Color.clear] : uiColors
        let view = LinearGradient(
            colors: gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size.width, height: size.height)
        .clipped()

        // Render SwiftUI view to UIImage
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = .init(size)
        #if canImport(UIKit)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
        #else
        return nil
        #endif
    }
}

#Preview("Palette Header") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
            OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    return PaletteHeaderView(
        palette: OpalitePalette.sample
    )
    .environment(manager)
    .modelContainer(container)
}

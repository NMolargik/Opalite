//
//  PaletteRowHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData
import TipKit

struct PaletteRowHeaderView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"

    private let paletteMenuTip = PaletteMenuTip()

    @State private var showDeleteConfirmation = false
    @State private var shareImage: UIImage?
    @State private var shareImageTitle: String = "Shared from Opalite"
    @State private var isShowingShareSheet = false
    @State private var isShowingColorEditor = false
    @State private var shareFileURL: URL?
    @State private var isShowingFileShareSheet = false
    @State private var isShowingPaywall: Bool = false
    @State private var exportPDFURL: URL?
    @State private var isShowingPDFShareSheet = false
    
    let palette: OpalitePalette
    
    var body: some View {
        HStack {
            Menu {
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                    Button(role: .confirm) {
                        HapticsManager.shared.selection()
                        isShowingColorEditor.toggle()
                    } label: {
                        Label("New Color", systemImage: "plus.square.dashed")
                    }
                } else {
                    Button() {
                        HapticsManager.shared.selection()
                        isShowingColorEditor.toggle()
                    } label: {
                        Label("New Color", systemImage: "plus.square.dashed")
                    }
                }
                
                Divider()
                
                Button {
                    HapticsManager.shared.selection()
                    if let image = gradientImage(from: palette.colors ?? []) {
                        shareImage = image
                        shareImageTitle = palette.name
                        isShowingShareSheet = true
                    }
                } label: {
                    Label("Share As Image", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    HapticsManager.shared.selection()
                    do {
                        exportPDFURL = try PortfolioPDFExporter.exportPalette(palette, userName: userName)
                        isShowingPDFShareSheet = true
                    } catch {
                        toastManager.show(error: .pdfExportFailed)
                    }
                } label: {
                    Label("Share As PDF", systemImage: "doc.richtext")
                }

                Button {
                    HapticsManager.shared.selection()
                    if subscriptionManager.hasOnyxEntitlement {
                        do {
                            shareFileURL = try SharingService.exportPalette(palette)
                            isShowingFileShareSheet = true
                        } catch {
                            // Export failed silently
                        }
                    } else {
                        isShowingPaywall = true
                    }
                } label: {
                    Label {
                        HStack {
                            Text("Export Palette")
                            if !subscriptionManager.hasOnyxEntitlement {
                                Image(systemName: "lock.fill")
                                    .font(.footnote)
                            }
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    HapticsManager.shared.selection()
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
                    .glassIfAvailable(
                        GlassConfiguration(style: .regular)
                    )
                    .contentShape(Circle())
                    .hoverEffect(.lift)
            }
            .popoverTip(paletteMenuTip, arrowEdge: .leading)
            .padding(.leading)

            NavigationLink {
                PaletteDetailView(palette: palette)
                    .tint(.none)
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
                .glassIfAvailable(
                    GlassConfiguration(style: .regular)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .hoverEffect(.lift)
            }
            .buttonStyle(.plain)
        }
        .alert("Delete \(palette.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }

            Button("Delete Palette", role: .destructive) {
                withAnimation {
                    HapticsManager.shared.selection()
                    do {
                        try colorManager.deletePalette(palette, andColors: false)
                    } catch {
                        toastManager.show(error: .paletteDeletionFailed)
                    }
                }
            }

            if (!(palette.colors?.isEmpty ?? false)) {
                Button("Delete Palette and Colors", role: .destructive) {
                    HapticsManager.shared.selection()
                    withAnimation {
                        do {
                            try colorManager.deletePalette(palette, andColors: true)
                        } catch {
                            toastManager.show(error: .paletteDeletionFailed)
                        }
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .background(shareSheet(image: shareImage))
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Data file export requires Onyx")
        }
        .fullScreenCover(isPresented: $isShowingColorEditor) {
            ColorEditorView(
                color: nil,
                palette: palette,
                onCancel: {
                    isShowingColorEditor = false
                },
                onApprove: { newColor in
                    do {
                        let createdColor = try colorManager.createColor(existing: newColor)
                        colorManager.attachColor(createdColor, to: palette)
                    } catch {
                        toastManager.show(error: .colorCreationFailed)
                    }

                    isShowingColorEditor.toggle()
                }
            )
        }
    }
    
    @ViewBuilder
    private func shareSheet(image: UIImage?) -> some View {
        EmptyView()
            .background(
                ShareSheetPresenter(image: image, title: shareImageTitle, isPresented: $isShowingShareSheet)
            )
            .background(
                FileShareSheetPresenter(fileURL: shareFileURL, isPresented: $isShowingFileShareSheet)
            )
            .background(
                FileShareSheetPresenter(fileURL: exportPDFURL, isPresented: $isShowingPDFShareSheet)
            )
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
    return PaletteRowHeaderView(
        palette: OpalitePalette.sample
    )
    .environment(manager)
    .environment(ToastManager())
    .environment(SubscriptionManager())
    .modelContainer(container)
}

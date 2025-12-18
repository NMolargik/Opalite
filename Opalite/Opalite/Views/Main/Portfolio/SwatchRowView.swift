//
//  SwatchRowView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SwatchRowView: View {
    @Environment(ColorManager.self) private var colorManager
    let colors: [OpaliteColor]
    let palette: OpalitePalette?
    let swatchWidth: CGFloat
    let swatchHeight: CGFloat
    var showOverlays: Bool = false
    var showsNavigation: Bool = true
    var menuContent: ((OpaliteColor) -> AnyView)? = nil
    var contextMenuContent: ((OpaliteColor) -> AnyView)? = nil
    var matchedNamespace: Namespace.ID? = nil
    
    @State private var isDropTargeted: Bool = false
    @State private var showingColorEditor: Bool = false
    
    var body: some View {
        Group {
            if (colors.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.down.right")
                        .bold()
                    
                    Button {
                        showingColorEditor.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.square.dashed")
                                .font(.title2)
                            
                            Text("Create New Color")
                        }
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 20)
                        .padding(8)
                        .multilineTextAlignment(.center)
                        .glassEffect(.clear.tint(.blue).interactive())
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .hoverEffect(.lift)
                    }
                    
                    Spacer()
                }
                .padding(.leading, 35)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(colors.sorted(by: { $0.updatedAt > $1.updatedAt }), id: \.self) { color in
                            if showsNavigation {
                                NavigationLink {
                                    ColorDetailView(color: color)
                                } label: {
                                    swatchCell(for: color)
                                }
                                .buttonStyle(.plain)
                            } else {
                                swatchCell(for: color)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onDrop(of: [UTType.opaliteColorID], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.opaliteColorID.identifier) }) else {
                return false
            }

            provider.loadItem(forTypeIdentifier: UTType.opaliteColorID.identifier, options: nil) { item, _ in
                var idString: String?
                if let data = item as? Data {
                    idString = String(data: data, encoding: .utf8)
                } else if let str = item as? String {
                    idString = str
                } else if let url = item as? URL {
                    idString = url.lastPathComponent
                } else if let nsData = item as? NSData {
                    idString = String(data: nsData as Data, encoding: .utf8)
                }

                guard let idString, let uuid = UUID(uuidString: idString) else { return }

                Task { @MainActor in
                    var droppedColor = colorManager.colors.first(where: { $0.id == uuid })
                    if droppedColor == nil {
                        _ = try? colorManager.fetchColors()
                        droppedColor = colorManager.colors.first(where: { $0.id == uuid })
                    }
                    guard let color = droppedColor else { return }

                    withAnimation(.spring()) {
                        if let palette {
                            colorManager.attachColor(color, to: palette)
                        } else {
                            colorManager.detachColorFromPalette(color)
                        }
                    }
                }
            }

            // Accept the drop; handling is async
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colors.isEmpty ? .inverseTheme : .blue, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .opacity(isDropTargeted ? 1 : 0)
                .padding(.leading, colors.isEmpty ? 65 : 10)
                .padding(.trailing, colors.isEmpty ? 0 : -20) // bleed past trailing edge
        )
        .fullScreenCover(isPresented: $showingColorEditor) {
            ColorEditorView(
                color: nil,
                palette: palette,
                onCancel: {
                    showingColorEditor = false
                },
                onApprove: { newColor in
                    do {
                        let createdColor = try colorManager.createColor(existing: newColor)
                        if let palette = palette {
                            colorManager.attachColor(createdColor, to: palette)
                        }
                    } catch {
                        // TODO: error handling
                    }
                    
                    showingColorEditor.toggle()
                }
            )
        }
    }
    
    @ViewBuilder
    private func swatchCell(for color: OpaliteColor) -> some View {
        SwatchView(
            fill: [color],
            width: swatchWidth,
            height: swatchHeight,
            badgeText: color.name ?? color.hexString,
            showOverlays: showOverlays,
            isEditingBadge: .constant(nil),
            saveBadge: nil,
            palette: palette,
            matchedNamespace: matchedNamespace,
            matchedID: color.id,
            menu: menuContent?(color),
            contextMenu: contextMenuContent?(color)
        )
    }
}

#Preview {
    // In-memory SwiftData container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
            OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    
    return VStack {
        SwatchRowView(
            colors: [OpaliteColor.sample, OpaliteColor.sample2],
            palette: nil,
            swatchWidth: 75,
            swatchHeight: 75
        )
        
        SwatchRowView(
            colors: [OpaliteColor.sample, OpaliteColor.sample2],
            palette: nil,
            swatchWidth: 150,
            swatchHeight: 150,
            showOverlays: true,
            menuContent: { _ in
                AnyView(
                    Group {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )
            }
        )
        
        SwatchRowView(
            colors: [OpaliteColor.sample, OpaliteColor.sample2],
            palette: nil,
            swatchWidth: 200,
            swatchHeight: 200,
            showOverlays: true,
            menuContent: { _ in
                AnyView(
                    Group {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )
            }
        )
    }
    .environment(manager)
}

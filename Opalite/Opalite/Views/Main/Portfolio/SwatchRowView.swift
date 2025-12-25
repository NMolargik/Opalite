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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    
    let colors: [OpaliteColor]
    let palette: OpalitePalette?
    let swatchWidth: CGFloat
    let swatchHeight: CGFloat
    var showOverlays: Bool = false
    var showsNavigation: Bool = true
    var onTap: ((OpaliteColor) -> Void)? = nil
    var menuContent: ((OpaliteColor) -> AnyView)? = nil
    var contextMenuContent: ((OpaliteColor) -> AnyView)? = nil
    var matchedNamespace: Namespace.ID? = nil
    
    var isCompact: Bool { horizontalSizeClass == .compact }
    
    @State private var isDropTargeted: Bool = false
    @State private var showingColorEditor: Bool = false
    
    var body: some View {
        HStack {
            if (colors.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.down.right")
                        .bold()
                        .accessibilityHidden(true)

                    Button {
                        HapticsManager.shared.selection()
                        showingColorEditor.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.square.dashed")
                                .font(.title2)

                            Text("Create A New Color")
                        }
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 20)
                        .padding(8)
                        .multilineTextAlignment(.center)
                        .glassIfAvailable(
                            GlassConfiguration(style: .clear)
                                .tint(.blue)
                                .interactive()
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .hoverEffect(.lift)
                    }
                    .accessibilityLabel("Create A New Color")
                    .accessibilityHint("Opens the color editor to create a new color")

                    Spacer()
                }
                .padding(.leading, 35)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(colors.sorted(by: { $0.updatedAt > $1.updatedAt }), id: \.self) { color in
                            if let onTap = onTap {
                                Button {
                                    HapticsManager.shared.selection()
                                    onTap(color)
                                } label: {
                                    swatchCell(for: color)
                                }
                                .buttonStyle(.plain)
                            } else if showsNavigation {
                                NavigationLink {
                                    ColorDetailView(color: color)
                                        .tint(.none)
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
        .onDrop(of: [UTType.opaliteColor, UTType.opaliteColorID], isTargeted: $isDropTargeted) { providers in
            // Try to handle full JSON color data first (cross-device drops)
            if let jsonProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.opaliteColor.identifier) }) {
                jsonProvider.loadDataRepresentation(forTypeIdentifier: UTType.opaliteColor.identifier) { data, _ in
                    guard let data else { return }
                    handleDroppedColorJSON(data)
                }
                return true
            }

            // Fall back to color ID (same-device drops)
            guard let idProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.opaliteColorID.identifier) }) else {
                return false
            }

            idProvider.loadItem(forTypeIdentifier: UTType.opaliteColorID.identifier, options: nil) { item, _ in
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
                handleDroppedColorID(uuid)
            }

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
                        toastManager.show(error: .colorCreationFailed)
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

    // MARK: - Drop Handlers

    /// Handle a dropped color by UUID (same-device drop - color exists locally)
    private func handleDroppedColorID(_ uuid: UUID) {
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

    /// Handle a dropped color from JSON data (cross-device drop - need to import)
    private func handleDroppedColorJSON(_ data: Data) {
        Task { @MainActor in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            // Check if this color already exists by ID
            if let idString = json["id"] as? String,
               let uuid = UUID(uuidString: idString) {
                // Try to find existing color first
                var existingColor = colorManager.colors.first(where: { $0.id == uuid })
                if existingColor == nil {
                    _ = try? colorManager.fetchColors()
                    existingColor = colorManager.colors.first(where: { $0.id == uuid })
                }

                if let color = existingColor {
                    // Color exists locally, just attach/detach
                    withAnimation(.spring()) {
                        if let palette {
                            colorManager.attachColor(color, to: palette)
                        } else {
                            colorManager.detachColorFromPalette(color)
                        }
                    }
                    return
                }
            }

            // Color doesn't exist locally - create it from the JSON data
            guard let red = json["red"] as? Double,
                  let green = json["green"] as? Double,
                  let blue = json["blue"] as? Double else { return }

            let alpha = json["alpha"] as? Double ?? 1.0
            let name = json["name"] as? String
            let notes = json["notes"] as? String
            let createdByDisplayName = json["createdByDisplayName"] as? String

            let newColor = OpaliteColor(
                name: name,
                notes: notes,
                createdByDisplayName: createdByDisplayName,
                red: red,
                green: green,
                blue: blue,
                alpha: alpha
            )

            do {
                let createdColor = try colorManager.createColor(existing: newColor)
                withAnimation(.spring()) {
                    if let palette {
                        colorManager.attachColor(createdColor, to: palette)
                    }
                }
            } catch {
                // Import failed silently
            }
        }
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
                        Button("Edit") {
                            HapticsManager.shared.selection()
                        }
                        Button("Duplicate") {
                            HapticsManager.shared.selection()
                        }
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

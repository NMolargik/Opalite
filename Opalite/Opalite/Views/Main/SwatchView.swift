//
//  SwatchView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

import UniformTypeIdentifiers

struct SwatchView: View {
    private var palette: OpalitePalette? = nil
    @State private var isDropTargeted: Bool = false
    private var matchedNamespace: Namespace.ID? = nil
    private var matchedID: AnyHashable? = nil

    private var fill: [OpaliteColor]
    private var width: CGFloat?
    private var height: CGFloat?
    private var badgeText: String
    private var showOverlays: Bool
    @Binding var isEditingBadge: Bool?
    private var saveBadge: ((String) -> Void)?
    private var allowBadgeTapToEdit: Bool
    private var menu: AnyView?
    private var contextMenu: AnyView?
    @Binding var showCopiedFeedback: Bool

    @State private var editedBadgeText: String = ""
    @State private var isMenuPresented: Bool = false
    @FocusState private var badgeFocused: Bool

    init(
        fill: [OpaliteColor],
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        badgeText: String,
        showOverlays: Bool,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        allowBadgeTapToEdit: Bool = false,
        palette: OpalitePalette? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        menu: AnyView? = nil,
        contextMenu: AnyView? = nil,
        showCopiedFeedback: Binding<Bool> = .constant(false)
    ) {
        self.fill = fill
        self.width = width
        self.height = height
        self.badgeText = badgeText
        self.showOverlays = showOverlays
        self._isEditingBadge = isEditingBadge
        self.saveBadge = saveBadge
        self.allowBadgeTapToEdit = allowBadgeTapToEdit
        self.palette = palette
        self.matchedNamespace = matchedNamespace
        self.matchedID = matchedID
        self.menu = menu
        self.contextMenu = contextMenu
        self._showCopiedFeedback = showCopiedFeedback
    }

    init<MenuContent: View>(
        fill: [OpaliteColor],
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        badgeText: String,
        showOverlays: Bool,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        allowBadgeTapToEdit: Bool = false,
        palette: OpalitePalette? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        showCopiedFeedback: Binding<Bool> = .constant(false),
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.init(
            fill: fill,
            width: width,
            height: height,
            badgeText: badgeText,
            showOverlays: showOverlays,
            isEditingBadge: isEditingBadge,
            saveBadge: saveBadge,
            allowBadgeTapToEdit: allowBadgeTapToEdit,
            palette: palette,
            matchedNamespace: matchedNamespace,
            matchedID: matchedID,
            menu: AnyView(menu()),
            showCopiedFeedback: showCopiedFeedback
        )
    }
    
    init<ContextMenuContent: View>(
        fill: [OpaliteColor],
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        badgeText: String,
        showOverlays: Bool,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        allowBadgeTapToEdit: Bool = false,
        palette: OpalitePalette? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        showCopiedFeedback: Binding<Bool> = .constant(false),
        @ViewBuilder contextMenu: @escaping () -> ContextMenuContent
    ) {
        self.init(
            fill: fill,
            width: width,
            height: height,
            badgeText: badgeText,
            showOverlays: showOverlays,
            isEditingBadge: isEditingBadge,
            saveBadge: saveBadge,
            allowBadgeTapToEdit: allowBadgeTapToEdit,
            palette: palette,
            matchedNamespace: matchedNamespace,
            matchedID: matchedID,
            menu: nil,
            contextMenu: AnyView(contextMenu()),
            showCopiedFeedback: showCopiedFeedback
        )
    }
    
    // MARK: - The View
    var body: some View {
        return RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: fill.map { $0.swiftUIColor }),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.thinMaterial, lineWidth: 5)
            )
            .frame(width: width)
            .frame(minHeight: height)
            .overlay(alignment: .topLeading) {
                badgeContent
                    .frame(maxWidth: 500, alignment: .leading)
            }
            .overlay(alignment: .bottomTrailing) {
                menuContent
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .opacity(isDropTargeted ? 1 : 0)
            )
            .contextMenu {
                contextMenuContent
            }
            .if(matchedNamespace != nil && matchedID != nil) { view in
                view.matchedGeometryEffect(id: matchedID!, in: matchedNamespace!)
            }
            .zIndex(2)
            .if(!fill.isEmpty && isEditingBadge != true) { view in
                view.onDrag {
                    provideDragItem()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityAddTraits(.isButton)
    }

    private var accessibilityDescription: String {
        if fill.isEmpty {
            return "Empty swatch"
        } else if fill.count == 1, let first = fill.first {
            let name = first.name ?? "Unnamed color"
            return "\(name), \(first.hexString)"
        } else {
            return "\(badgeText.isEmpty ? "Color palette" : badgeText), \(fill.count) colors"
        }
    }
    
    // MARK: - Badge Content
    @ViewBuilder
    private var badgeContent: some View {
        if showOverlays {
            ZStack(alignment: .leading) {
                // Read-only label state
                if isEditingBadge != true {
                    Text(badgeText)
                        .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                        .bold()
                        .if(allowBadgeTapToEdit && saveBadge != nil) { view in
                            view.onTapGesture {
                                withAnimation(.easeInOut) {
                                    isEditingBadge = true
                                }
                            }
                        }
                }

                // Editing state
                if isEditingBadge == true {
                    HStack(spacing: 8) {
                        TextField("Badge", text: Binding(
                            get: { editedBadgeText.isEmpty ? badgeText : editedBadgeText },
                            set: { editedBadgeText = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                        .bold()
                        .submitLabel(.done)
                        .focused($badgeFocused)
                        .onSubmit {
                            let finalText = editedBadgeText.isEmpty ? badgeText : editedBadgeText
                            saveBadge?(finalText)
                            editedBadgeText = ""
                            withAnimation(.easeInOut) {
                                isEditingBadge = false
                            }
                        }

                        Button {
                            HapticsManager.shared.selection()
                            let finalText = editedBadgeText.isEmpty ? badgeText : editedBadgeText
                            saveBadge?(finalText)
                            editedBadgeText = ""
                            withAnimation(.easeInOut) {
                                isEditingBadge = false
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(fill.first?.idealTextColor() ?? .black, .green)
                        }
                        .contentShape(Circle())
                        .hoverEffect(.lift)
                    }
                    .onAppear {
                        // Ensure the TextField receives focus right after it appears
                        DispatchQueue.main.async {
                            badgeFocused = true
                        }
                    }
                }
            }
            .onChange(of: isEditingBadge) { _, to in
                if to == true {
                    DispatchQueue.main.async {
                        badgeFocused = true
                    }
                }
            }
            .frame(height: 20)
            .padding(8)
            .glassIfAvailable(
                GlassConfiguration(style: .clear)
            )
            .padding(8)
            .mask(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentTransition(.interpolate)
            .animation(.bouncy, value: isEditingBadge)
        }
    }
    
    // MARK: - Menu Content
    @ViewBuilder
    private var menuContent: some View {
        if showOverlays {
            if let menu = menu {
                Menu {
                    menu
                } label: {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "ellipsis")
                        .imageScale(.large)
                        .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                        .frame(width: 8, height: 8)
                        .padding(12)
                        .background(
                            Circle().fill(.clear)
                        )
                        .glassIfAvailable(
                            GlassConfiguration(style: .clear)
                        )
                        .contentShape(Circle())
                        .hoverEffect(.lift)
                        .contentTransition(.symbolEffect(.replace))
                }
                .menuStyle(.automatic)
                .padding(8)
                .onChange(of: showCopiedFeedback) { _, newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopiedFeedback = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Context Menu Content
    @ViewBuilder
    private var contextMenuContent: some View {
        if let contextMenu {
            contextMenu
        } else {
            EmptyView()
        }
    }

    // MARK: - Drag Support
    private func provideDragItem() -> NSItemProvider {
        // Always provide a PNG preview of the swatch
        let size = CGSize(width: 512, height: 512)
        guard let imageData = renderSwatchImage(size: size) else {
            return NSItemProvider()
        }

        let provider = NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.png.identifier)

        // For single colors, include full JSON data for cross-device drops and ID for same-device palette management
        if fill.count == 1, let first = fill.first {
            // Register full JSON color data (works cross-device via Universal Control)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.opaliteColor.identifier, visibility: .all) { completion in
                do {
                    let jsonData = try first.jsonRepresentation()
                    completion(jsonData, nil)
                } catch {
                    completion(nil, error)
                }
                return nil
            }

            // Also include color ID for efficient same-device palette management
            if let idData = first.id.uuidString.data(using: .utf8) {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.opaliteColorID.identifier, visibility: .all) { completion in
                    completion(idData, nil)
                    return nil
                }
            }
        }

        return provider
    }

    /// Renders the swatch as PNG image data for drag and drop or sharing.
    ///
    /// Creates a gradient image from the swatch colors with an optional badge overlay
    /// showing the color name or hex code.
    ///
    /// - Parameter size: The size of the output image
    /// - Returns: PNG data of the rendered swatch, or nil if rendering fails
    private func renderSwatchImage(size: CGSize) -> Data? {
        let badgeOverlay = Group {
            if showOverlays {
                Text(badgeText)
                    .foregroundStyle(fill.first?.idealTextColor() ?? .black)
                    .bold()
                    .frame(height: 20)
                    .padding(8)
                    .glassIfAvailable(
                        GlassConfiguration(style: .clear)
                    )
                    .padding(8)
                    .mask(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
        }

        let swatchView = Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: fill.map { $0.swiftUIColor }),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                badgeOverlay
                    .frame(maxWidth: 500, alignment: .leading)
            }

        return ColorImageRenderer.renderViewAsPNGData(swatchView, size: size, opaque: false)
    }
}

#Preview("With Menu") {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State private var isEditing: Bool? = true

    var body: some View {
        let sampleColors: [OpaliteColor] = [OpaliteColor.sample, OpaliteColor.sample2]

        VStack {
            Toggle("Editing Badge", isOn: Binding(
                get: { isEditing ?? false },
                set: { isEditing = $0 }
            ))
            .padding(.bottom)

            HStack(alignment: .bottom) {
                SwatchView(
                    fill: [sampleColors.first!],
                    width: 250,
                    height: 250,
                    badgeText: "Sample Color",
                    showOverlays: true,
                    isEditingBadge: .constant(nil),
                    menu: {
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

                SwatchView(
                    fill: [OpaliteColor(red: 0, green: 0, blue: 0)],
                    width: 250,
                    height: 250,
                    badgeText: "Sample Color",
                    showOverlays: true,
                    isEditingBadge: $isEditing,
                    menu: {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )

                SwatchView(
                    fill: [OpaliteColor(red: 255, green: 255, blue: 255)],
                    width: 250,
                    height: 250,
                    badgeText: "Sample Color",
                    showOverlays: true,
                    isEditingBadge: .constant(nil),
                    menu: {
                        Button("Edit") {}
                        Button("Duplicate") {}
                        Divider()
                        Button(role: .destructive) { } label: { Text("Delete") }
                    }
                )

                SwatchView(
                    fill: [OpaliteColor(red: 1, green: 1.0, blue: 0.5)],
                      width: 75,
                      height: 75,
                    badgeText: "",
                    showOverlays: false
                  )
            }

            SwatchView(
                fill: sampleColors,
                height: 350,
                badgeText: "Sample Color",
                showOverlays: false,
                isEditingBadge: $isEditing
            )
        }
        .padding()
    }
}


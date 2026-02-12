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
    private var palette: OpalitePalette?
    @State private var isDropTargeted: Bool = false
    private var matchedNamespace: Namespace.ID?
    private var matchedID: AnyHashable?

    // Color blindness simulation
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var colorBlindnessMode: ColorBlindnessMode {
        ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
    }

    /// Color with color blindness simulation applied (if active)
    private var displayColor: OpaliteColor {
        [color].simulatingColorBlindness(colorBlindnessMode).first ?? color
    }

    private var color: OpaliteColor
    private var width: CGFloat?
    private var height: CGFloat?
    private var cornerRadius: CGFloat
    private var showBorder: Bool
    private var badgeText: String
    private var showOverlays: Bool
    @Binding var isEditingBadge: Bool?
    private var saveBadge: ((String) -> Void)?
    private var allowBadgeTapToEdit: Bool
    private var menu: AnyView?
    private var contextMenu: AnyView?
    @Binding var showCopiedFeedback: Bool

    // Name suggestions support
    private var nameSuggestions: [String]
    private var isLoadingSuggestions: Bool
    private var onSuggestionSelected: ((String) -> Void)?

    // Drag state
    private var onDragStarted: (() -> Void)?
    @Binding var isDragging: Bool

    @State private var editedBadgeText: String = ""
    @FocusState private var badgeFocused: Bool

    // Cached drag image to avoid regenerating on every drag
    @State private var cachedDragImage: Data?
    @State private var cachedDragImageKey: String = ""

    init(
        color: OpaliteColor,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = 16,
        showBorder: Bool = true,
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
        showCopiedFeedback: Binding<Bool> = .constant(false),
        nameSuggestions: [String] = [],
        isLoadingSuggestions: Bool = false,
        onSuggestionSelected: ((String) -> Void)? = nil,
        onDragStarted: (() -> Void)? = nil,
        isDragging: Binding<Bool> = .constant(false)
    ) {
        self.color = color
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
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
        self.nameSuggestions = nameSuggestions
        self.isLoadingSuggestions = isLoadingSuggestions
        self.onSuggestionSelected = onSuggestionSelected
        self.onDragStarted = onDragStarted
        self._isDragging = isDragging
    }

    init<MenuContent: View>(
        color: OpaliteColor,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = 16,
        showBorder: Bool = true,
        badgeText: String,
        showOverlays: Bool,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        allowBadgeTapToEdit: Bool = false,
        palette: OpalitePalette? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        showCopiedFeedback: Binding<Bool> = .constant(false),
        nameSuggestions: [String] = [],
        isLoadingSuggestions: Bool = false,
        onSuggestionSelected: ((String) -> Void)? = nil,
        onDragStarted: (() -> Void)? = nil,
        isDragging: Binding<Bool> = .constant(false),
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.init(
            color: color,
            width: width,
            height: height,
            cornerRadius: cornerRadius,
            showBorder: showBorder,
            badgeText: badgeText,
            showOverlays: showOverlays,
            isEditingBadge: isEditingBadge,
            saveBadge: saveBadge,
            allowBadgeTapToEdit: allowBadgeTapToEdit,
            palette: palette,
            matchedNamespace: matchedNamespace,
            matchedID: matchedID,
            menu: AnyView(menu()),
            showCopiedFeedback: showCopiedFeedback,
            nameSuggestions: nameSuggestions,
            isLoadingSuggestions: isLoadingSuggestions,
            onSuggestionSelected: onSuggestionSelected,
            onDragStarted: onDragStarted,
            isDragging: isDragging
        )
    }

    init<ContextMenuContent: View>(
        color: OpaliteColor,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = 16,
        showBorder: Bool = true,
        badgeText: String,
        showOverlays: Bool,
        isEditingBadge: Binding<Bool?> = .constant(nil),
        saveBadge: ((String) -> Void)? = nil,
        allowBadgeTapToEdit: Bool = false,
        palette: OpalitePalette? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        showCopiedFeedback: Binding<Bool> = .constant(false),
        nameSuggestions: [String] = [],
        isLoadingSuggestions: Bool = false,
        onSuggestionSelected: ((String) -> Void)? = nil,
        onDragStarted: (() -> Void)? = nil,
        isDragging: Binding<Bool> = .constant(false),
        @ViewBuilder contextMenu: @escaping () -> ContextMenuContent
    ) {
        self.init(
            color: color,
            width: width,
            height: height,
            cornerRadius: cornerRadius,
            showBorder: showBorder,
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
            showCopiedFeedback: showCopiedFeedback,
            nameSuggestions: nameSuggestions,
            isLoadingSuggestions: isLoadingSuggestions,
            onSuggestionSelected: onSuggestionSelected,
            onDragStarted: onDragStarted,
            isDragging: isDragging
        )
    }

    // MARK: - The View
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(displayColor.swiftUIColor)
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.thinMaterial, lineWidth: 5)
                }
            }
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
                RoundedRectangle(cornerRadius: cornerRadius)
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
            .if(isEditingBadge != true) { view in
                view.onDrag {
                    onDragStarted?()
                    return provideDragItem()
                } preview: {
                    // Clean preview without material overlay that doesn't render well during drag
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(displayColor.swiftUIColor)
                        .frame(width: width ?? 100, height: height ?? 100)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityAddTraits(.isButton)
    }

    private var accessibilityDescription: String {
        let name = color.name ?? "Unnamed color"
        return "\(name), \(color.hexString)"
    }

    // MARK: - Badge Content
    @ViewBuilder
    private var badgeContent: some View {
        if showOverlays {
            VStack(alignment: .leading, spacing: 8) {
                badgeEditableContent
                    .frame(height: 20)
                    .padding(8)
                    .glassIfAvailable(
                        GlassConfiguration(style: .clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentTransition(.interpolate)
                    .animation(.bouncy, value: isEditingBadge)

                // Name suggestions (shown when editing)
                if isEditingBadge == true {
                    suggestionsView
                }
            }
            .padding(8)
            .onChange(of: isEditingBadge) { _, newValue in
                if newValue == true {
                    DispatchQueue.main.async {
                        badgeFocused = true
                    }
                }
            }
        }
    }

    private var isEditing: Bool {
        isEditingBadge == true
    }

    @ViewBuilder
    private var badgeEditableContent: some View {
        ZStack(alignment: .leading) {
            if !isEditing {
                // Read-only state
                Text(badgeText)
                    .foregroundStyle(displayColor.idealTextColor())
                    .bold()
                    .transition(.blurReplace)
                    .if(allowBadgeTapToEdit && saveBadge != nil) { view in
                        view.onTapGesture {
                            editedBadgeText = badgeText
                            withAnimation(.bouncy) {
                                isEditingBadge = true
                            }
                        }
                    }
            } else {
                // Editing state
                HStack(spacing: 8) {
                    TextField("Name", text: $editedBadgeText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(displayColor.idealTextColor())
                        .bold()
                        .submitLabel(.done)
                        .focused($badgeFocused)
                        .onSubmit {
                            saveBadgeText()
                        }

                    Button {
                        HapticsManager.shared.selection()
                        saveBadgeText()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(.black, .green)
                    }
                    .contentShape(Circle())
                    .hoverEffect(.lift)
                }
                .transition(.blurReplace)
            }
        }
    }

    private func saveBadgeText() {
        let finalText = editedBadgeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            saveBadge?(finalText)
        }
        editedBadgeText = ""
        withAnimation(.easeInOut) {
            isEditingBadge = false
        }
    }

    // MARK: - Suggestions View
    @ViewBuilder
    private var suggestionsView: some View {
        Group {
            if isLoadingSuggestions {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating suggestions...")
                        .font(.caption)
                        .foregroundStyle(color.idealTextColor())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if !nameSuggestions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(nameSuggestions.enumerated()), id: \.element) { _, suggestion in
                        Button {
                            HapticsManager.shared.selection()
                            onSuggestionSelected?(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(color.idealTextColor())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: 5)))
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoadingSuggestions)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: nameSuggestions)
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
                        .foregroundStyle(showCopiedFeedback ? .green : displayColor.idealTextColor())
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
    /// Uses explicit contextMenu if provided, otherwise falls back to menu content for right-click support
    @ViewBuilder
    private var contextMenuContent: some View {
        if let contextMenu {
            contextMenu
        } else if let menu {
            menu
        } else {
            EmptyView()
        }
    }

    // MARK: - Drag Support

    /// Creates a cache key based on color values
    private var dragImageCacheKey: String {
        return "\(color.id)-\(color.red)-\(color.green)-\(color.blue)-\(color.alpha)"
    }

    private func provideDragItem() -> NSItemProvider {
        // Use cached image if available, otherwise render and cache
        let currentKey = dragImageCacheKey
        let imageData: Data?

        if cachedDragImageKey == currentKey, let cached = cachedDragImage {
            imageData = cached
        } else {
            let size = CGSize(width: 512, height: 512)
            let rendered = renderSwatchImage(size: size)
            imageData = rendered
            // Update cache for next drag
            if rendered != nil {
                cachedDragImage = rendered
                cachedDragImageKey = currentKey
            }
        }

        guard let imageData else {
            return NSItemProvider()
        }

        let provider = NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.png.identifier)

        // Set filename to color name if available, otherwise use hex code
        let filename: String
        if let name = color.name, !name.isEmpty {
            filename = "\(name).png"
        } else {
            // Remove the # prefix from hex string for cleaner filename
            let hex = color.hexString.hasPrefix("#") ? String(color.hexString.dropFirst()) : color.hexString
            filename = "\(hex).png"
        }
        provider.suggestedName = filename

        // Include full JSON data for cross-device drops and ID for same-device palette management
        // Register full JSON color data (works cross-device via Universal Control)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.opaliteColor.identifier, visibility: .all) { completion in
            do {
                let jsonData = try self.color.jsonRepresentation()
                completion(jsonData, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }

        // Also include color ID for efficient same-device palette management
        if let idData = color.id.uuidString.data(using: .utf8) {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.opaliteColorID.identifier, visibility: .all) { completion in
                completion(idData, nil)
                return nil
            }
        }

        return provider
    }

    /// Renders the swatch as PNG image data for drag and drop or sharing.
    ///
    /// Creates a solid color rectangle without any badge or overlay,
    /// providing a clean color swatch for external use.
    ///
    /// - Parameter size: The size of the output image
    /// - Returns: PNG data of the rendered swatch, or nil if rendering fails
    private func renderSwatchImage(size: CGSize) -> Data? {
        let swatchView = Rectangle()
            .fill(displayColor.swiftUIColor)
            .frame(width: size.width, height: size.height)

        return ColorImageRenderer.renderViewAsPNGData(swatchView, size: size, opaque: false)
    }
}

#Preview("With Menu") {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State private var isEditing: Bool? = true

    var body: some View {
        VStack {
            Toggle("Editing Badge", isOn: Binding(
                get: { isEditing ?? false },
                set: { isEditing = $0 }
            ))
            .padding(.bottom)

            HStack(alignment: .bottom) {
                SwatchView(
                    color: OpaliteColor.sample,
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
                    color: OpaliteColor(red: 0, green: 0, blue: 0),
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
                    color: OpaliteColor(red: 1, green: 1, blue: 1),
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
                    color: OpaliteColor(red: 1, green: 1.0, blue: 0.5),
                    width: 75,
                    height: 75,
                    badgeText: "",
                    showOverlays: false
                )
            }

            SwatchView(
                color: OpaliteColor.sample2,
                height: 350,
                badgeText: "Sample Color",
                showOverlays: false,
                isEditingBadge: $isEditing
            )
        }
        .padding()
    }
} 

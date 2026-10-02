//
//  SwatchView.swift
//  OpaliteFeatureShared
//
//  The color swatch — the one visual every surface shares. A rounded fill with an
//  optional name badge (tap-to-rename with Apple Intelligence suggestions), an optional
//  overflow menu, a context menu, drag support, color-vision simulation, and a
//  checkerboard behind translucent colors. Generic over its menus so no AnyView.
//

#if !os(watchOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

public struct SwatchView<MenuContent: View, ContextMenuContent: View>: View {
    private let color: OpaliteColor
    private let width: CGFloat?
    private let height: CGFloat?
    private let cornerRadius: CGFloat
    private let showsBorder: Bool
    private let showsOverlays: Bool
    private let badgeText: String?
    private let menu: () -> MenuContent
    private let contextMenu: () -> ContextMenuContent
    private let hasMenu: Bool
    private let hasContextMenu: Bool
    private let matchedNamespace: Namespace.ID?
    private let matchedID: AnyHashable?

    @Binding private var isEditingBadge: Bool
    private let onRename: ((String) -> Void)?
    private let nameSuggestions: [String]
    private let isLoadingSuggestions: Bool
    private let onSuggestionSelected: ((String) -> Void)?
    private let onDragStarted: (() -> Void)?
    @Binding private var isDragging: Bool

    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editedText = ""
    @FocusState private var badgeFocused: Bool
    @State private var dragImage: Data?
    @State private var dragImageKey = ""

    public init(
        color: OpaliteColor,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = Brand.Radius.swatch,
        showsBorder: Bool = true,
        showsOverlays: Bool = true,
        badgeText: String? = nil,
        isEditingBadge: Binding<Bool> = .constant(false),
        onRename: ((String) -> Void)? = nil,
        nameSuggestions: [String] = [],
        isLoadingSuggestions: Bool = false,
        onSuggestionSelected: ((String) -> Void)? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        onDragStarted: (() -> Void)? = nil,
        isDragging: Binding<Bool> = .constant(false),
        @ContentBuilder menu: @escaping () -> MenuContent,
        @ContentBuilder contextMenu: @escaping () -> ContextMenuContent
    ) {
        self.color = color
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.showsBorder = showsBorder
        self.showsOverlays = showsOverlays
        self.badgeText = badgeText
        self._isEditingBadge = isEditingBadge
        self.onRename = onRename
        self.nameSuggestions = nameSuggestions
        self.isLoadingSuggestions = isLoadingSuggestions
        self.onSuggestionSelected = onSuggestionSelected
        self.matchedNamespace = matchedNamespace
        self.matchedID = matchedID
        self.onDragStarted = onDragStarted
        self._isDragging = isDragging
        self.menu = menu
        self.contextMenu = contextMenu
        self.hasMenu = MenuContent.self != EmptyView.self
        self.hasContextMenu = ContextMenuContent.self != EmptyView.self
    }

    private var mode: ColorBlindnessMode { ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off }
    private var displayColor: Color { color.simulatedSwiftUIColor(mode) }
    private var onDark: Bool { !ColorBlindnessSimulator.simulate(color.rgba, mode: mode).prefersDarkText }
    private var label: String { badgeText ?? color.displayName }

    public var body: some View {
        swatchShape
            .frame(width: width)
            .frame(minHeight: height)
            .overlay(alignment: .topLeading) { if showsOverlays { badge.frame(maxWidth: 500, alignment: .leading) } }
            .overlay(alignment: .bottomTrailing) { if showsOverlays, hasMenu { menuButton } }
            .if(hasContextMenu) { $0.contextMenu { contextMenu() } }
            .if(!hasContextMenu && hasMenu) { $0.contextMenu { menu() } }
            .if(matchedNamespace != nil && matchedID != nil) { $0.matchedGeometryEffect(id: matchedID!, in: matchedNamespace!) }
            .if(!isEditingBadge) { view in
                #if os(tvOS)
                view
                #else
                view.draggable(DraggedColor(id: color.id)) {
                    dragPreview
                }
                .onDrag {
                    onDragStarted?()
                    return dragProvider()
                } preview: { dragPreview }
                #endif
            }
            .opacity(isDragging ? 0.2 : 1)
            .animation(reduceMotion ? nil : .easeIn(duration: 0.2), value: isDragging)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(accessibilityDescription))
    }

    private var swatchShape: some View {
        ZStack {
            if color.alpha < 1 {
                Checkerboard()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(displayColor)
            if showsBorder {
                // Primary at low opacity: dark on light backgrounds, light on dark ones, so
                // white and black swatches keep an edge against either grouped background.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.2), lineWidth: 1)
            }
        }
    }

    private var accessibilityDescription: String {
        color.hasName ? "\(color.displayName), \(color.hexString)" : String(localized: "Unnamed color, \(color.hexString)")
    }

    // MARK: - Badge

    @ContentBuilder
    private var badge: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            if isEditingBadge {
                editingBadge
            } else {
                HexBadge(label, onDark: onDark, font: .subheadline.weight(.semibold))
                    .if(onRename != nil) { view in
                        view.onTapGesture { beginEditing() }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint(Text("Double-tap to rename"))
                    }
            }
            if isEditingBadge { suggestions }
        }
        .padding(Brand.Space.sm)
        .animation(reduceMotion ? nil : .bouncy, value: isEditingBadge)
        .onChange(of: isEditingBadge) { _, editing in
            if editing {
                editedText = color.name ?? ""
                badgeFocused = true
            }
        }
    }

    private var editingBadge: some View {
        HStack(spacing: Brand.Space.sm) {
            TextField(String(localized: "Name"), text: $editedText)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(onDark ? .white : .black)
                .submitLabel(.done)
                .focused($badgeFocused)
                #if os(iOS) || os(visionOS)
                .textInputAutocapitalization(.words)
                #endif
                .onSubmit(commitEditing)
                .accessibilityLabel(Text("Color name"))
            Button {
                Haptics.selection()
                commitEditing()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.large)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Save name"))
        }
        .padding(.horizontal, Brand.Space.sm)
        .padding(.vertical, Brand.Space.xs)
        .background(Capsule(style: .continuous).fill((onDark ? Color.black : Color.white).opacity(0.28)))
        .transition(.blurReplace)
    }

    private func beginEditing() {
        guard onRename != nil else { return }
        editedText = color.name ?? ""
        withAnimation(reduceMotion ? nil : .bouncy) { isEditingBadge = true }
    }

    private func commitEditing() {
        let text = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onRename?(text) }
        editedText = ""
        withAnimation(reduceMotion ? nil : .easeInOut) { isEditingBadge = false }
    }

    @ContentBuilder
    private var suggestions: some View {
        if isLoadingSuggestions {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Thinking of names…")
                    .font(.caption)
                    .foregroundStyle(onDark ? .white : .black)
            }
            .padding(.horizontal, Brand.Space.sm)
            .padding(.vertical, Brand.Space.xs)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if !nameSuggestions.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(nameSuggestions, id: \.self) { suggestion in
                    Button {
                        Haptics.selection()
                        onSuggestionSelected?(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(onDark ? .white : .black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Menu

    private var menuButton: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(onDark ? .white : .black)
                .frame(width: 32, height: 32)
                .background(Circle().fill((onDark ? Color.black : Color.white).opacity(0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverLift()
        .padding(Brand.Space.sm)
        .accessibilityLabel(Text("More actions for \(label)"))
    }

    // MARK: - Drag

    private var dragPreview: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(displayColor)
            .overlay(alignment: .topLeading) {
                if showsOverlays { HexBadge(label, onDark: onDark).padding(Brand.Space.sm) }
            }
            .frame(width: width ?? 100, height: height ?? 100)
    }

    #if !os(tvOS)
    private func dragProvider() -> NSItemProvider {
        let key = "\(color.id)-\(color.hexString)-\(color.alpha)"
        if dragImageKey != key {
            dragImage = ImageRendering.solidPNG(color.rgba)
            dragImageKey = key
        }
        return ColorDragDrop.itemProvider(for: color, pngData: dragImage)
    }
    #endif
}

// MARK: - Transferable payload

#if !os(tvOS)
/// The modern `Transferable` form of a dragged color (same-device moves).
nonisolated public struct DraggedColor: Codable, Transferable, Sendable {
    public let id: UUID
    public init(id: UUID) { self.id = id }
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .opaliteColorID)
    }
}
#endif

// MARK: - Convenience inits

extension SwatchView where ContextMenuContent == EmptyView {
    public init(
        color: OpaliteColor,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = Brand.Radius.swatch,
        showsBorder: Bool = true,
        showsOverlays: Bool = true,
        badgeText: String? = nil,
        isEditingBadge: Binding<Bool> = .constant(false),
        onRename: ((String) -> Void)? = nil,
        nameSuggestions: [String] = [],
        isLoadingSuggestions: Bool = false,
        onSuggestionSelected: ((String) -> Void)? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        onDragStarted: (() -> Void)? = nil,
        isDragging: Binding<Bool> = .constant(false),
        @ContentBuilder menu: @escaping () -> MenuContent
    ) {
        self.init(color: color, width: width, height: height, cornerRadius: cornerRadius, showsBorder: showsBorder, showsOverlays: showsOverlays, badgeText: badgeText, isEditingBadge: isEditingBadge, onRename: onRename, nameSuggestions: nameSuggestions, isLoadingSuggestions: isLoadingSuggestions, onSuggestionSelected: onSuggestionSelected, matchedNamespace: matchedNamespace, matchedID: matchedID, onDragStarted: onDragStarted, isDragging: isDragging, menu: menu, contextMenu: { EmptyView() })
    }
}

extension SwatchView where MenuContent == EmptyView, ContextMenuContent == EmptyView {
    public init(
        color: OpaliteColor,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = Brand.Radius.swatch,
        showsBorder: Bool = true,
        showsOverlays: Bool = true,
        badgeText: String? = nil,
        matchedNamespace: Namespace.ID? = nil,
        matchedID: AnyHashable? = nil,
        onDragStarted: (() -> Void)? = nil,
        isDragging: Binding<Bool> = .constant(false)
    ) {
        self.init(color: color, width: width, height: height, cornerRadius: cornerRadius, showsBorder: showsBorder, showsOverlays: showsOverlays, badgeText: badgeText, matchedNamespace: matchedNamespace, matchedID: matchedID, onDragStarted: onDragStarted, isDragging: isDragging, menu: { EmptyView() }, contextMenu: { EmptyView() })
    }
}

#if DEBUG
#Preview("Swatches") {
    HStack(alignment: .bottom, spacing: 16) {
        SwatchView(color: .sample, width: 200, height: 200) {
            Button("Edit") {}
            Button("Delete", role: .destructive) {}
        }
        SwatchView(color: OpaliteColor(name: "Glass", red: 0.2, green: 0.8, blue: 0.9, alpha: 0.5), width: 150, height: 150)
        SwatchView(color: .sample4, width: 75, height: 75, showsOverlays: false)
    }
    .padding()
    .previewEnvironment()
}
#endif
#endif

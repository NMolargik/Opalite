//
//  SwatchRow.swift
//  OpaliteFeatureShared
//
//  A horizontal strip of swatches belonging to one palette (or the loose colors), acting
//  as a drop target that moves/imports colors into it. Selection is reported through
//  `onSelect`, so features decide what tapping means (push detail, pick for canvas…).
//

#if !os(watchOS) && !os(tvOS)
import SwiftUI
import UniformTypeIdentifiers
import OpaliteCore
import OpaliteDesignSystem

public struct SwatchRow<MenuContent: View>: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors: [OpaliteColor]
    private let palette: OpalitePalette?
    private let swatchSize: SwatchSize
    private let acceptsDrops: Bool
    private let selectedIDs: Set<UUID>
    private let onSelect: ((OpaliteColor) -> Void)?
    private let onCreate: (() -> Void)?
    private let menu: (OpaliteColor) -> MenuContent
    private let matchedNamespace: Namespace.ID?

    @State private var isDropTargeted = false
    @State private var draggingColorID: UUID?
    @State private var dragResetTask: Task<Void, Never>?

    public init(
        colors: [OpaliteColor],
        palette: OpalitePalette?,
        swatchSize: SwatchSize,
        acceptsDrops: Bool = true,
        selectedIDs: Set<UUID> = [],
        matchedNamespace: Namespace.ID? = nil,
        onSelect: ((OpaliteColor) -> Void)? = nil,
        onCreate: (() -> Void)? = nil,
        @ContentBuilder menu: @escaping (OpaliteColor) -> MenuContent
    ) {
        self.colors = colors
        self.palette = palette
        self.swatchSize = swatchSize
        self.acceptsDrops = acceptsDrops
        self.selectedIDs = selectedIDs
        self.matchedNamespace = matchedNamespace
        self.onSelect = onSelect
        self.onCreate = onCreate
        self.menu = menu
    }

    public var body: some View {
        Group {
            if colors.isEmpty {
                emptyRow
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: Brand.Space.md) {
                        ForEach(colors) { color in
                            cell(for: color)
                        }
                    }
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.xs)
                }
                .scrollClipDisabled()
                .scrollIndicators(.hidden)
            }
        }
        .if(acceptsDrops) { view in
            view
                .dropDestination(for: DraggedColor.self) { items, _ in
                    guard let item = items.first, let color = portfolio.color(withID: item.id) else { return false }
                    endDrag()
                    guard color.palette?.id != palette?.id else { return true }
                    Haptics.lightImpact()
                    portfolio.move(color, to: palette)
                    return true
                } isTargeted: { isDropTargeted = $0 }
                .onDrop(of: ColorDragDrop.acceptedTypes, isTargeted: $isDropTargeted) { providers in
                    endDrag()
                    return ColorDragDrop.handleDrop(providers, into: palette, portfolio: portfolio)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        .opacity(isDropTargeted ? 1 : 0)
                        .padding(.horizontal, Brand.Space.sm)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isDropTargeted)
                )
        }
    }

    private var emptyRow: some View {
        HStack(spacing: Brand.Space.md) {
            Image(systemName: "arrow.turn.down.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            if let onCreate {
                Button {
                    Haptics.selection()
                    onCreate()
                } label: {
                    Label("Add a Color", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .glassActionButton(tint: .opalitePurple, prominent: false)
                .hoverHighlight()
                .accessibilityHint(Text("Opens the color editor"))
            } else {
                Text("No colors yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, Brand.Space.xxl)
        .padding(.vertical, Brand.Space.sm)
    }

    @ContentBuilder
    private func cell(for color: OpaliteColor) -> some View {
        let swatch = SwatchView(
            color: color,
            width: swatchSize.side,
            height: swatchSize.side,
            cornerRadius: swatchSize.cornerRadius,
            showsOverlays: swatchSize.showsOverlays,
            matchedNamespace: matchedNamespace,
            matchedID: color.id,
            onDragStarted: { beginDrag(color.id) },
            isDragging: Binding(get: { draggingColorID == color.id }, set: { if !$0 { draggingColorID = nil } }),
            menu: { menu(color) }
        )
        .overlay(alignment: .topTrailing) {
            if onSelect != nil, !selectedIDs.isEmpty || !swatchSize.showsOverlays {
                let selected = selectedIDs.contains(color.id)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
        }

        if let onSelect {
            Button {
                Haptics.selection()
                onSelect(color)
            } label: { swatch }
            .buttonStyle(.plain)
            .hoverLift()
            .accessibilityAddTraits(selectedIDs.contains(color.id) ? .isSelected : [])
        } else {
            swatch
        }
    }

    private func beginDrag(_ id: UUID) {
        draggingColorID = id
        dragResetTask?.cancel()
        dragResetTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { draggingColorID = nil }
        }
    }

    private func endDrag() {
        dragResetTask?.cancel()
        draggingColorID = nil
    }
}

extension SwatchRow where MenuContent == EmptyView {
    public init(colors: [OpaliteColor], palette: OpalitePalette?, swatchSize: SwatchSize, acceptsDrops: Bool = true, selectedIDs: Set<UUID> = [], matchedNamespace: Namespace.ID? = nil, onSelect: ((OpaliteColor) -> Void)? = nil, onCreate: (() -> Void)? = nil) {
        self.init(colors: colors, palette: palette, swatchSize: swatchSize, acceptsDrops: acceptsDrops, selectedIDs: selectedIDs, matchedNamespace: matchedNamespace, onSelect: onSelect, onCreate: onCreate, menu: { _ in EmptyView() })
    }
}

#if DEBUG
#Preview("Swatch rows") {
    VStack(alignment: .leading, spacing: 24) {
        SwatchRow(colors: OpaliteColor.samples, palette: nil, swatchSize: .small)
        SwatchRow(colors: OpaliteColor.samples, palette: nil, swatchSize: .medium) { color in
            Button("Edit \(color.displayName)") {}
        }
        SwatchRow(colors: [], palette: nil, swatchSize: .medium, onCreate: {})
    }
    .padding(.vertical)
    .previewEnvironment()
}
#endif
#endif

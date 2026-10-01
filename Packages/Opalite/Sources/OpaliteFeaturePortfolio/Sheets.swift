//
//  Sheets.swift
//  OpaliteFeaturePortfolio
//
//  The Portfolio's modal sheets: quick-add by hex, palette reordering, archived palettes,
//  moving colors into a palette, and choosing a canvas to link.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - Quick add by hex

struct QuickAddHexSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = QuickAddHexInput()
    @State private var text = ""
    @FocusState private var isFocused: Bool

    let onAdd: (QuickAddHexInput) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Brand.Space.xl) {
                preview
                field
                Spacer(minLength: 0)
            }
            .padding(Brand.Space.lg)
            .frame(maxWidth: Brand.readableWidth)
            .frame(maxWidth: .infinity)
            .navigationTitle("Add by Hex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.selection()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(!input.isValid)
                        .accessibilityIdentifier("quickAddHex.add")
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var preview: some View {
        ZStack {
            if let rgba = input.rgba {
                if rgba.alpha < 1 { Checkerboard() }
                Rectangle().fill(rgba.color)
                HexBadge(input.displayHex ?? rgba.hexString, onDark: !rgba.prefersDarkText, font: .title3.weight(.semibold))
            } else {
                Rectangle().fill(.quaternary)
                VStack(spacing: Brand.Space.sm) {
                    Image(systemName: "number")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                    Text("Type a hex code")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
        .animation(.snappy, value: input)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(input.displayHex.map { "Preview, \($0)" } ?? String(localized: "Preview, no color yet")))
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            HStack(spacing: Brand.Space.xs) {
                Text("#")
                    .foregroundStyle(.secondary)
                TextField("RRGGBB", text: $text)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit { if input.isValid { add() } }
                    .onChange(of: text) { _, newValue in
                        input.update(newValue)
                        if input.text != newValue { text = input.text }
                    }
                    .accessibilityIdentifier("quickAddHex.field")
                    .accessibilityLabel(Text("Hex code"))
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Clear"))
                }
            }
            .font(.title2.monospaced())
            .padding(Brand.Space.md)
            .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))

            if let message = input.validationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if let rgba = input.rgba {
                Text(rgba.rgbString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private func add() {
        guard input.isValid else { return }
        Haptics.mediumImpact()
        onAdd(input)
        dismiss()
    }
}

// MARK: - Palette order

struct PaletteOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PortfolioModel.self) private var portfolio

    @State private var ids: [UUID] = []

    private var ordered: [OpalitePalette] {
        ids.compactMap { portfolio.palette(withID: $0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordered) { palette in
                        PaletteRowLabel(name: palette.name, colors: portfolio.colors(in: palette).map(\.rgba))
                    }
                    .onMove { source, destination in
                        Haptics.selection()
                        ids.move(fromOffsets: source, toOffset: destination)
                    }
                    .reorderableIfAvailable()
                } footer: {
                    Text("Drag to reorder. This is the order palettes appear in your Portfolio and exports.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.selection()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.selection()
                        portfolio.reorderPalettes(ids)
                        dismiss()
                    }
                }
            }
            .onAppear { ids = portfolio.orderedPalettes.map(\.id) }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Archived palettes

struct ArchivedPalettesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var paletteToDelete: OpalitePalette?

    var body: some View {
        NavigationStack {
            Group {
                if portfolio.archivedPalettes.isEmpty {
                    EmptyStateView("No Archived Palettes", systemImage: "archivebox", description: String(localized: "Palettes you archive appear here until you restore or delete them."))
                } else {
                    List {
                        Section {
                            ForEach(portfolio.archivedPalettes) { palette in
                                HStack {
                                    PaletteRowLabel(name: palette.name, colors: portfolio.colors(in: palette).map(\.rgba))
                                    Button {
                                        restore(palette)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward.circle")
                                            .labelStyle(.iconOnly)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(Text("Restore \(palette.name)"))
                                }
                                .swipeActions(edge: .leading) {
                                    Button { restore(palette) } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                                        .tint(.opalitePurple)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { paletteToDelete = palette } label: { Label("Delete", systemImage: "trash") }
                                }
                                .contextMenu {
                                    Button { restore(palette) } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                                    Button(role: .destructive) { paletteToDelete = palette } label: { Label("Delete…", systemImage: "trash") }
                                }
                            }
                        } footer: {
                            Text("Restoring returns a palette and its colors to the Portfolio. Deleting removes the palette and its colors.")
                        }
                    }
                }
            }
            .navigationTitle("Archived Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete \(paletteToDelete?.name ?? "")?",
                isPresented: Binding(get: { paletteToDelete != nil }, set: { if !$0 { paletteToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete Palette and Colors", role: .destructive) {
                    if let palette = paletteToDelete {
                        withAnimation(reduceMotion ? nil : .snappy) { portfolio.delete(palette, deleteColors: true) }
                        toasts.showSuccess(String(localized: "Deleted \(palette.name)"), systemImage: "trash.fill")
                    }
                    paletteToDelete = nil
                }
                Button("Cancel", role: .cancel) { paletteToDelete = nil }
            } message: {
                Text("This can't be undone.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func restore(_ palette: OpalitePalette) {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .snappy) { portfolio.setArchived(palette, false) }
        toasts.showSuccess(String(localized: "Restored \(palette.name)"), systemImage: "archivebox")
    }
}

// MARK: - Palette selection (move colors)

struct PaletteSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toasts
    @Environment(\.onyxEntitlement) private var entitlement

    let colors: [OpaliteColor]
    var onMoved: (() -> Void)? = nil

    @State private var newPaletteName = ""
    @FocusState private var isNameFocused: Bool

    private var title: String {
        colors.count == 1 ? String(localized: "Move to Palette") : String(localized: "Move \(colors.count) Colors")
    }

    private var canCreate: Bool { !newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isAtPaletteLimit: Bool { !OnyxGate(hasOnyx: entitlement.hasOnyx).canCreatePalette(currentCount: portfolio.palettes.count) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Brand.Space.sm) {
                        TextField(String(localized: "New palette name"), text: $newPaletteName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($isNameFocused)
                            .onSubmit { if canCreate { createAndMove() } }
                        Button {
                            Haptics.selection()
                            createAndMove()
                        } label: {
                            Label("Create", systemImage: isAtPaletteLimit ? "lock.fill" : "plus")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!canCreate)
                        .accessibilityLabel(Text("Create palette and move"))
                    }
                } header: {
                    HStack {
                        Text("New Palette")
                        if isAtPaletteLimit { OnyxBadge(compact: true) }
                    }
                }

                Section("Your Palettes") {
                    if portfolio.orderedPalettes.isEmpty {
                        Text("No palettes yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(portfolio.orderedPalettes) { palette in
                        let isCurrent = colors.count == 1 && colors.first?.palette?.id == palette.id
                        Button {
                            Haptics.selection()
                            move(to: palette)
                        } label: {
                            HStack {
                                PaletteRowLabel(name: palette.name, colors: portfolio.colors(in: palette).map(\.rgba))
                                if isCurrent {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityLabel(Text("Current palette"))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isCurrent)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func move(to palette: OpalitePalette) {
        for color in colors where color.palette?.id != palette.id {
            portfolio.move(color, to: palette)
        }
        Haptics.success()
        let message = colors.count == 1
            ? String(localized: "Moved to \(palette.name)")
            : String(localized: "Moved \(colors.count) colors to \(palette.name)")
        toasts.showSuccess(message, systemImage: "swatchpalette.fill")
        onMoved?()
        dismiss()
    }

    private func createAndMove() {
        let name = newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        // The portfolio enforces the free-tier limit itself (toast + paywall).
        guard let palette = portfolio.createPalette(name: name) else { return }
        #if canImport(TipKit)
        PortfolioTips.advanceAfterContentCreation()
        #endif
        move(to: palette)
    }
}

// MARK: - Canvas picker

struct CanvasPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CanvasModel.self) private var canvases

    let onSelect: (CanvasFile) -> Void

    @State private var query = ""

    private var filtered: [CanvasFile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return canvases.canvases }
        return canvases.canvases.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if canvases.canvases.isEmpty {
                    EmptyStateView("No Canvases", systemImage: "pencil.and.scribble", description: String(localized: "Create a canvas in the Canvas tab first, then link it here."))
                } else {
                    List(filtered) { canvas in
                        Button {
                            Haptics.selection()
                            onSelect(canvas)
                            dismiss()
                        } label: {
                            HStack(spacing: Brand.Space.md) {
                                canvasThumbnail(canvas)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(canvas.title)
                                        .font(.headline)
                                    Text("Edited \(DetailFormatting.shortDate(canvas.updatedAt))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let linked = canvas.palette {
                                    Text(linked.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel(Text("Currently linked to \(linked.name)"))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $query, prompt: Text("Canvas name"))
                    .overlay {
                        if filtered.isEmpty { ContentUnavailableView.search(text: query) }
                    }
                }
            }
            .navigationTitle("Link a Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ContentBuilder
    private func canvasThumbnail(_ canvas: CanvasFile) -> some View {
        #if canImport(UIKit)
        if let data = canvas.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
                .accessibilityHidden(true)
        } else {
            placeholderThumbnail
        }
        #else
        placeholderThumbnail
        #endif
    }

    private var placeholderThumbnail: some View {
        Image(systemName: "scribble.variable")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Quick add") {
    QuickAddHexSheet { _ in }
        .portfolioPreviewEnvironment()
}

#Preview("Reorder") {
    PaletteOrderSheet()
        .portfolioPreviewEnvironment()
}

#Preview("Move color") {
    PaletteSelectionSheet(colors: [.sample])
        .portfolioPreviewEnvironment()
}

#Preview("Canvas picker") {
    CanvasPickerSheet { _ in }
        .portfolioPreviewEnvironment()
}
#endif
#endif

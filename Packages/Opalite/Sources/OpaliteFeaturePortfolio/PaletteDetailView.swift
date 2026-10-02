//
//  PaletteDetailView.swift
//  OpaliteFeaturePortfolio
//
//  A palette: the preview board (its colors on a chosen background, name editable in
//  place), info tiles, then cards — the colors (open, add, remove, delete), notes, tags,
//  and the linked canvas. Add Color is the single primary action; share, publish,
//  duplicate, archive, full screen, and delete live in the toolbar and More menu.
//  Menu-bar commands reach it through `PortfolioModel`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
import OpaliteFeatureSharing

/// Resolves the environment, then hands a per-palette view model to the content.
public struct PaletteDetailView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(CanvasModel.self) private var canvases
    @Environment(ToastManager.self) private var toasts

    private let paletteID: UUID

    public init(paletteID: UUID) {
        self.paletteID = paletteID
    }

    public var body: some View {
        PaletteDetailContent(paletteID: paletteID, portfolio: portfolio, canvases: canvases, toasts: toasts)
            .id(paletteID)
    }
}

private struct PaletteDetailContent: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(CanvasModel.self) private var canvases
    @Environment(AppRouter.self) private var router
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: PaletteDetailViewModel
    @State private var colorToDelete: OpaliteColor?
    @State private var movingColor: OpaliteColor?
    @Namespace private var namespace
    @FocusState private var isNameFocused: Bool

    init(paletteID: UUID, portfolio: PortfolioModel, canvases: CanvasModel, toasts: ToastManager) {
        _model = State(initialValue: PaletteDetailViewModel(paletteID: paletteID, portfolio: portfolio, canvases: canvases, toasts: toasts))
    }

    var body: some View {
        Group {
            if let palette = model.palette {
                content(for: palette)
            } else {
                EmptyStateView(String(localized: "Palette Not Found"), systemImage: "questionmark.circle", description: String(localized: "This palette may have been deleted on another device.")) {
                    Button("Back to Portfolio") { dismiss() }
                        .secondaryActionButton()
                }
            }
        }
        .onAppear(perform: model.didAppear)
        .onDisappear(perform: model.willDisappear)
        .onChange(of: portfolio.pendingCommand) { _, command in
            guard let command, portfolio.activePaletteID == model.paletteID, model.handle(command) else { return }
            portfolio.pendingCommand = nil
        }
        .onChange(of: model.isEditingName) { _, editing in isNameFocused = editing }
    }

    // MARK: - Content

    private func content(for palette: OpalitePalette) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                board(for: palette)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.top, Brand.Space.sm)
                tiles(for: palette)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.top, Brand.Space.md)
                VStack(spacing: Brand.Space.lg) {
                    colorsCard(for: palette)
                    notesCard
                    tagsCard
                    canvasCard(for: palette)
                }
                .padding(.horizontal, Brand.Space.lg)
                .padding(.top, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xxl)
            }
            .frame(maxWidth: Brand.detailMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(groupedBackground)
        .softScrollEdgesIfAvailable()
        .navigationTitle(palette.name)
        .navigationSubtitleIfAvailable(countText(model.memberCount))
        .toolbarTitleDisplayMode(.inline)
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .toolbar { toolbar(for: palette) }
        .fullScreenCover(isPresented: $model.isShowingEditor) {
            ColorEditorView(mode: .create(palette: palette), onCancel: { model.isShowingEditor = false }) { result in
                model.addColor(result)
                #if canImport(TipKit)
                PortfolioTips.advanceAfterContentCreation()
                #endif
            }
        }
        .fullScreenCover(isPresented: $model.isShowingFullScreen) {
            FullScreenColorView(colors: model.members.map(\.rgba), title: palette.name, titles: model.members.map(\.displayName))
        }
        .sheet(isPresented: $model.isShowingExport) { PaletteExportSheet(palette: palette) }
        .sheet(isPresented: $model.isShowingPublish) { PublishPaletteSheet(palette: palette) }
        .sheet(isPresented: $model.isShowingCanvasPicker) {
            CanvasPickerSheet { model.link($0) }
        }
        .sheet(item: $movingColor) { color in
            PaletteSelectionSheet(colors: [color])
        }
        .confirmationDialog("Delete \(palette.name)?", isPresented: $model.isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Palette", role: .destructive) {
                Haptics.selection()
                model.delete(deleteColors: false)
                dismiss()
            }
            if model.memberCount > 0 {
                Button("Delete Palette and Colors", role: .destructive) {
                    Haptics.selection()
                    model.delete(deleteColors: true)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.memberCount == 0 ? "This can't be undone." : "Deleting only the palette keeps its colors in your Portfolio.")
        }
        .confirmationDialog("Archive \(palette.name)?", isPresented: $model.isConfirmingArchive, titleVisibility: .visible) {
            Button("Archive") {
                Haptics.selection()
                model.archive()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived palettes leave the Portfolio but stay in Archived Palettes, where you can restore them.")
        }
        .confirmationDialog("Unlink the canvas?", isPresented: $model.isConfirmingUnlink, titleVisibility: .visible) {
            Button("Unlink", role: .destructive) {
                Haptics.selection()
                model.unlinkCanvas()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The canvas stays in your Canvases; it just won't be attached to this palette.")
        }
        .confirmationDialog(
            "Delete \(colorToDelete?.displayName ?? "")?",
            isPresented: Binding(get: { colorToDelete != nil }, set: { if !$0 { colorToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Color", role: .destructive) {
                if let color = colorToDelete {
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .snappy) { model.delete(color) }
                }
                colorToDelete = nil
            }
            Button("Cancel", role: .cancel) { colorToDelete = nil }
        } message: {
            Text("This can't be undone.")
        }
        .accessibilityIdentifier("paletteDetailView")
    }

    // MARK: - Board

    private var background: PreviewBackground { model.background(isDark: colorScheme == .dark) }

    private func board(for palette: OpalitePalette) -> some View {
        let members = model.members
        let onDark = !background.prefersDarkText
        return VStack(alignment: .leading, spacing: Brand.Space.md) {
            HStack(alignment: .center, spacing: Brand.Space.sm) {
                nameField(onDark: onDark)
                Spacer(minLength: Brand.Space.sm)
                backgroundMenu(onDark: onDark)
            }

            if members.isEmpty {
                VStack(spacing: Brand.Space.sm) {
                    Image(systemName: "swatchpalette")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                    Text("No colors yet")
                        .font(.headline)
                    Text("Add a color, or drag swatches here from your Portfolio.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(onDark ? Color.white.opacity(0.85) : Color.black.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Brand.Space.xl)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: boardSwatchSide, maximum: boardSwatchSide * 1.6), spacing: Brand.Space.sm)], spacing: Brand.Space.sm) {
                    ForEach(members) { color in
                        NavigationLink(value: PortfolioDestination.color(color.id)) {
                            SwatchView(color: color, height: boardSwatchSide, cornerRadius: Brand.Radius.control, matchedNamespace: namespace, matchedID: color.id)
                        }
                        .buttonStyle(.plain)
                        .hoverLift()
                        .contextMenu { memberMenu(color) }
                        .accessibilityHint(Text("Opens the color"))
                    }
                }
            }
        }
        .padding(Brand.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                .fill(background.rgba.color)
        )
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous).strokeBorder(.white.opacity(0.25)))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .animation(reduceMotion ? nil : .snappy, value: background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Palette preview, \(palette.name), \(members.count) colors"))
        .accessibilityIdentifier("paletteDetail.board")
    }

    private var boardSwatchSide: CGFloat { horizontalSizeClass == .compact ? 96 : 120 }

    @ContentBuilder
    private func nameField(onDark: Bool) -> some View {
        if model.isEditingName {
            HStack(spacing: Brand.Space.sm) {
                TextField(String(localized: "Palette name"), text: $model.nameDraft)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(onDark ? .white : .black)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit { model.commitRename() }
                    .accessibilityLabel(Text("Palette name"))
                Button {
                    Haptics.selection()
                    model.commitRename()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.large)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Save name"))
                Button {
                    Haptics.selection()
                    model.cancelRenaming()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(onDark ? .white.opacity(0.7) : .black.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Cancel"))
            }
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.xs)
            .background(Capsule(style: .continuous).fill((onDark ? Color.black : Color.white).opacity(0.28)))
            .transition(.blurReplace)
        } else {
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .bouncy) { model.beginRenaming() }
            } label: {
                HStack(spacing: Brand.Space.xs) {
                    Text(model.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                        .opacity(0.7)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(onDark ? .white : .black)
                .padding(.horizontal, Brand.Space.md)
                .padding(.vertical, Brand.Space.sm)
                .background(Capsule(style: .continuous).fill((onDark ? Color.black : Color.white).opacity(0.28)))
            }
            .buttonStyle(.plain)
            .hoverLift()
            .accessibilityLabel(Text("\(model.name), palette name"))
            .accessibilityHint(Text("Double-tap to rename"))
            .accessibilityIdentifier("paletteDetail.name")
        }
    }

    private func backgroundMenu(onDark: Bool) -> some View {
        Menu {
            Picker("Background", selection: Binding(get: { background }, set: { model.setBackground($0) })) {
                ForEach(PreviewBackground.allCases) { option in
                    Label(option.displayName, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Image(systemName: "paintbrush.pointed")
                .font(.body.weight(.semibold))
                .foregroundStyle(onDark ? .white : .black)
                .frame(width: 36, height: 36)
                .background(Circle().fill((onDark ? Color.black : Color.white).opacity(0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverLift()
        .accessibilityLabel(Text("Preview background"))
        .accessibilityValue(Text(background.displayName))
    }

    // MARK: - Tiles

    private func tiles(for palette: OpalitePalette) -> some View {
        HStack(spacing: Brand.Space.sm) {
            InfoTile(title: String(localized: "Colors"), value: model.memberCount.formatted(), systemImage: "swatchpalette.fill")
            InfoTile(title: String(localized: "Created by"), value: DetailFormatting.authorName(palette.createdByDisplayName), systemImage: "person.fill", tint: .opaliteBlue)
            InfoTile(title: String(localized: "Updated"), value: DetailFormatting.shortDate(palette.updatedAt), systemImage: "clock.fill", tint: .opaliteTan)
        }
    }

    // MARK: - Cards

    private func expansion(_ section: PaletteDetailSection) -> Binding<Bool> {
        Binding(get: { model.isExpanded(section) }, set: { model.setExpanded(section, $0) })
    }

    private func colorsCard(for palette: OpalitePalette) -> some View {
        SectionCard(String(localized: "Colors"), systemImage: "paintpalette", isExpanded: expansion(.colors), trailing: {
            Text(model.memberCount, format: .number)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .accessibilityHidden(true)
        }) {
            VStack(spacing: 0) {
                ForEach(model.members) { color in
                    memberRow(color)
                    if color.id != model.members.last?.id { Divider() }
                }
                if model.members.isEmpty {
                    Text("Colors you add appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Brand.Space.sm)
                }
                Button {
                    Haptics.selection()
                    model.isShowingEditor = true
                } label: {
                    Label("Add Color", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionButton()
                .padding(.top, Brand.Space.md)
                .accessibilityIdentifier("paletteDetail.addColor")
            }
        }
    }

    private func memberRow(_ color: OpaliteColor) -> some View {
        NavigationLink(value: PortfolioDestination.color(color.id)) {
            HStack(spacing: Brand.Space.md) {
                ColorChip(color.rgba, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(color.displayName)
                        .font(.body)
                        .lineLimit(1)
                    Text(hexCopy.formatted(color))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Brand.Space.sm)
                Menu {
                    memberMenu(color)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Actions for \(color.displayName)"))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Brand.Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .contextMenu { memberMenu(color) }
        .accessibilityLabel(Text(color.hasName ? "\(color.displayName), \(color.hexString)" : String(localized: "Unnamed color, \(color.hexString)")))
        .accessibilityHint(Text("Opens the color"))
    }

    @ContentBuilder
    private func memberMenu(_ color: OpaliteColor) -> some View {
        ColorActionsMenu(
            color: color,
            onMove: { movingColor = color },
            onRemoveFromPalette: { withAnimation(reduceMotion ? nil : .snappy) { model.remove(color) } },
            onDelete: { colorToDelete = color }
        )
    }

    private var notesCard: some View {
        SectionCard(String(localized: "Notes"), systemImage: "note.text", tint: .opaliteTan, isExpanded: expansion(.notes), trailing: {
            if model.hasUnsavedNotes {
                Text("Saving…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }) {
            NotesEditor(text: $model.notesDraft, placeholder: String(localized: "What this palette is for, where it's used, what inspired it…")) {
                model.notesDidChange()
            }
        }
    }

    private var tagsCard: some View {
        SectionCard(String(localized: "Tags"), systemImage: "tag", tint: .opaliteBlue, isExpanded: expansion(.tags), trailing: {
            if !model.tags.isEmpty {
                Text(model.tags.count, format: .number)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }) {
            VStack(alignment: .leading, spacing: Brand.Space.md) {
                if model.tags.isEmpty {
                    Text("Tags help you find palettes in Search and are published with the palette.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: Brand.Space.sm) {
                        ForEach(model.tags, id: \.self) { tag in
                            HStack(spacing: Brand.Space.xs) {
                                Text(tag)
                                    .font(.subheadline.weight(.medium))
                                Button {
                                    Haptics.selection()
                                    withAnimation(reduceMotion ? nil : .snappy) { model.removeTag(tag) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Remove \(tag)"))
                            }
                            .padding(.horizontal, Brand.Space.md)
                            .padding(.vertical, Brand.Space.xs + 2)
                            .background(Capsule(style: .continuous).fill(Color.opaliteBlue.opacity(0.25)))
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(Text("Tag \(tag)"))
                        }
                    }
                }
                HStack(spacing: Brand.Space.sm) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(String(localized: "Add a tag"), text: $model.tagDraft)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { addTag() }
                        .accessibilityLabel(Text("New tag"))
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .disabled(DetailFormatting.normalizedTag(model.tagDraft) == nil)
                    .accessibilityLabel(Text("Add tag"))
                }
                .padding(.horizontal, Brand.Space.md)
                .padding(.vertical, Brand.Space.sm)
                .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
            }
        }
    }

    private func addTag() {
        guard DetailFormatting.normalizedTag(model.tagDraft) != nil else { return }
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .snappy) { model.addTag() }
    }

    private func canvasCard(for palette: OpalitePalette) -> some View {
        SectionCard(String(localized: "Canvas"), systemImage: "pencil.and.scribble", isExpanded: expansion(.canvas)) {
            if let canvas = model.linkedCanvas {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    HStack(spacing: Brand.Space.md) {
                        canvasThumbnail(canvas)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(canvas.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("Edited \(DetailFormatting.shortDate(canvas.updatedAt))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if !model.canOpenLinkedCanvas { OnyxBadge(compact: true) }
                    }
                    .accessibilityElement(children: .combine)
                    HStack(spacing: Brand.Space.sm) {
                        Button {
                            Haptics.mediumImpact()
                            canvases.requestOpen(canvas)
                        } label: {
                            Label("Open Canvas", systemImage: "arrow.up.forward.square")
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryActionButton()
                        .accessibilityHint(Text(model.canOpenLinkedCanvas ? "Opens the canvas" : "Requires Onyx"))
                        Button {
                            Haptics.selection()
                            model.isConfirmingUnlink = true
                        } label: {
                            Label("Unlink", systemImage: "link.badge.minus")
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryActionButton(tint: .opaliteTan)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    Text("Link a canvas to sketch with this palette's colors. The SwatchBar picks up its ink from here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Haptics.selection()
                        model.isShowingCanvasPicker = true
                    } label: {
                        Label("Link Canvas…", systemImage: "link.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryActionButton()
                }
            }
        }
    }

    @ContentBuilder
    private func canvasThumbnail(_ canvas: CanvasFile) -> some View {
        if let data = canvas.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "scribble.variable")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(for palette: OpalitePalette) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Haptics.selection()
                model.isShowingEditor = true
            } label: {
                Label("Add Color", systemImage: "plus")
            }
            .accessibilityHint(Text("Creates a new color in this palette"))
            .accessibilityIdentifier("paletteDetail.add")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.selection()
                model.isShowingExport = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(model.memberCount == 0)
            .accessibilityHint(Text("Export or share this palette"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .bouncy) { model.beginRenaming() }
                } label: {
                    Label("Rename…", systemImage: "character.cursor.ibeam")
                }
                Button {
                    Haptics.selection()
                    model.isShowingFullScreen = true
                } label: {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(model.memberCount == 0)
                Divider()
                Button {
                    Haptics.selection()
                    if let copy = model.duplicate() { router.open(.palette(copy.id)) }
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button {
                    Haptics.selection()
                    model.isShowingPublish = true
                } label: {
                    Label("Publish to Community…", systemImage: "person.2")
                }
                .disabled(model.memberCount == 0)
                if model.linkedCanvas == nil {
                    Button {
                        Haptics.selection()
                        model.isShowingCanvasPicker = true
                    } label: {
                        Label("Link Canvas…", systemImage: "link.badge.plus")
                    }
                }
                Divider()
                Button {
                    Haptics.selection()
                    model.isConfirmingArchive = true
                } label: {
                    Label("Archive…", systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    Haptics.selection()
                    model.isConfirmingDelete = true
                } label: {
                    Label("Delete…", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .toolbarButtonTint()
            .accessibilityLabel(Text("More actions"))
            .accessibilityIdentifier("paletteDetail.moreMenu")
        }
    }

    private func countText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 color") : String(localized: "\(count) colors")
    }
}

#if DEBUG
#Preview("Palette detail") {
    let environment = PreviewEnvironment()
    let id = environment.portfolio.activePalettes.first!.id
    return NavigationStack {
        PaletteDetailView(paletteID: id)
            .navigationDestination(for: PortfolioDestination.self) { PortfolioDestinationView(destination: $0) }
    }
    .previewEnvironment(environment)
}

#Preview("Empty palette, no Onyx") {
    let environment = PreviewEnvironment(hasOnyx: false)
    let palette = environment.portfolio.createPalette(name: "Empty")!
    return NavigationStack {
        PaletteDetailView(paletteID: palette.id)
    }
    .previewEnvironment(environment)
}
#endif
#endif

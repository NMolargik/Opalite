//
//  ColorDetailView.swift
//  OpaliteFeaturePortfolio
//
//  A saved color: the hero swatch (tap the badge to rename, with Apple Intelligence
//  suggestions), info tiles, then collapsible cards — codes, details, notes, palette
//  membership, the harmony wheel, tints/shades/tones, and the WCAG contrast checker.
//  Edit is the single primary action; share, move, publish, full screen, and delete live
//  in the toolbar and More menu. Menu-bar commands reach it through `PortfolioModel`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
import OpaliteFeatureSharing

/// Resolves the environment, then hands a per-color view model to the content.
public struct ColorDetailView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toasts
    @Environment(ColorNameSuggestionService.self) private var namer: ColorNameSuggestionService?

    private let colorID: UUID

    public init(colorID: UUID) {
        self.colorID = colorID
    }

    public var body: some View {
        ColorDetailContent(colorID: colorID, portfolio: portfolio, toasts: toasts, namer: namer)
            .id(colorID)
    }
}

private struct ColorDetailContent: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: ColorDetailViewModel
    @Namespace private var heroNamespace
    @ScaledMetric(relativeTo: .largeTitle) private var heroHeight: CGFloat = 240

    init(colorID: UUID, portfolio: PortfolioModel, toasts: ToastManager, namer: (any ColorNaming)?) {
        _model = State(initialValue: ColorDetailViewModel(colorID: colorID, portfolio: portfolio, toasts: toasts, namer: namer))
    }

    var body: some View {
        Group {
            if let color = model.color {
                content(for: color)
            } else {
                EmptyStateView(String(localized: "Color Not Found"), systemImage: "questionmark.circle", description: String(localized: "This color may have been deleted on another device.")) {
                    Button("Back to Portfolio") { dismiss() }
                        .secondaryActionButton()
                }
            }
        }
        .onAppear(perform: model.didAppear)
        .onDisappear(perform: model.willDisappear)
        .onChange(of: portfolio.pendingCommand) { _, command in
            guard let command, portfolio.activeColorID == model.colorID, model.handle(command) else { return }
            portfolio.pendingCommand = nil
        }
    }

    // MARK: - Content

    private func content(for color: OpaliteColor) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                hero(for: color)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.top, Brand.Space.sm)
                tiles(for: color)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.top, Brand.Space.md)
                VStack(spacing: Brand.Space.lg) {
                    codesCard(for: color)
                    detailsCard(for: color)
                    notesCard
                    paletteCard(for: color)
                    harmonyCard
                    tonesCard
                    contrastCard
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
        .navigationTitle(color.displayName)
        .navigationSubtitleIfAvailable(hexCopy.formatted(color))
        .toolbarTitleDisplayMode(.inline)
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .toolbar { toolbar(for: color) }
        .fullScreenCover(isPresented: $model.isShowingEditor) {
            ColorEditorView(mode: .edit(color), onCancel: { model.isShowingEditor = false }) { model.apply($0) }
        }
        .fullScreenCover(isPresented: $model.isShowingFullScreen) {
            FullScreenColorView(colors: [color.rgba], title: color.displayName)
        }
        .sheet(isPresented: $model.isShowingPaletteSheet) {
            PaletteSelectionSheet(colors: [color])
        }
        .sheet(isPresented: $model.isShowingExport) { ColorExportSheet(color: color) }
        .sheet(isPresented: $model.isShowingPublish) { PublishColorSheet(color: color) }
        .confirmationDialog("Delete \(color.displayName)?", isPresented: $model.isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Color", role: .destructive) {
                Haptics.selection()
                model.delete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .accessibilityIdentifier("colorDetailView")
    }

    // MARK: - Hero

    private func hero(for color: OpaliteColor) -> some View {
        SwatchView(
            color: color,
            height: heroHeight,
            isEditingBadge: $model.isEditingName,
            onRename: { model.rename(to: $0) },
            nameSuggestions: model.nameSuggestions,
            isLoadingSuggestions: model.isLoadingSuggestions,
            onSuggestionSelected: { model.rename(to: $0) },
            matchedNamespace: heroNamespace,
            matchedID: "hero"
        ) {
            ColorActionsMenu(
                color: color,
                onRename: { model.beginRenaming() },
                onMove: { model.isShowingPaletteSheet = true },
                onRemoveFromPalette: { model.removeFromPalette() },
                onExport: { model.isShowingExport = true },
                onPublish: { model.isShowingPublish = true },
                onDelete: { model.isConfirmingDelete = true }
            )
        }
        .frame(height: heroHeight)
        .shadow(color: color.swiftUIColor.opacity(0.35), radius: 24, y: 10)
        .onChange(of: model.isEditingName) { _, editing in
            if editing { model.requestSuggestions() } else { model.clearSuggestions() }
        }
        .accessibilityIdentifier("colorDetail.hero")
    }

    // MARK: - Tiles

    private func tiles(for color: OpaliteColor) -> some View {
        HStack(spacing: Brand.Space.sm) {
            InfoTile(
                title: String(localized: "Palette"),
                value: color.palette?.name ?? String(localized: "Loose"),
                systemImage: color.palette == nil ? "square.dashed" : "swatchpalette.fill"
            )
            InfoTile(
                title: String(localized: "Created On"),
                value: DetailFormatting.shortDeviceName(color.createdOnDeviceName),
                systemImage: DeviceKind.from(color.createdOnDeviceName).systemImage,
                tint: .opaliteBlue
            )
            InfoTile(
                title: String(localized: "Updated"),
                value: DetailFormatting.shortDate(color.updatedAt),
                systemImage: "clock.fill",
                tint: .opaliteTan
            )
        }
    }

    // MARK: - Cards

    private func expansion(_ section: ColorDetailSection) -> Binding<Bool> {
        Binding(get: { model.isExpanded(section) }, set: { model.setExpanded(section, $0) })
    }

    private func codesCard(for color: OpaliteColor) -> some View {
        SectionCard(String(localized: "Codes"), systemImage: "number", isExpanded: expansion(.codes)) {
            VStack(spacing: Brand.Space.xs) {
                DetailRow(String(localized: "Hex"), value: hexCopy.formatted(color), systemImage: "number", monospaced: true) {
                    hexCopy.copyHex(for: color)
                }
                if color.alpha < 1 {
                    Divider()
                    DetailRow(String(localized: "Hex with Alpha"), value: color.hexWithAlphaString, systemImage: "number.square", monospaced: true) {
                        hexCopy.copy(text: color.hexWithAlphaString, label: String(localized: "Hex with Alpha"))
                    }
                }
                Divider()
                DetailRow(String(localized: "RGB"), value: color.rgbString, systemImage: "slider.horizontal.3", monospaced: true) {
                    hexCopy.copy(text: color.rgbString, label: String(localized: "RGB"))
                }
                Divider()
                DetailRow(String(localized: "HSL"), value: color.hslString, systemImage: "circle.lefthalf.filled", monospaced: true) {
                    hexCopy.copy(text: color.hslString, label: String(localized: "HSL"))
                }
                Divider()
                DetailRow(String(localized: "HSV"), value: hsvString(color.hsv), systemImage: "sun.max", monospaced: true) {
                    hexCopy.copy(text: hsvString(color.hsv), label: String(localized: "HSV"))
                }
                Divider()
                DetailRow(String(localized: "CMYK"), value: DetailFormatting.cmykString(color.cmyk), systemImage: "printer", monospaced: true) {
                    hexCopy.copy(text: DetailFormatting.cmykString(color.cmyk), label: String(localized: "CMYK"))
                }
                if color.alpha < 1 {
                    Divider()
                    DetailRow(String(localized: "Opacity"), value: color.alpha.formatted(.percent.precision(.fractionLength(0))), systemImage: "circle.dotted", monospaced: true)
                }
            }
        }
    }

    private func detailsCard(for color: OpaliteColor) -> some View {
        SectionCard(String(localized: "Details"), systemImage: "info.circle", tint: .opaliteBlue, isExpanded: expansion(.details)) {
            VStack(spacing: Brand.Space.xs) {
                DetailRow(String(localized: "Family"), value: ColorClassifier.description(of: color.rgba), systemImage: "paintpalette")
                Divider()
                DetailRow(String(localized: "Created by"), value: DetailFormatting.authorName(color.createdByDisplayName), systemImage: "person")
                Divider()
                DetailRow(String(localized: "Created"), value: DetailFormatting.longDate(color.createdAt), systemImage: "calendar")
                Divider()
                DetailRow(String(localized: "Updated"), value: DetailFormatting.longDate(color.updatedAt), systemImage: "clock")
                if let device = color.updatedOnDeviceName, !device.isEmpty {
                    Divider()
                    DetailRow(String(localized: "Last edited on"), value: device, systemImage: DeviceKind.from(device).systemImage)
                }
                Divider()
                DetailRow(String(localized: "Luminance"), value: color.relativeLuminance.formatted(.number.precision(.fractionLength(3))), systemImage: "light.max", monospaced: true)
            }
        }
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
            NotesEditor(text: $model.notesDraft, placeholder: String(localized: "Where you found it, where it works, what it pairs with…")) {
                model.notesDidChange()
            }
        }
    }

    private func paletteCard(for color: OpaliteColor) -> some View {
        SectionCard(String(localized: "Palette"), systemImage: "swatchpalette", isExpanded: expansion(.palette)) {
            if let palette = color.palette {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    NavigationLink(value: PortfolioDestination.palette(palette.id)) {
                        HStack(spacing: Brand.Space.md) {
                            PaletteRowLabel(name: palette.name, colors: portfolio.colors(in: palette).map(\.rgba))
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight()
                    .accessibilityHint(Text("Opens the palette"))

                    HStack(spacing: Brand.Space.sm) {
                        Button {
                            Haptics.selection()
                            model.isShowingPaletteSheet = true
                        } label: {
                            Label("Move…", systemImage: "arrow.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryActionButton()
                        Button {
                            Haptics.selection()
                            withAnimation(reduceMotion ? nil : .snappy) { model.removeFromPalette() }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryActionButton(tint: .opaliteTan)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    Text("This is a loose color. Add it to a palette to keep related colors together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Haptics.selection()
                        model.isShowingPaletteSheet = true
                    } label: {
                        Label("Add to Palette…", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryActionButton()
                }
            }
        }
    }

    private var harmonyCard: some View {
        SectionCard(String(localized: "Harmonies"), systemImage: "circle.hexagongrid", isExpanded: expansion(.harmony)) {
            VStack(spacing: Brand.Space.lg) {
                Picker("Harmony", selection: $model.harmonyKind) {
                    ForEach(HarmonyKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.systemImage).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .accessibilityLabel(Text("Harmony"))

                HarmonyWheel(base: model.rgba, kind: model.harmonyKind, diameter: horizontalSizeClass == .compact ? 200 : 240)
                    .padding(.vertical, Brand.Space.sm)

                VStack(alignment: .leading, spacing: Brand.Space.xs) {
                    Text(model.harmonyKind.title)
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text(model.harmonyKind.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .snappy, value: model.harmonyKind)

                derivedRow(model.harmonyColors.map { DerivedChip(id: $0.hexString, rgba: $0, label: $0.hexString) }, kindLabel: model.harmonyKind.title)
            }
        }
    }

    private var tonesCard: some View {
        SectionCard(String(localized: "Tints, Shades & Tones"), systemImage: "circle.lefthalf.filled", tint: .opaliteTan, isExpanded: expansion(.tones)) {
            VStack(alignment: .leading, spacing: Brand.Space.lg) {
                ForEach(ToneLadder.allCases) { ladder in
                    VStack(alignment: .leading, spacing: Brand.Space.sm) {
                        HStack(spacing: Brand.Space.xs) {
                            Image(systemName: ladder.systemImage)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(ladder.title)
                                .font(.subheadline.weight(.semibold))
                            Text("·")
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                            Text(ladder.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        derivedRow(ladder.steps(for: model.rgba).map { DerivedChip(id: $0.id, rgba: $0.rgba, label: $0.label) }, kindLabel: ladder.title)
                    }
                }
            }
        }
    }

    private var contrastCard: some View {
        SectionCard(String(localized: "Contrast"), systemImage: "circle.righthalf.filled", tint: .opaliteBlue, isExpanded: expansion(.contrast), trailing: {
            if let level = model.contrast.conformance?.level {
                Text(level.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Brand.Space.sm)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(level.color))
                    .accessibilityLabel(Text("WCAG \(level.title)"))
            }
        }) {
            ContrastCheckerCard(model: model, candidates: model.contrastCandidates)
        }
    }

    // MARK: - Derived chips

    private struct DerivedChip: Identifiable {
        let id: String
        let rgba: RGBA
        let label: String
    }

    private func derivedRow(_ chips: [DerivedChip], kindLabel: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Space.md) {
                ForEach(chips) { chip in
                    Button {
                        model.addDerivedColor(chip.rgba, label: kindLabel)
                    } label: {
                        ColorChip(chip.rgba, size: 64, cornerRadius: Brand.Radius.control, label: chip.label)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "plus.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(chip.rgba.idealTextColor, (chip.rgba.prefersDarkText ? Color.white : Color.black).opacity(0.3))
                                    .font(.body)
                                    .padding(Brand.Space.xs)
                                    .accessibilityHidden(true)
                            }
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .contextMenu {
                        Button {
                            hexCopy.copy(hex: chip.rgba.hexString)
                        } label: {
                            Label("Copy Hex", systemImage: "number")
                        }
                        Button {
                            model.addDerivedColor(chip.rgba, label: kindLabel)
                        } label: {
                            Label("Add to Portfolio", systemImage: "plus")
                        }
                    }
                    .accessibilityLabel(Text("\(kindLabel) \(chip.label), \(chip.rgba.hexString)"))
                    .accessibilityHint(Text("Adds this color to your Portfolio"))
                }
            }
            .padding(.vertical, Brand.Space.xs)
        }
        .scrollClipDisabled()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(for color: OpaliteColor) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Haptics.selection()
                model.isShowingEditor = true
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }
            .accessibilityHint(Text("Opens the color editor"))
            .accessibilityIdentifier("colorDetail.edit")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.selection()
                model.isShowingExport = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityHint(Text("Export or share this color"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.selection()
                    model.beginRenaming()
                } label: {
                    Label("Rename…", systemImage: "character.cursor.ibeam")
                }
                Button {
                    Haptics.selection()
                    model.isShowingPaletteSheet = true
                } label: {
                    Label(color.palette == nil ? "Add to Palette…" : "Move to Palette…", systemImage: "swatchpalette")
                }
                if color.palette != nil {
                    Button {
                        Haptics.selection()
                        model.removeFromPalette()
                    } label: {
                        Label("Remove from Palette", systemImage: "minus.circle")
                    }
                }
                Divider()
                Button {
                    Haptics.selection()
                    model.isShowingFullScreen = true
                } label: {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button {
                    Haptics.selection()
                    model.isShowingPublish = true
                } label: {
                    Label("Publish to Community…", systemImage: "person.2")
                }
                Divider()
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
            .accessibilityIdentifier("colorDetail.moreMenu")
        }
    }

    // MARK: - Formatting

    private func hsvString(_ hsv: HSV) -> String {
        "hsv(\(Int(hsv.hue.rounded())), \(Int((hsv.saturation * 100).rounded()))%, \(Int((hsv.value * 100).rounded()))%)"
    }
}

// MARK: - Contrast checker

private struct ContrastCheckerCard: View {
    @Bindable var model: ColorDetailViewModel
    let candidates: [ContrastCandidate]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isHexFocused: Bool

    private var contrast: ContrastCheck { model.contrast }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.lg) {
            preview
            ratio
            presets
            hexField
            if !candidates.isEmpty { candidateRow }
            criteria
        }
    }

    private var preview: some View {
        HStack(spacing: 0) {
            sample(background: contrast.source, foreground: contrast.comparison ?? (contrast.source.prefersDarkText ? .black : .white), title: String(localized: "Text on this color"))
            sample(background: contrast.comparison ?? (contrast.source.prefersDarkText ? .white : .black), foreground: contrast.source, title: String(localized: "This color as text"))
        }
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous).strokeBorder(.quaternary))
        .animation(reduceMotion ? nil : .snappy, value: contrast)
    }

    private func sample(background: RGBA, foreground: RGBA, title: String) -> some View {
        VStack(spacing: Brand.Space.xs) {
            Text("Aa")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
            Text(title)
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(foreground.color)
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(background.color)
        .accessibilityElement(children: .combine)
    }

    private var ratio: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(contrast.ratioText)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("contrast ratio")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if contrast.hasComparison {
                Button {
                    Haptics.selection()
                    model.contrast.clearComparison()
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear comparison"))
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: contrast.ratioText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(contrast.hasComparison ? "Contrast ratio \(contrast.ratioText)" : String(localized: "Choose a comparison color to check contrast")))
    }

    private var presets: some View {
        HStack(spacing: Brand.Space.sm) {
            ForEach(ContrastCheck.Preset.allCases) { preset in
                Button {
                    Haptics.selection()
                    model.selectContrast(preset)
                } label: {
                    HStack(spacing: Brand.Space.xs) {
                        Circle()
                            .fill(preset.rgba.color)
                            .overlay(Circle().strokeBorder(.quaternary))
                            .frame(width: 16, height: 16)
                        Text(preset.title)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, Brand.Space.md)
                    .padding(.vertical, Brand.Space.sm)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(contrast.comparison == preset.rgba ? Color.accentColor.opacity(0.25) : Color.clear)
                    )
                    .overlay(Capsule(style: .continuous).strokeBorder(contrast.comparison == preset.rgba ? Color.accentColor : .quaternary))
                }
                .buttonStyle(.plain)
                .hoverLift()
                .accessibilityAddTraits(contrast.comparison == preset.rgba ? .isSelected : [])
            }
        }
    }

    private var hexField: some View {
        HStack(spacing: Brand.Space.sm) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "Compare with a hex code"), text: $model.contrastHexDraft)
                .textFieldStyle(.plain)
                .font(.body.monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($isHexFocused)
                .onSubmit { apply() }
                .accessibilityLabel(Text("Comparison hex code"))
            Button {
                apply()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .disabled(RGBA(hex: model.contrastHexDraft) == nil)
            .accessibilityLabel(Text("Use this hex code"))
        }
        .padding(.horizontal, Brand.Space.md)
        .padding(.vertical, Brand.Space.sm)
        .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
    }

    private var candidateRow: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text("From your Portfolio")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Brand.Space.sm) {
                    ForEach(candidates) { candidate in
                        Button {
                            Haptics.selection()
                            model.selectContrast(candidate)
                        } label: {
                            ColorChip(candidate.rgba, size: 44, label: nil)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: contrast.comparison == candidate.rgba ? 3 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .hoverLift()
                        .accessibilityLabel(Text(candidate.label))
                        .accessibilityAddTraits(contrast.comparison == candidate.rgba ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var criteria: some View {
        VStack(spacing: Brand.Space.xs) {
            ForEach(ContrastCheck.Criterion.allCases) { criterion in
                let passes = contrast.passes(criterion)
                HStack(spacing: Brand.Space.md) {
                    Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(passes ? Color.green : (contrast.hasComparison ? Color.red : Color.secondary))
                        .symbolEffect(.bounce, value: passes)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(criterion.title)
                            .font(.subheadline.weight(.medium))
                        Text(criterion.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Brand.Space.xs)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(contrast.hasComparison ? (passes ? "Passes" : "Fails") : "Not checked"))
                if criterion != ContrastCheck.Criterion.allCases.last { Divider() }
            }
        }
    }

    private func apply() {
        if model.applyContrastHex() {
            Haptics.selection()
            isHexFocused = false
        } else {
            Haptics.error()
        }
    }
}

// MARK: - Notes editor

/// A borderless multi-line notes field with a placeholder.
struct NotesEditor: View {
    @Binding var text: String
    let placeholder: String
    let onChange: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 96)
            .focused($isFocused)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(Brand.Space.sm)
            .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
            .onChange(of: text) { onChange() }
            .accessibilityLabel(Text("Notes"))
    }
}

// MARK: - Full screen

/// Fills the screen with one or more colors (swipe between them); tap to dismiss.
struct FullScreenColorView: View {
    let colors: [RGBA]
    let title: String
    var titles: [String]? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(colors.enumerated()), id: \.offset) { offset, rgba in
                ZStack {
                    if rgba.alpha < 1 { Checkerboard(squareSize: 14) }
                    rgba.color
                }
                .ignoresSafeArea()
                .tag(offset)
                .accessibilityLabel(Text(titles?[safe: offset] ?? rgba.hexString))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: colors.count > 1 ? .automatic : .never))
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack(spacing: Brand.Space.sm) {
                Text(titles?[safe: index] ?? title)
                    .font(.headline)
                    .lineLimit(1)
                if colors.count > 1 {
                    Text("\(index + 1) of \(colors.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Haptics.selection()
                    dismiss()
                } label: {
                    Label("Exit Full Screen", systemImage: "arrow.down.right.and.arrow.up.left")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Exit full screen"))
                .accessibilityIdentifier("fullScreen.exit")
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.md)
            .adaptiveGlassCapsule()
            .padding(.horizontal, Brand.Space.lg)
            .padding(.top, Brand.Space.sm)
        }
        .onTapGesture { dismiss() }
        .accessibilityIdentifier("fullScreenColorView")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
#Preview("Color detail") {
    let environment = PreviewEnvironment()
    let id = environment.portfolio.looseColors.first!.id
    return NavigationStack {
        ColorDetailView(colorID: id)
            .navigationDestination(for: PortfolioDestination.self) { PortfolioDestinationView(destination: $0) }
    }
    .previewEnvironment(environment)
    .environment(ColorNameSuggestionService())
}

#Preview("In a palette") {
    let environment = PreviewEnvironment()
    let id = environment.portfolio.activePalettes.first!.sortedColors.first!.id
    return NavigationStack {
        ColorDetailView(colorID: id)
    }
    .previewEnvironment(environment)
}
#endif
#endif

//
//  PaletteAccessibilityViews.swift
//  OpaliteFeaturePortfolio
//
//  The palette detail's accessibility tools, each a card: the contrast matrix (WCAG and
//  APCA for every pair; a tap opens the contrast checker), the lightness scale (an 11-step
//  OKLCH ramp that can be saved as a palette), and color-vision distinguishability (a score
//  per deficiency and the pairs that collapse). The math is in OpaliteCore.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - Shared bits

extension APCA.Band {
    /// A short phrase for the matrix cells.
    var shortGuidance: String {
        switch self {
        case .fail: String(localized: "Too low")
        case .spot: String(localized: "Spot only")
        case .large: String(localized: "Headlines")
        case .content: String(localized: "Content")
        case .body: String(localized: "Body")
        case .fluent: String(localized: "Fluent")
        }
    }

    /// The longer guidance used by the contrast checker.
    var guidance: String {
        switch self {
        case .fail: String(localized: "Too low for text")
        case .spot: String(localized: "Incidental text only")
        case .large: String(localized: "Large headlines")
        case .content: String(localized: "Content and large body text")
        case .body: String(localized: "Body text")
        case .fluent: String(localized: "Fluent reading")
        }
    }
}

// MARK: - Focused view

/// On iPad the sheet is wide enough for the matrix and as tall as its content (within reason),
/// instead of a full page with a large empty block. iPhone sheets ignore it and use detents.
struct AccessibilitySheetSizing: PresentationSizing {
    func proposedSize(for root: PresentationSizingRoot, context: PresentationSizingContext) -> ProposedViewSize {
        let width: CGFloat = 860
        let height = root.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return ProposedViewSize(width: width, height: min(max(height, 640), 900))
    }
}

/// One place for the three tools: a segmented switch over the matrix, the scale and the
/// color-vision score, so the palette screen itself gains a single row.
struct PaletteAccessibilitySheet: View {
    @Bindable var model: PaletteDetailViewModel
    let openPalette: @MainActor (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(PortfolioModel.self) private var portfolio
    @State private var detent: PresentationDetent = {
        #if DEBUG
        // Simulator verification: open the iPhone sheet at its large detent.
        if CommandLine.arguments.contains("--expand-accessibility") { return .large }
        #endif
        return .medium
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Brand.Space.lg) {
                    Picker("Tool", selection: $model.accessibilityTool) {
                        Text("Contrast").tag(AccessibilityTool.contrast)
                        Text("Scale").tag(AccessibilityTool.scale)
                        Text("Color Vision").tag(AccessibilityTool.colorVision)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("accessibility.tool")

                    VStack(alignment: .leading, spacing: Brand.Space.md) {
                        tool
                    }
                    .padding(Brand.Space.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
                }
                .padding(Brand.Space.lg)
                .frame(maxWidth: Brand.wideDetailMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(groupedBackground)
            .navigationTitle(model.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
            .sharedSheet(item: $model.contrastPair) { pair in ContrastPairSheet(pair: pair) }
        }
        .presentationSizing(AccessibilitySheetSizing())
        .presentationDetents(horizontalSizeClass == .compact ? [.medium, .large] : [.large], selection: $detent)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("paletteAccessibilitySheet")
    }

    @ContentBuilder
    private var tool: some View {
        switch model.accessibilityTool {
        case .contrast:
            ContrastMatrixCard(model: model)
        case .scale:
            LightnessScaleCard(model: model) {
                model.addScaleAsPalette(open: { id in
                    dismiss()
                    openPalette(id)
                })
            }
        case .colorVision:
            ColorVisionCard(model: model)
        }
    }
}

// MARK: - Contrast matrix

/// One quiet result badge per cell: green for a pass, amber for partial, gray for a miss
/// (most pairs in any palette miss, which is normal, so a miss is not drawn in alarm red).
private struct ResultBadge: View {
    enum Tone { case pass, partial, miss }

    let text: String
    let tone: Tone

    private var tint: Color {
        switch tone {
        case .pass: .green
        case .partial: .orange
        case .miss: .secondary
        }
    }

    var body: some View {
        Text(verbatim: text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone == .miss ? Color.secondary : tint.mix(with: .primary, by: 0.35))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule(style: .continuous).fill(tint.opacity(tone == .miss ? 0.14 : 0.18)))
    }
}

struct ContrastMatrixCard: View {
    @Bindable var model: PaletteDetailViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var availableWidth: CGFloat = 0
    @State private var hasMoreToTrailing = false

    private let spacing: CGFloat = 6
    private var headerWidth: CGFloat { horizontalSizeClass == .compact ? 68 : 88 }
    private var minCell: CGFloat { horizontalSizeClass == .compact ? 84 : 104 }
    private var maxCell: CGFloat { 150 }
    private let cellHeight: CGFloat = 76

    /// Fills the card when the grid fits; otherwise cells keep their minimum and it scrolls.
    private func cellWidth(count: Int) -> CGFloat {
        guard count > 0, availableWidth > 0 else { return minCell }
        let fit = (availableWidth - headerWidth - CGFloat(count) * spacing) / CGFloat(count)
        return min(maxCell, max(minCell, fit))
    }

    var body: some View {
        let matrix = model.contrastMatrix
        let colors = model.matrixMembers
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            if colors.count < 2 {
                Text("Add at least two colors to compare every pair.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                summaryLine(matrix)

                ScrollView(.horizontal, showsIndicators: false) {
                    grid(matrix, colors: colors)
                        .padding(.vertical, Brand.Space.xs)
                }
                .scrollClipDisabled()
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.x + geometry.containerSize.width < geometry.contentSize.width - 2
                } action: { _, more in
                    hasMoreToTrailing = more
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
                .overlay(alignment: .trailing) {
                    // A trailing fade says "there are more columns".
                    LinearGradient(colors: [secondaryGroupedBackground.opacity(0), secondaryGroupedBackground], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 36)
                        .opacity(hasMoreToTrailing ? 1 : 0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .animation(.easeOut(duration: 0.15), value: hasMoreToTrailing)
                }
                .accessibilityIdentifier("contrastMatrix.grid")

                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.isMatrixTruncated {
                    Label("Showing the first \(ContrastMatrixLimit.value) of \(model.memberCount) colors.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footnote: String {
        switch model.contrastMode {
        case .wcag: String(localized: "Rows are the text color and columns the background. WCAG ratios are the same both ways. Tap a pair to open the contrast checker.")
        case .apca: String(localized: "Rows are the text color and columns the background. APCA depends on which color is the text. Tap a pair to open the contrast checker.")
        }
    }

    // MARK: Summary and measure

    private func summaryLine(_ matrix: ContrastMatrix) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
            summaryText(matrix)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Brand.Space.sm)
            Menu {
                Picker("Measure", selection: $model.contrastMode) {
                    Text("WCAG").tag(ContrastMatrixMode.wcag)
                    Text("APCA").tag(ContrastMatrixMode.apca)
                }
            } label: {
                HStack(spacing: 3) {
                    Text(model.contrastMode == .wcag ? "WCAG" : "APCA")
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Brand.Space.md)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(groupedBackground))
            }
            .accessibilityLabel(Text("Measure"))
            .accessibilityValue(Text(model.contrastMode == .wcag ? "WCAG" : "APCA"))
            .accessibilityIdentifier("contrastMatrix.mode")
        }
    }

    @ContentBuilder
    private func summaryText(_ matrix: ContrastMatrix) -> some View {
        switch model.contrastMode {
        case .wcag:
            let passingCount: Int = matrix.passingPairCount
            let totalCount: Int = matrix.pairCount
            Text("\(passingCount) of \(totalCount) pairs pass AA for normal text")
        case .apca:
            let readableCount: Int = matrix.cells.filter { abs($0.lc) >= 60 }.count
            let totalCount: Int = matrix.cells.count
            Text("\(readableCount) of \(totalCount) text and background combinations reach Lc 60")
        }
    }

    // MARK: Grid

    private func grid(_ matrix: ContrastMatrix, colors: [OpaliteColor]) -> some View {
        let width = cellWidth(count: colors.count)
        return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            GridRow {
                Color.clear.frame(width: headerWidth, height: 1)
                ForEach(colors.indices, id: \.self) { column in
                    header(colors[column], width: width)
                }
            }
            ForEach(colors.indices, id: \.self) { row in
                GridRow {
                    header(colors[row], width: headerWidth)
                    ForEach(colors.indices, id: \.self) { column in
                        if let cell = matrix.cell(row: row, column: column) {
                            cellButton(cell, text: colors[row], background: colors[column], width: width)
                        } else {
                            diagonal(width: width)
                        }
                    }
                }
            }
        }
    }

    private func header(_ color: OpaliteColor, width: CGFloat) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                .fill(color.rgba.color)
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
            Text(color.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: width)
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }

    /// The pair of a color with itself: empty, but visibly part of the grid.
    private func diagonal(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
            .fill(Color.secondary.opacity(0.1))
            .frame(width: width, height: cellHeight)
            .accessibilityHidden(true)
    }

    private func cellButton(_ cell: ContrastMatrix.Cell, text: OpaliteColor, background: OpaliteColor, width: CGFloat) -> some View {
        Button {
            Haptics.selection()
            model.openContrast(row: cell.row, column: cell.column)
        } label: {
            VStack(spacing: 0) {
                Text("Aa")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(text.rgba.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(background.rgba.color)
                VStack(spacing: 3) {
                    switch model.contrastMode {
                    case .wcag:
                        Text(verbatim: cell.ratioText)
                            .font(.caption.monospacedDigit().weight(.semibold))
                        wcagBadge(cell)
                    case .apca:
                        Text(verbatim: APCA.lcText(cell.lc))
                            .font(.caption.monospacedDigit().weight(.semibold))
                        apcaBadge(cell.apcaBand)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cellHeight - 34)
                .background(groupedBackground)
            }
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverLift()
        .accessibilityLabel(Text("\(text.displayName) on \(background.displayName)"))
        .accessibilityValue(Text(accessibilityValue(cell)))
        .accessibilityHint(Text("Opens the contrast checker for this pair"))
    }

    /// The best WCAG level the ratio reaches: AAA and AA for normal text, AA Large for large text only.
    @ContentBuilder
    private func wcagBadge(_ cell: ContrastMatrix.Cell) -> some View {
        switch cell.normalLevel {
        case .aaa: ResultBadge(text: "AAA", tone: .pass)
        case .aa: ResultBadge(text: "AA", tone: .pass)
        case .fail:
            if cell.largeLevel == .fail {
                ResultBadge(text: String(localized: "Fail"), tone: .miss)
            } else {
                ResultBadge(text: String(localized: "AA Large"), tone: .partial)
            }
        }
    }

    private func apcaBadge(_ band: APCA.Band) -> some View {
        let tone: ResultBadge.Tone
        switch band {
        case .fail, .spot: tone = .miss
        case .large: tone = .partial
        case .content, .body, .fluent: tone = .pass
        }
        return ResultBadge(text: band.shortGuidance, tone: tone)
    }

    private func accessibilityValue(_ cell: ContrastMatrix.Cell) -> String {
        switch model.contrastMode {
        case .wcag:
            let normal = cell.normalLevel == .fail ? String(localized: "Fail") : (cell.normalLevel == .aaa ? "AAA" : "AA")
            let large = cell.largeLevel == .fail ? String(localized: "Fail") : (cell.largeLevel == .aaa ? "AAA" : "AA")
            return String(localized: "Contrast \(cell.ratioText). Normal text \(normal). Large text \(large).")
        case .apca:
            return String(localized: "\(APCA.lcText(cell.lc)). \(cell.apcaBand.guidance).")
        }
    }
}

/// Keeps the "first N colors" note in step with the model's cap.
private enum ContrastMatrixLimit {
    static var value: Int { PaletteDetailViewModel.maxMatrixColors }
}

// MARK: - Contrast checker for a pair

/// Resolves the environment, then hosts the existing contrast checker preloaded with the pair.
struct ContrastPairSheet: View {
    let pair: ContrastPair

    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toasts

    var body: some View {
        ContrastPairContent(pair: pair, portfolio: portfolio, toasts: toasts)
    }
}

private struct ContrastPairContent: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ColorDetailViewModel

    init(pair: ContrastPair, portfolio: PortfolioModel, toasts: ToastManager) {
        let model = ColorDetailViewModel(colorID: pair.textID, portfolio: portfolio, toasts: toasts)
        if let background = portfolio.color(withID: pair.backgroundID) {
            model.selectContrast(ContrastCandidate(id: background.id, name: background.name, rgba: background.rgba))
        }
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ContrastCheckerCard(model: model, candidates: model.contrastCandidates)
                    .padding(Brand.Space.lg)
                    .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
                    .padding(Brand.Space.lg)
                    .frame(maxWidth: Brand.detailMaxWidth)
                    .frame(maxWidth: .infinity)
            }
            .background(groupedBackground)
            .navigationTitle("Contrast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("contrastPairSheet")
    }
}

// MARK: - Lightness scale

struct LightnessScaleCard: View {
    @Bindable var model: PaletteDetailViewModel
    let onAddAsPalette: () -> Void

    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.onyxEntitlement) private var entitlement
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isHexFocused: Bool

    private var isAtPaletteLimit: Bool {
        !OnyxGate(hasOnyx: entitlement.hasOnyx).canCreatePalette(currentCount: portfolio.palettes.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            baseChooser
            hexField

            let steps = model.scaleSteps
            if steps.isEmpty {
                Text("Add a color to build a scale from it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ramp(steps)
                if let step = model.shownScaleStep { detail(step) }
                Button {
                    Haptics.selection()
                    onAddAsPalette()
                } label: {
                    Label("Add as Palette", systemImage: isAtPaletteLimit ? "lock.fill" : "plus")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionButton()
                .accessibilityIdentifier("lightnessScale.addAsPalette")
                .accessibilityHint(Text("Saves these 11 colors as a new palette"))
            }
        }
    }

    // MARK: Base

    private var baseChooser: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text("Start from")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Brand.Space.sm) {
                    ForEach(model.members) { color in
                        let isBase = model.scaleCustom == nil && model.scaleBaseColor?.id == color.id
                        Button {
                            Haptics.selection()
                            model.selectScaleBase(color)
                        } label: {
                            ColorChip(color.rgba, size: 44, label: nil)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: isBase ? 3 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .hoverLift()
                        .accessibilityLabel(Text(color.displayName))
                        .accessibilityAddTraits(isBase ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var hexField: some View {
        HStack(spacing: Brand.Space.sm) {
            if let custom = model.scaleCustom {
                ColorChip(custom, size: 22, cornerRadius: 6)
            } else {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            TextField(String(localized: "Or start from a hex code"), text: $model.scaleHexDraft)
                .textFieldStyle(.plain)
                .font(.body)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($isHexFocused)
                .onSubmit { applyHex() }
                .accessibilityLabel(Text("Scale hex code"))
            Button {
                applyHex()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .disabled(RGBA(hex: model.scaleHexDraft) == nil)
            .accessibilityLabel(Text("Use this hex code"))
        }
        .padding(.horizontal, Brand.Space.md)
        .padding(.vertical, Brand.Space.sm)
        .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
    }

    private func applyHex() {
        if model.applyScaleHex() {
            Haptics.selection()
            isHexFocused = false
        } else {
            Haptics.error()
        }
    }

    // MARK: Ramp

    private func ramp(_ steps: [LightnessScale.Step]) -> some View {
        let nearest = model.nearestScaleStep?.stop
        let shown = model.shownScaleStep?.stop
        return VStack(alignment: .leading, spacing: Brand.Space.xs) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(steps) { step in
                    Button {
                        Haptics.selection()
                        withAnimation(reduceMotion ? nil : .snappy) { model.selectedScaleStop = step.stop }
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(step.srgb.color)
                                .frame(height: 64)
                                .overlay {
                                    if step.stop == nearest {
                                        Circle()
                                            .fill(step.srgb.prefersDarkText ? Color.black.opacity(0.7) : Color.white.opacity(0.85))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.quaternary))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: step.stop == shown ? 3 : 0)
                                )
                            Text(verbatim: String(step.stop))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(step.stop == shown ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Step \(step.stop), \(step.srgb.hexString)"))
                    .accessibilityAddTraits(step.stop == shown ? .isSelected : [])
                }
            }
            .accessibilityIdentifier("lightnessScale.ramp")
            Text("Same hue and chroma as your color, with evenly spaced lightness (OKLCH). The dot marks the closest step.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func detail(_ step: LightnessScale.Step) -> some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            ColorChip(step.srgb, size: 44, label: nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(model.scaleBaseName) \(step.stop)")
                    .font(.subheadline.weight(.semibold))
                Text(verbatim: step.srgb.hexString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(verbatim: step.srgb.oklchString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let p3 = step.displayP3 {
                    Text(verbatim: wideGamutString(p3))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Wide gamut: Display P3 holds more chroma than the sRGB color above, which is the one saved.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if step.isChromaReduced {
                    Text("Chroma reduced to fit sRGB.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Button {
                hexCopy.copy(hex: step.srgb.hexString)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text("Copy hex"))
        }
        .accessibilityElement(children: .contain)
    }

    private func wideGamutString(_ p3: DisplayP3) -> String {
        "color(display-p3 \(String(format: "%.4f", p3.red)) \(String(format: "%.4f", p3.green)) \(String(format: "%.4f", p3.blue)))"
    }
}

// MARK: - Color vision

struct ColorVisionCard: View {
    @Bindable var model: PaletteDetailViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shownPairLimit = 8

    var body: some View {
        let analysis = model.colorVision
        let threshold = String(format: "%.2f", ColorVisionAnalysis.confusionThreshold)
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            if model.memberCount < 2 {
                Text("Add at least two colors to see how well they hold apart for people with color-vision deficiency.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: Brand.Space.sm) {
                    ForEach(analysis.reports) { report in scoreTile(report) }
                }
                if let report = analysis.report(for: model.visionMode) {
                    problems(report, analysis: analysis)
                }
                Text("Pairs closer than \(threshold) in OKLab after simulation are hard to tell apart. Only pairs that differ in normal vision are scored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if analysis.similarForEveryonePairCount > 0 {
                    Label("\(analysis.similarForEveryonePairCount) pairs are already close in normal vision and are not scored.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Scores

    private func scoreTile(_ report: ColorVisionAnalysis.Report) -> some View {
        let selected = report.mode == model.visionMode
        return Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .snappy) { model.visionMode = report.mode }
        } label: {
            VStack(spacing: 4) {
                Text(report.mode.shortTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    Image(systemName: statusSymbol(report))
                        .font(.footnote)
                        .foregroundStyle(statusTint(report))
                        .accessibilityHidden(true)
                    if let score = report.score {
                        Text(verbatim: String(score))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .monospacedDigit()
                    } else {
                        Text(verbatim: "–")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                    }
                }
                Text(report.problemPairs.count == 1 ? String(localized: "1 problem pair") : String(localized: "\(report.problemPairs.count) problem pairs"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, Brand.Space.sm)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(groupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: selected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .hoverLift()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(report.mode.shortTitle))
        .accessibilityValue(Text(scoreSpeech(report)))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("colorVision.score.\(report.mode.rawValue)")
    }

    private func statusSymbol(_ report: ColorVisionAnalysis.Report) -> String {
        guard let score = report.score else { return "minus.circle" }
        return score >= 90 ? "checkmark.circle.fill" : (score >= 70 ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
    }

    private func statusTint(_ report: ColorVisionAnalysis.Report) -> Color {
        guard let score = report.score else { return .secondary }
        return score >= 90 ? .green : (score >= 70 ? .orange : .red)
    }

    private func scoreSpeech(_ report: ColorVisionAnalysis.Report) -> String {
        guard let score = report.score else { return String(localized: "No score") }
        return String(localized: "Score \(score) out of 100, \(report.problemPairs.count) problem pairs")
    }

    // MARK: Problem pairs

    @ContentBuilder
    private func problems(_ report: ColorVisionAnalysis.Report, analysis: ColorVisionAnalysis) -> some View {
        let members = model.members
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text(report.mode.title)
                .font(.subheadline.weight(.semibold))
            Text(report.mode.modeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            if report.problemPairs.isEmpty {
                Label(report.score == nil ? String(localized: "Nothing to score yet: every pair is already close in normal vision.") : String(localized: "Every pair stays easy to tell apart."), systemImage: report.score == nil ? "info.circle" : "checkmark.seal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                pairHeader
                ForEach(report.problemPairs.prefix(shownPairLimit)) { pair in
                    if members.indices.contains(pair.first), members.indices.contains(pair.second) {
                        pairRow(pair, first: members[pair.first], second: members[pair.second])
                        if pair.id != report.problemPairs.prefix(shownPairLimit).last?.id { Divider() }
                    }
                }
                if report.problemPairs.count > shownPairLimit {
                    Text("+ \(report.problemPairs.count - shownPairLimit) more pairs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private let swatchWidth: CGFloat = 72
    private let arrowWidth: CGFloat = 16

    /// Column labels, said once above the list.
    private var pairHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.md) {
            Text("As designed")
                .frame(width: swatchWidth, alignment: .leading)
            Color.clear.frame(width: arrowWidth, height: 1)
            Text("As seen")
                .frame(width: swatchWidth, alignment: .leading)
            Spacer(minLength: 0)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityHidden(true)
    }

    private func severityText(_ severity: ColorVisionAnalysis.Severity) -> String {
        switch severity {
        case .nearlyIdentical: String(localized: "Nearly identical")
        case .veryHard: String(localized: "Very hard to tell apart")
        case .hard: String(localized: "Hard to tell apart")
        }
    }

    private func pairRow(_ pair: ColorVisionAnalysis.Pair, first: OpaliteColor, second: OpaliteColor) -> some View {
        let simulated = String(format: "%.3f", pair.simulatedDistance)
        let normal = String(format: "%.3f", pair.normalDistance)
        let severity = severityText(pair.severity)
        return HStack(alignment: .center, spacing: Brand.Space.md) {
            split(first.rgba, second.rgba)
            Image(systemName: "arrow.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(width: arrowWidth)
                .accessibilityHidden(true)
            split(pair.simulatedFirst, pair.simulatedSecond)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(first.displayName) / \(second.displayName)")
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                Text(verbatim: severity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(first.displayName) and \(second.displayName)"))
        .accessibilityValue(Text("\(severity). Distance \(simulated) after simulation, \(normal) in normal vision."))
    }

    /// Two colors side by side in one rounded tile, so how close they look is obvious.
    private func split(_ a: RGBA, _ b: RGBA) -> some View {
        HStack(spacing: 0) {
            a.color
            b.color
        }
        .frame(width: swatchWidth, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
        .accessibilityHidden(true)
    }
}
#endif

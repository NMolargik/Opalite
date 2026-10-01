//
//  PaletteSection.swift
//  OpaliteFeaturePortfolio
//
//  One palette in the Portfolio: a header (name → detail, count, overflow menu) and its
//  swatch row, which accepts drops. In the two-column layout it's a card; in one column
//  it's a plain section so the swatches stay the focus.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import TipKit
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureSharing

struct PaletteSection: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(ToastManager.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let palette: OpalitePalette
    @Bindable var model: PortfolioViewModel
    let swatchSize: SwatchSize
    let namespace: Namespace.ID
    let showsTip: Bool
    let asCard: Bool

    @State private var isRenaming = false
    @State private var renameDraft = ""
    @State private var isConfirmingDelete = false
    @State private var isConfirmingArchive = false
    @State private var isShowingExport = false
    @State private var isShowingPublish = false
    @State private var isShowingCanvasPicker = false

    private let paletteMenuTip = PaletteMenuTip()

    private var colors: [OpaliteColor] { portfolio.colors(in: palette) }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            if showsTip {
                TipView(paletteMenuTip)
                    .tipCornerRadius(Brand.Radius.card)
                    .padding(.horizontal, asCard ? 0 : Brand.Space.lg)
            }
            header
            SwatchRow(
                colors: colors,
                palette: palette,
                swatchSize: swatchSize,
                matchedNamespace: namespace,
                onSelect: { router.open(.color($0.id)) },
                onCreate: { model.requestEditor(for: palette) },
                menu: { color in
                    ColorActionsMenu(
                        color: color,
                        onRename: { model.beginRenaming(color) },
                        onMove: { model.activeSheet = .moveColor(color.id) },
                        onRemoveFromPalette: { model.removeFromPalette(color) },
                        onExport: { model.activeSheet = .exportColor(color.id) },
                        onPublish: { model.activeSheet = .publishColor(color.id) },
                        onDelete: { model.confirmDelete(color) }
                    )
                }
            )
            .zIndex(1)
        }
        .padding(.vertical, asCard ? Brand.Space.md : 0)
        .if(asCard) { $0.cardSurface().clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)) }
        .alert("Rename Palette", isPresented: $isRenaming) {
            TextField(String(localized: "Palette name"), text: $renameDraft)
            Button("Cancel", role: .cancel) { renameDraft = "" }
            Button("Save") {
                portfolio.rename(palette, to: renameDraft)
                renameDraft = ""
            }
        }
        .confirmationDialog("Delete \(palette.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Palette", role: .destructive) {
                withAnimation(reduceMotion ? nil : .snappy) { portfolio.delete(palette, deleteColors: false) }
            }
            if !colors.isEmpty {
                Button("Delete Palette and Colors", role: .destructive) {
                    withAnimation(reduceMotion ? nil : .snappy) { portfolio.delete(palette, deleteColors: true) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(colors.isEmpty ? "This can't be undone." : "Deleting only the palette keeps its colors in your Portfolio.")
        }
        .confirmationDialog("Archive \(palette.name)?", isPresented: $isConfirmingArchive, titleVisibility: .visible) {
            Button("Archive") {
                withAnimation(reduceMotion ? nil : .snappy) { portfolio.setArchived(palette, true) }
                toasts.show(message: String(localized: "Archived \(palette.name)"), style: .info, systemImage: "archivebox.fill")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived palettes leave the Portfolio but stay in Archived Palettes, where you can restore them.")
        }
        .sheet(isPresented: $isShowingExport) { PaletteExportSheet(palette: palette) }
        .sheet(isPresented: $isShowingPublish) { PublishPaletteSheet(palette: palette) }
        .sheet(isPresented: $isShowingCanvasPicker) {
            CanvasPickerSheet { canvas in
                portfolio.link(canvas, to: palette)
                toasts.showSuccess(String(localized: "Linked \(canvas.title)"), systemImage: "link")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
            NavigationLink(value: PortfolioDestination.palette(palette.id)) {
                HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
                    Text(palette.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Text(colors.count, format: .number)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .snappy, value: colors.count)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()
            .accessibilityLabel(Text("\(palette.name), \(colors.count) colors"))
            .accessibilityHint(Text("Opens the palette"))
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Brand.Space.sm)

            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hoverLift()
            .accessibilityLabel(Text("Actions for \(palette.name)"))
        }
        .padding(.horizontal, Brand.Space.lg)
    }

    @ContentBuilder
    private var menuItems: some View {
        Button {
            Haptics.selection()
            model.requestEditor(for: palette)
        } label: {
            Label("Add Color", systemImage: "plus")
        }

        Button {
            Haptics.selection()
            renameDraft = palette.name
            isRenaming = true
        } label: {
            Label("Rename…", systemImage: "character.cursor.ibeam")
        }

        Divider()

        Button {
            Haptics.selection()
            isShowingExport = true
        } label: {
            Label("Export…", systemImage: "square.and.arrow.up")
        }
        .disabled(colors.isEmpty)

        Button {
            Haptics.selection()
            isShowingPublish = true
        } label: {
            Label("Publish to Community…", systemImage: "person.2")
        }
        .disabled(colors.isEmpty)

        if let canvas = palette.canvasFile {
            Button {
                Haptics.selection()
                portfolio.link(nil, to: palette)
            } label: {
                Label("Unlink \(canvas.title)", systemImage: "link.badge.minus")
            }
        } else {
            Button {
                Haptics.selection()
                isShowingCanvasPicker = true
            } label: {
                Label("Link Canvas…", systemImage: "link.badge.plus")
            }
        }

        Divider()

        Button {
            Haptics.selection()
            isConfirmingArchive = true
        } label: {
            Label("Archive", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            Haptics.selection()
            isConfirmingDelete = true
        } label: {
            Label("Delete…", systemImage: "trash")
        }
    }
}
#endif

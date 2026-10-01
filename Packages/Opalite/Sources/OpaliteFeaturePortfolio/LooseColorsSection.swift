//
//  LooseColorsSection.swift
//  OpaliteFeaturePortfolio
//
//  The "Colors" row: colors that aren't in a palette. A drop target (dropping here
//  removes a color from its palette) with a multi-select mode for moving or deleting
//  several at once.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct LooseColorsSection: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var model: PortfolioViewModel
    let swatchSize: SwatchSize
    let namespace: Namespace.ID

    private var colors: [OpaliteColor] { portfolio.looseColors }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            header
            if model.selection.isActive { selectionBar }
            SwatchRow(
                colors: colors,
                palette: nil,
                swatchSize: swatchSize,
                selectedIDs: model.selection.selectedIDs,
                matchedNamespace: namespace,
                onSelect: { color in
                    if !model.handleTap(on: color) { router.open(.color(color.id)) }
                },
                onCreate: { model.requestEditor() },
                menu: { color in
                    if !model.selection.isActive {
                        ColorActionsMenu(
                            color: color,
                            onRename: { model.beginRenaming(color) },
                            onMove: { model.activeSheet = .moveColor(color.id) },
                            onExport: { model.activeSheet = .exportColor(color.id) },
                            onPublish: { model.activeSheet = .publishColor(color.id) },
                            onDelete: { model.confirmDelete(color) }
                        )
                    }
                }
            )
            .zIndex(1)
        }
    }

    private var header: some View {
        HStack(spacing: Brand.Space.sm) {
            Image(systemName: "paintpalette.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.opalitePurple)
                .accessibilityHidden(true)
            Text("Colors")
                .font(.title2.weight(.semibold))
            Text(colors.count, format: .number)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy, value: colors.count)
            Spacer(minLength: 0)
            if !colors.isEmpty {
                Button {
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .snappy) { model.toggleSelectionMode() }
                } label: {
                    Text(model.selection.isActive ? "Done" : "Select")
                        .font(.subheadline.weight(.semibold))
                }
                .glassActionButton(tint: .opalitePurple, prominent: model.selection.isActive)
                .controlSize(.small)
                .hoverHighlight()
                .accessibilityIdentifier("portfolio.selectColors")
            }
        }
        .padding(.horizontal, Brand.Space.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Colors, \(colors.count) items"))
        .accessibilityAddTraits(.isHeader)
    }

    private var selectionBar: some View {
        HStack(spacing: Brand.Space.md) {
            Button(model.selection.isAllSelected(of: colors.map(\.id)) ? "Deselect All" : "Select All") {
                Haptics.selection()
                model.selection.toggleAll(of: colors.map(\.id))
            }
            .font(.subheadline)
            Spacer(minLength: 0)
            Button {
                Haptics.selection()
                model.activeSheet = .moveSelection
            } label: {
                Label("Move", systemImage: "swatchpalette")
            }
            .disabled(model.selection.isEmpty)
            Button(role: .destructive) {
                Haptics.warning()
                model.isConfirmingBatchDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(model.selection.isEmpty)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, Brand.Space.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
#endif

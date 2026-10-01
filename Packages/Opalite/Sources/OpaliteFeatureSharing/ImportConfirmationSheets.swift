//
//  ImportConfirmationSheets.swift
//  OpaliteFeatureSharing
//
//  What opening an `.opalitecolor` / `.opalitepalette` file will do, with one primary
//  action. The previews come from Core; confirmation goes through `ImportModel`, which
//  the shell binds to the sheet's presentation.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - Color

public struct ColorImportConfirmationSheet: View {
    private let preview: ColorImportPreview
    private let summary: ColorImportSummary

    @Environment(\.dismiss) private var dismiss
    @Environment(ImportModel.self) private var importer
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(HexCopyModel.self) private var hexCopy

    public init(preview: ColorImportPreview) {
        self.preview = preview
        self.summary = ColorImportSummary(preview: preview)
    }

    private var color: DecodedColor { preview.color }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ColorHero(rgba: color.rgba, title: summary.title)
                        .padding(.vertical, Brand.Space.sm)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Details") {
                    if let name = color.name, !name.isEmpty {
                        DetailRow(String(localized: "Name"), value: name, systemImage: "textformat")
                    }
                    DetailRow(String(localized: "Hex"), value: hexCopy.formatted(color.rgba.hexString), systemImage: "number", monospaced: true) {
                        hexCopy.copy(hex: color.rgba.hexString)
                    }
                    DetailRow(String(localized: "RGB"), value: color.rgba.rgbString, systemImage: "slider.horizontal.3", monospaced: true)
                    if let author = color.createdByDisplayName, !author.isEmpty, author != "Unknown" {
                        DetailRow(String(localized: "Created by"), value: author, systemImage: "person")
                    }
                    DetailRow(String(localized: "Created"), value: color.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    if let notes = color.notes, !notes.isEmpty {
                        NotesRow(notes: notes)
                    }
                }

                Section {
                    StatusCallout(
                        title: summary.headline,
                        message: summary.detail,
                        systemImage: summary.outcome.systemImage,
                        tint: summary.willSkip ? .yellow : .green
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ActionBar {
                    Button {
                        confirm()
                    } label: {
                        Label(summary.actionTitle, systemImage: summary.canImport ? "square.and.arrow.down" : "checkmark")
                    }
                    .primaryActionButton()
                    .accessibilityHint(summary.canImport ? Text("Adds the color to your Portfolio") : Text("Closes without changes"))
                    .accessibilityIdentifier("sharing.import.confirm")
                }
            }
        }
        .sharingSheet(detents: [.medium, .large])
    }

    private func confirm() {
        if summary.canImport {
            importer.confirmColorImport(into: portfolio)
            Haptics.success()
        } else {
            Haptics.selection()
        }
        dismiss()
    }
}

// MARK: - Palette

public struct PaletteImportConfirmationSheet: View {
    private let preview: PaletteImportPreview
    private let summary: PaletteImportSummary

    @Environment(\.dismiss) private var dismiss
    @Environment(ImportModel.self) private var importer
    @Environment(PortfolioModel.self) private var portfolio

    public init(preview: PaletteImportPreview) {
        self.preview = preview
        self.summary = PaletteImportSummary(preview: preview)
    }

    private var palette: DecodedPalette { preview.palette }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    PaletteHero(
                        name: palette.name,
                        colors: palette.colors.map(\.rgba),
                        background: palette.previewBackgroundRaw.flatMap(PreviewBackground.init(rawValue:))
                    )
                    .padding(.vertical, Brand.Space.sm)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    DetailRow(String(localized: "Name"), value: palette.name, systemImage: "textformat")
                    DetailRow(String(localized: "Colors"), value: palette.colors.count.formatted(), systemImage: "paintpalette")
                    if let author = palette.createdByDisplayName, !author.isEmpty, author != "Unknown" {
                        DetailRow(String(localized: "Created by"), value: author, systemImage: "person")
                    }
                    DetailRow(String(localized: "Created"), value: palette.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    if !palette.tags.isEmpty {
                        VStack(alignment: .leading, spacing: Brand.Space.sm) {
                            Text("Tags")
                                .foregroundStyle(.secondary)
                            TagChips(tags: palette.tags)
                        }
                        .padding(.vertical, Brand.Space.xs)
                    }
                    if let notes = palette.notes, !notes.isEmpty {
                        NotesRow(notes: notes)
                    }
                }

                Section {
                    StatusCallout(
                        title: summary.headline,
                        message: summary.detail,
                        systemImage: summary.isUpdate ? "arrow.triangle.2.circlepath.circle.fill" : "plus.circle.fill",
                        tint: summary.isUpdate ? .blue : .green
                    )
                    ForEach(summary.outcomes) { outcome in
                        OutcomeRow(outcome: outcome)
                    }
                } header: {
                    Text("What will happen")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ActionBar {
                    Button {
                        confirm()
                    } label: {
                        Label(summary.actionTitle, systemImage: summary.isUpdate ? "arrow.triangle.2.circlepath" : "square.and.arrow.down")
                    }
                    .primaryActionButton()
                    .disabled(!summary.canImport)
                    .accessibilityHint(summary.isUpdate ? Text("Updates the palette in your Portfolio") : Text("Adds the palette to your Portfolio"))
                    .accessibilityIdentifier("sharing.import.confirm")
                }
            }
        }
        .sharingSheet(detents: [.large])
    }

    private func confirm() {
        importer.confirmPaletteImport(into: portfolio)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Notes row

/// Multi-line notes under a caption, matching `DetailRow`'s rhythm.
private struct NotesRow: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xs) {
            Text("Notes")
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Brand.Space.xs)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Import Color · new") {
    let decoded = DecodedColor(id: UUID(), name: "Harbor Blue", notes: "Pulled from a photo of the marina.", rgba: RGBA(red: 0.2, green: 0.45, blue: 0.7), createdByDisplayName: "Ada")
    ColorImportConfirmationSheet(preview: ColorImportPreview(color: decoded, existingColorID: nil))
        .previewEnvironment()
}

#Preview("Import Color · duplicate") {
    let decoded = DecodedColor(id: UUID(), name: nil, notes: nil, rgba: RGBA(red: 0.9, green: 0.3, blue: 0.5, alpha: 0.6))
    ColorImportConfirmationSheet(preview: ColorImportPreview(color: decoded, existingColorID: decoded.id))
        .previewEnvironment()
}

#Preview("Import Palette · update") {
    let colors = OpalitePalette.sample.sortedColors.map { DecodedColor(id: $0.id, name: $0.name, notes: $0.notes, rgba: $0.rgba) }
    let decoded = DecodedPalette(id: UUID(), name: "Harbor", notes: "Evening tones.", tags: ["sea", "dusk"], createdByDisplayName: "Ada", previewBackgroundRaw: PreviewBackground.navy.rawValue, createdAt: .now, updatedAt: .now, colors: colors)
    PaletteImportConfirmationSheet(preview: PaletteImportPreview(palette: decoded, existingPaletteID: decoded.id, newColors: Array(colors.prefix(2)), existingColorIDs: colors.dropFirst(2).map(\.id)))
        .previewEnvironment()
}
#endif
#endif

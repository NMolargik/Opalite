//
//  TVPaletteDetailView.swift
//  OpaliteFeatureTV
//
//  A palette at TV scale: header with the strip and one action (slideshow), then an
//  adaptive grid of swatch cards, notes and provenance.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVPaletteDetailView: View {
    let paletteID: UUID

    @Environment(PortfolioModel.self) private var portfolio
    @State private var presentation: TVPresentationRequest?

    var body: some View {
        if let palette = portfolio.palette(withID: paletteID) {
            content(for: palette)
                .onAppear { portfolio.activePaletteID = paletteID }
                .onDisappear { if portfolio.activePaletteID == paletteID { portfolio.activePaletteID = nil } }
                .fullScreenCover(item: $presentation) { request in
                    TVPresentationView(request: request)
                }
        } else {
            ContentUnavailableView(
                "Palette Not Found",
                systemImage: "questionmark.circle",
                description: Text("This palette may have been deleted on another device.")
            )
        }
    }

    private func content(for palette: OpalitePalette) -> some View {
        let colors = palette.sortedColors
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Brand.Space.xxl) {
                header(for: palette, colors: colors)

                if colors.isEmpty {
                    ContentUnavailableView(
                        "No Colors",
                        systemImage: "paintpalette",
                        description: Text("Add colors to this palette on your iPhone, iPad, or Mac.")
                    )
                    .padding(.top, Brand.Space.xxl)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: TVLayout.cardSide + 40), spacing: 48)], spacing: 56) {
                        ForEach(colors) { color in
                            TVSwatchCard(color: color)
                        }
                    }
                    .padding(.horizontal, TVLayout.gutter)
                    .focusSection()
                }

                if let notes = palette.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: Brand.Space.md) {
                        Text("Notes")
                            .font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(notes)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Brand.Space.xl)
                            .adaptiveGlass(cornerRadius: Brand.Radius.card)
                            .tvFocusStop()
                    }
                    .padding(.horizontal, TVLayout.gutter)
                }

                provenance(for: palette)
                    .padding(.horizontal, TVLayout.gutter)
            }
            .padding(.vertical, Brand.Space.xxl)
        }
        .scrollClipDisabled()
        .navigationTitle(palette.name)
    }

    // MARK: - Pieces

    private func header(for palette: OpalitePalette, colors: [OpaliteColor]) -> some View {
        HStack(alignment: .center, spacing: Brand.Space.xl) {
            TVPaletteStrip(colors: colors.map(\.rgba), height: 72, segmentWidth: 28)

            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text(palette.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: Brand.Space.md) {
                    Text("\(colors.count) colors")
                    if !palette.tags.isEmpty {
                        Text(palette.tags.map { "#\($0)" }.joined(separator: "  "))
                            .lineLimit(1)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !colors.isEmpty {
                Button("Show Full Screen", systemImage: "tv") {
                    presentation = TVPresentationRequest(colors: colors)
                }
                .accessibilityHint(Text("Shows each color edge to edge. Swipe to move between them."))
                .accessibilityIdentifier("showFullScreen")
            }
        }
        .padding(.horizontal, TVLayout.gutter)
        .focusSection()
    }

    private func provenance(for palette: OpalitePalette) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            Text("Details")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: Brand.Space.md) {
                if let author = palette.createdByDisplayName, !author.isEmpty {
                    LabeledContent("Created by", value: author)
                }
                LabeledContent("Created", value: palette.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Updated", value: palette.updatedAt.formatted(date: .abbreviated, time: .omitted))
                if palette.isArchived {
                    LabeledContent("Status", value: String(localized: "Archived"))
                }
            }
            .font(.callout)
            .padding(Brand.Space.xl)
            .adaptiveGlass(cornerRadius: Brand.Radius.card)
            .tvFocusStop()
        }
    }
}

#if DEBUG
#Preview {
    let environment = PreviewEnvironment()
    let id = environment.portfolio.palettes.first!.id
    return NavigationStack {
        TVPaletteDetailView(paletteID: id)
    }
    .previewEnvironment(environment)
}
#endif
#endif

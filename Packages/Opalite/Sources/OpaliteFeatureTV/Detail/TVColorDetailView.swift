//
//  TVColorDetailView.swift
//  OpaliteFeatureTV
//
//  A color at TV scale: the hero swatch with one action (show full screen), and the
//  readouts, harmonies, notes and provenance as focusable tiles beside it.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVColorDetailView: View {
    let colorID: UUID

    @Environment(PortfolioModel.self) private var portfolio
    @Environment(HexCopyModel.self) private var hexCopy
    @State private var presentation: TVPresentationRequest?

    var body: some View {
        if let color = portfolio.color(withID: colorID) {
            content(for: color)
                .onAppear { portfolio.activeColorID = colorID }
                .onDisappear { if portfolio.activeColorID == colorID { portfolio.activeColorID = nil } }
                .fullScreenCover(item: $presentation) { request in
                    TVPresentationView(request: request)
                }
        } else {
            ContentUnavailableView(
                "Color Not Found",
                systemImage: "questionmark.circle",
                description: Text("This color may have been deleted on another device.")
            )
        }
    }

    private func content(for color: OpaliteColor) -> some View {
        HStack(alignment: .top, spacing: 64) {
            hero(for: color)
                .frame(width: TVLayout.heroSide)
                .focusSection()

            ScrollView {
                VStack(alignment: .leading, spacing: Brand.Space.xxl) {
                    readouts(for: color)
                    harmonies(for: color)
                    notes(for: color)
                    provenance(for: color)
                }
                .padding(.vertical, Brand.Space.xl)
                .padding(.trailing, TVLayout.gutter)
            }
            .scrollClipDisabled()
            .focusSection()
        }
        .padding(.leading, TVLayout.gutter)
        .padding(.top, Brand.Space.xxl)
        .navigationTitle(color.displayName)
    }

    // MARK: - Hero

    private func hero(for color: OpaliteColor) -> some View {
        VStack(spacing: Brand.Space.xl) {
            TVSwatchFill(color.rgba, cornerRadius: Brand.Radius.sheet)
                .frame(width: TVLayout.heroSide, height: TVLayout.heroSide)
                .shadow(color: color.swiftUIColor.opacity(0.35), radius: 40, y: 16)
                .accessibilityHidden(true)

            VStack(spacing: Brand.Space.xs) {
                Text(color.displayName)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(hexCopy.formatted(color))
                    .font(.title3.monospaced())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(color.hasName ? "\(color.displayName), \(color.hexString)" : String(localized: "Unnamed color, \(color.hexString)")))

            Button("Show Full Screen", systemImage: "tv") {
                presentation = TVPresentationRequest(colors: [color])
            }
            .accessibilityHint(Text("Fills the screen with this color"))
            .accessibilityIdentifier("showFullScreen")
        }
    }

    // MARK: - Sections

    private func readouts(for color: OpaliteColor) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: Brand.Space.lg)], spacing: Brand.Space.lg) {
            TVReadoutTile(title: String(localized: "Hex"), value: hexCopy.formatted(color))
            TVReadoutTile(title: String(localized: "RGB"), value: color.rgbString)
            TVReadoutTile(title: String(localized: "HSL"), value: color.hslString)
            TVReadoutTile(title: String(localized: "HSV"), value: hsvString(color.hsv))
            TVReadoutTile(title: String(localized: "CMYK"), value: cmykString(color.cmyk))
            TVReadoutTile(title: String(localized: "Luminance"), value: color.relativeLuminance.formatted(.number.precision(.fractionLength(3))))
        }
    }

    private func harmonies(for color: OpaliteColor) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.lg) {
            Text("Harmonies")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            TVHarmonyRow(title: String(localized: "Complementary"), colors: [ColorHarmony.complementary(of: color.rgba)])
            TVHarmonyRow(title: String(localized: "Analogous"), colors: ColorHarmony.analogous(of: color.rgba))
            TVHarmonyRow(title: String(localized: "Triadic"), colors: ColorHarmony.triadic(of: color.rgba))
            TVHarmonyRow(title: String(localized: "Split Complementary"), colors: ColorHarmony.splitComplementary(of: color.rgba))
            TVHarmonyRow(title: String(localized: "Tetradic"), colors: ColorHarmony.tetradic(of: color.rgba))
        }
    }

    @ContentBuilder
    private func notes(for color: OpaliteColor) -> some View {
        if let notes = color.notes, !notes.isEmpty {
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
        }
    }

    private func provenance(for color: OpaliteColor) -> some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            Text("Details")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: Brand.Space.md) {
                if let author = color.createdByDisplayName, !author.isEmpty {
                    LabeledContent("Created by", value: author)
                }
                LabeledContent("Created", value: color.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Updated", value: color.updatedAt.formatted(date: .abbreviated, time: .omitted))
                if let device = color.createdOnDeviceName, !device.isEmpty {
                    LabeledContent("Created on", value: device)
                }
                if let palette = color.palette {
                    LabeledContent("Palette", value: palette.name)
                }
            }
            .font(.callout)
            .padding(Brand.Space.xl)
            .adaptiveGlass(cornerRadius: Brand.Radius.card)
            .tvFocusStop()
        }
    }

    // MARK: - Formatting

    private func hsvString(_ hsv: HSV) -> String {
        "hsv(\(Int(hsv.hue.rounded())), \(Int((hsv.saturation * 100).rounded()))%, \(Int((hsv.value * 100).rounded()))%)"
    }

    private func cmykString(_ cmyk: CMYK) -> String {
        "cmyk(\(Int((cmyk.cyan * 100).rounded()))%, \(Int((cmyk.magenta * 100).rounded()))%, \(Int((cmyk.yellow * 100).rounded()))%, \(Int((cmyk.key * 100).rounded()))%)"
    }
}

#if DEBUG
#Preview {
    let environment = PreviewEnvironment()
    let id = environment.portfolio.colors.first!.id
    return NavigationStack {
        TVColorDetailView(colorID: id)
    }
    .previewEnvironment(environment)
}
#endif
#endif

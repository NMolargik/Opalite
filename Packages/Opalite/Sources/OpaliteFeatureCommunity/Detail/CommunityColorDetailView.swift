//
//  CommunityColorDetailView.swift
//  OpaliteFeatureCommunity
//
//  A published color: a full-bleed hero swatch under the glass bar, info tiles, the
//  color codes with copy, the publisher row, and notes. Save to Portfolio is the one
//  prominent action; Report (or Remove, for the user's own color) lives in the More menu.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureSharing

public struct CommunityColorDetailView: View {
    let color: CommunityColor

    @Environment(CommunityModel.self) private var community
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue
    @ScaledMetric(relativeTo: .largeTitle) private var heroHeight: CGFloat = 260

    @State private var isShowingReportSheet = false
    @State private var isConfirmingRemoval = false
    @State private var isValuesExpanded = true
    @State private var isPublisherExpanded = true

    public init(color: CommunityColor) {
        self.color = color
    }

    private var mode: ColorBlindnessMode { ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off }
    private var simulated: RGBA { ColorBlindnessSimulator.simulate(color.rgba, mode: mode) }
    private var isMine: Bool { community.isMine(color) }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(spacing: Brand.Space.lg) {
                    tiles
                    valuesCard
                    publisherCard
                    if let notes = color.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        CommunityNotesCard(notes: notes)
                    }
                    CommunitySaveButton(isEnabled: true) {
                        community.save(color, into: portfolio, router: router)
                    }
                    .padding(.top, Brand.Space.sm)
                }
                .padding(.horizontal, Brand.Space.lg)
                .padding(.top, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xxl)
                .communityDetailWidth()
            }
        }
        .background(groupedBackground)
        .softScrollEdgesIfAvailable()
        .navigationTitle(color.displayName)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportItemSheet(id: color.id, type: .color)
        }
        .confirmationDialog("Remove this color from the Community?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task {
                    await community.unpublish(color)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will no longer appear for anyone. Your copy in your Portfolio is unaffected.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            if color.alpha < 1 {
                Checkerboard(squareSize: 12)
            }
            Rectangle().fill(simulated.color)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text(color.displayName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(color.hexString)
                    .font(.subheadline.monospaced())
            }
            .foregroundStyle(simulated.idealTextColor)
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                    .fill((simulated.prefersDarkText ? Color.white : Color.black).opacity(0.22))
            )
            .padding(Brand.Space.lg)
            .frame(maxWidth: Brand.detailMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Color preview, \(color.displayName), \(color.hexString)"))
    }

    // MARK: - Tiles

    private var tiles: some View {
        CommunityInfoTileStrip(tiles: [
            .init(id: "publisher", title: String(localized: "Publisher"), value: color.publisherName, systemImage: "person.fill", tint: .opalitePurple),
            .init(id: "device", title: String(localized: "Created On"), value: CommunityDeviceLabel.short(color.createdOnDeviceName), systemImage: DeviceKind.from(color.createdOnDeviceName).systemImage, tint: .opaliteBlue),
            .init(id: "published", title: String(localized: "Published"), value: color.publishedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar", tint: .opaliteTan),
        ])
    }

    // MARK: - Cards

    private var valuesCard: some View {
        SectionCard(String(localized: "Values"), systemImage: "number", isExpanded: $isValuesExpanded) {
            VStack(spacing: Brand.Space.xs) {
                DetailRow(String(localized: "Hex"), value: hexCopy.formatted(color.hexString), systemImage: "number", monospaced: true) {
                    hexCopy.copy(hex: color.hexString)
                }
                Divider()
                DetailRow(String(localized: "RGB"), value: color.rgbString, systemImage: "slider.horizontal.3", monospaced: true) {
                    hexCopy.copy(text: color.rgbString, label: String(localized: "RGB"))
                }
                Divider()
                DetailRow(String(localized: "HSL"), value: color.hslString, systemImage: "circle.lefthalf.filled", monospaced: true) {
                    hexCopy.copy(text: color.hslString, label: String(localized: "HSL"))
                }
                if color.alpha < 1 {
                    Divider()
                    DetailRow(String(localized: "Opacity"), value: color.alpha.formatted(.percent.precision(.fractionLength(0))), systemImage: "circle.dotted", monospaced: true)
                }
            }
        }
    }

    private var publisherCard: some View {
        SectionCard(String(localized: "Publisher"), systemImage: "person", isExpanded: $isPublisherExpanded) {
            CommunityPublisherRow(id: color.publisherUserRecordID, displayName: color.publisherName, isMine: isMine)
        }
    }

    // MARK: - Toolbar

    private var moreMenu: some View {
        Menu {
            CommunityColorMenuItems(color: color, includesViewPublisher: true, onUnpublish: { isConfirmingRemoval = true }) {
                isShowingReportSheet = true
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .toolbarButtonTint()
        .accessibilityLabel(Text("More actions"))
        .accessibilityIdentifier("community.moreMenu")
    }
}

#if DEBUG
#Preview("Color detail") {
    NavigationStack {
        CommunityColorDetailView(color: .sample)
            .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
    }
    .previewEnvironment()
}

#Preview("Someone else's, no Onyx") {
    NavigationStack {
        CommunityColorDetailView(color: .sample2)
    }
    .previewEnvironment(hasOnyx: false)
}
#endif
#endif

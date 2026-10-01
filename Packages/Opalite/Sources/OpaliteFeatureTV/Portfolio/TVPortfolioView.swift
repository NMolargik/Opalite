//
//  TVPortfolioView.swift
//  OpaliteFeatureTV
//
//  The Portfolio tab: loose colors on a shelf, then one shelf per palette. Owns the
//  tab's navigation stack and honors color/palette deep links.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVPortfolioView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router

    @State private var path: [PortfolioDestination] = []
    @State private var isAddingColor = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 56) {
                    header

                    if portfolio.isEmpty {
                        emptyState
                    } else {
                        if !portfolio.looseColors.isEmpty {
                            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                                TVSectionHeader(title: "Colors", subtitle: "\(portfolio.looseColors.count)")
                                TVSwatchRow(colors: portfolio.looseColors)
                            }
                        }
                        if !portfolio.orderedPalettes.isEmpty {
                            VStack(alignment: .leading, spacing: Brand.Space.xl) {
                                TVSectionHeader(title: "Palettes", subtitle: "\(portfolio.orderedPalettes.count)")
                                ForEach(portfolio.orderedPalettes) { palette in
                                    TVPaletteRow(palette: palette)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, Brand.Space.xxl)
            }
            .navigationDestination(for: PortfolioDestination.self) { destination in
                TVDestinationView(destination: destination)
            }
            .sheet(isPresented: $isAddingColor) {
                TVQuickAddHexSheet()
            }
            .onAppear(perform: consumeDeepLink)
            .onChange(of: router.pendingDeepLink) { consumeDeepLink() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Brand.Space.xs) {
                Text("Portfolio")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button("Add Color", systemImage: "plus") {
                isAddingColor = true
            }
            .accessibilityHint(Text("Adds a color by typing its hex code"))
            .accessibilityIdentifier("addColor")
        }
        .padding(.horizontal, TVLayout.gutter)
        .focusSection()
    }

    private var summary: String {
        let colors = portfolio.colors.count
        let palettes = portfolio.activePalettes.count
        return String(localized: "\(colors) colors · \(palettes) palettes")
    }

    private var emptyState: some View {
        EmptyStateView(
            "No Colors Yet",
            systemImage: "paintpalette",
            description: String(localized: "Create colors on your iPhone, iPad, or Mac and they'll sync here with iCloud — or add one by hex code now.")
        ) {
            Button("Add a Color", systemImage: "plus") { isAddingColor = true }
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Deep links

    private func consumeDeepLink() {
        guard let link = router.pendingDeepLink else { return }
        switch link {
        case .color(let id):
            _ = router.takePendingDeepLink()
            router.selectedTab = .portfolio
            path = [.color(id)]
        case .palette(let id):
            _ = router.takePendingDeepLink()
            router.selectedTab = .portfolio
            path = [.palette(id)]
        case .createColor:
            _ = router.takePendingDeepLink()
            router.selectedTab = .portfolio
            isAddingColor = true
        default:
            break
        }
    }
}

#if DEBUG
#Preview("Seeded") {
    TVPortfolioView()
        .previewEnvironment()
}

#Preview("Empty") {
    TVPortfolioView()
        .previewEnvironment(seeded: false)
}
#endif
#endif

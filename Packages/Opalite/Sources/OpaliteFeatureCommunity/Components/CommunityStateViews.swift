//
//  CommunityStateViews.swift
//  OpaliteFeatureCommunity
//
//  The non-content states of the feed — offline, signed out, failed, empty, no results —
//  each with the one action that fixes it.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct CommunityStateView: View {
    let status: CommunityFeedStatus
    let segment: CommunitySegment
    let searchText: String
    let onRetry: () async -> Void
    let onGoToPortfolio: () -> Void

    @State private var isRetrying = false

    var body: some View {
        Group {
            switch status {
            case .offline:
                EmptyStateView("You're Offline", systemImage: "wifi.slash", description: String(localized: "Connect to the internet to browse colors and palettes shared by the community.")) {
                    retryButton("Try Again")
                }
            case .signedOut:
                EmptyStateView("Sign in to iCloud", systemImage: "icloud.slash", description: String(localized: "The Community uses your iCloud account to browse and share. Sign in under Settings › Apple Account, then come back.")) {
                    retryButton("Check Again")
                }
            case .failed:
                EmptyStateView("Couldn't Load the Community", systemImage: "exclamationmark.icloud", description: String(localized: "Something went wrong while loading. Pull down or try again.")) {
                    retryButton("Try Again")
                }
            case .noResults:
                EmptyStateView("No Results", systemImage: "magnifyingglass", description: String(localized: "Nothing matches “\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))”. Try a name, a hex code, or a color family like “teal”."))
            case .empty:
                switch segment {
                case .colors:
                    EmptyStateView("No Colors Yet", systemImage: "paintpalette", description: String(localized: "The community hasn't shared any colors yet. Publish one from your Portfolio and be the first.")) {
                        portfolioButton
                    }
                case .palettes:
                    EmptyStateView("No Palettes Yet", systemImage: "swatchpalette", description: String(localized: "The community hasn't shared any palettes yet. Publish one from your Portfolio and be the first.")) {
                        portfolioButton
                    }
                }
            case .loading, .content:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Brand.Space.xxl)
    }

    private func retryButton(_ title: LocalizedStringKey) -> some View {
        Button {
            Haptics.selection()
            Task {
                isRetrying = true
                await onRetry()
                isRetrying = false
            }
        } label: {
            Label(title, systemImage: "arrow.clockwise")
                .symbolEffect(.rotate, value: isRetrying)
        }
        .glassActionButton(tint: .opalitePurple, prominent: true)
        .disabled(isRetrying)
        .accessibilityIdentifier("community.retryButton")
    }

    private var portfolioButton: some View {
        Button {
            Haptics.selection()
            onGoToPortfolio()
        } label: {
            Label("Open Portfolio", systemImage: "square.grid.2x2")
        }
        .glassActionButton(tint: .opalitePurple, prominent: true)
        .accessibilityIdentifier("community.openPortfolioButton")
    }
}

#if DEBUG
#Preview("Offline") {
    CommunityStateView(status: .offline, segment: .colors, searchText: "", onRetry: {}, onGoToPortfolio: {})
}

#Preview("Empty palettes") {
    CommunityStateView(status: .empty, segment: .palettes, searchText: "", onRetry: {}, onGoToPortfolio: {})
}

#Preview("No results") {
    CommunityStateView(status: .noResults, segment: .colors, searchText: "mauve", onRetry: {}, onGoToPortfolio: {})
}
#endif
#endif

//
//  TVSwatchCard.swift
//  OpaliteFeatureTV
//
//  The focusable swatch: a large unadorned color that lifts with the tvOS card style, its
//  name and hex resting beneath. Select opens the color; long-press offers full screen.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVSwatchCard: View {
    let color: OpaliteColor
    var side: CGFloat = TVLayout.cardSide

    @Environment(HexCopyModel.self) private var hexCopy
    @State private var presentation: TVPresentationRequest?

    var body: some View {
        VStack(spacing: Brand.Space.md) {
            NavigationLink(value: PortfolioDestination.color(color.id)) {
                TVSwatchFill(color.rgba)
                    .frame(width: side, height: side)
            }
            .buttonStyle(.card)
            .contextMenu {
                Button("Show Full Screen", systemImage: "tv") {
                    presentation = TVPresentationRequest(colors: [color])
                }
            }
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityHint(Text("Opens color details. Long press to show full screen."))
            .accessibilityIdentifier("swatch-\(color.id.uuidString)")

            VStack(spacing: 2) {
                Text(color.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(hexCopy.formatted(color))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(width: side)
            .accessibilityHidden(true)
        }
        .fullScreenCover(item: $presentation) { request in
            TVPresentationView(request: request)
        }
    }

    private var accessibilityLabel: String {
        color.hasName
            ? "\(color.displayName), \(color.hexString)"
            : String(localized: "Unnamed color, \(color.hexString)")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HStack(spacing: 48) {
            TVSwatchCard(color: .sample)
            TVSwatchCard(color: OpaliteColor(name: nil, red: 0.2, green: 0.7, blue: 0.9, alpha: 0.5))
        }
    }
    .previewEnvironment()
}
#endif
#endif

//
//  CanvasCard.swift
//  OpaliteFeatureCanvas
//
//  One canvas in the grid: a white-backed thumbnail, the title, "Edited … ago", the
//  linked palette, and the Onyx badge when the tier can't open it.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UIKit
import OpaliteCore
import OpaliteDesignSystem

struct CanvasCard: View {
    let canvas: CanvasFile
    let isLocked: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            thumbnailView
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
                    Text(canvas.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if isLocked { OnyxBadge(compact: true) }
                }
                Text("Edited \(canvas.updatedAt, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let palette = canvas.palette {
                    Label(palette.name, systemImage: "link")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Brand.Space.xs)
        }
        .padding(Brand.Space.sm)
        .cardSurface()
        .opacity(isLocked ? 0.75 : 1)
        .task(id: canvas.thumbnailData?.count ?? 0) {
            thumbnail = canvas.thumbnailData.flatMap(UIImage.init(data:))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(isLocked ? Text("Requires Onyx. Opens the Onyx options.") : Text("Opens the canvas"))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts = [canvas.title, String(localized: "edited \(canvas.updatedAt.formatted(.relative(presentation: .named)))")]
        if let palette = canvas.palette { parts.append(String(localized: "linked to \(palette.name)")) }
        if isLocked { parts.append(String(localized: "locked")) }
        return parts.joined(separator: ", ")
    }

    private var thumbnailView: some View {
        ZStack {
            Color.white
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(Brand.Space.sm)
            } else {
                Image(systemName: "scribble.variable")
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(LinearGradient.opaliteHorizontal)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
        .environment(\.colorScheme, .light)
    }
}
#endif

//
//  TVSwatchView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// A focusable color swatch optimized for tvOS Siri Remote navigation.
/// Long-press to show context menu with presentation option.
struct TVSwatchView: View {
    let color: OpaliteColor
    let size: SwatchSize

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var showPresentation: Bool = false

    private var swatchSize: CGFloat {
        // tvOS needs larger sizes for visibility at TV viewing distance
        switch size {
        case .extraSmall: return 80
        case .small: return 120
        case .medium: return 180
        case .large: return 280
        }
    }

    var body: some View {
        NavigationLink(destination: TVColorDetailView(color: color)) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.swiftUIColor)
                    .frame(width: swatchSize, height: swatchSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isFocused ? Color.white : Color.clear,
                                lineWidth: isFocused ? 4 : 0
                            )
                    )
                    .shadow(
                        color: isFocused ? color.swiftUIColor.opacity(0.6) : .clear,
                        radius: isFocused ? 20 : 0
                    )

                if size.showOverlays {
                    // Show name if it exists, otherwise hex - single line for consistent sizing
                    Text(color.name?.isEmpty == false ? color.name! : color.hexString)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .frame(width: swatchSize)
                        .opacity(isFocused ? 1 : 0.7)
                }
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(color.name?.isEmpty == false ? color.name! : "Color") \(color.hexString)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens color details. Long press for more options.")
        .contextMenu {
            Button {
                showPresentation = true
            } label: {
                Label("Present on TV", systemImage: "tv")
            }
            .accessibilityLabel("Present \(color.name ?? color.hexString) on TV")
            .accessibilityHint("Displays the color full screen")

            Button {
                // Navigation happens via the NavigationLink
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
            .accessibilityLabel("View details for \(color.name ?? color.hexString)")
        }
        .fullScreenCover(isPresented: $showPresentation) {
            NavigationStack {
                TVPresentationModeView(colors: [color], startIndex: 0)
            }
        }
    }
}

#Preview {
    TVSwatchView(color: OpaliteColor.sample, size: .medium)
}

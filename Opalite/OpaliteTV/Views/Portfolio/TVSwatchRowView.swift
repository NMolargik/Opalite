//
//  TVSwatchRowView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Horizontal scrolling row of color swatches for tvOS.
/// Optimized for Siri Remote navigation with focus-aware scrolling.
struct TVSwatchRowView: View {
    let colors: [OpaliteColor]
    let swatchSize: SwatchSize

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 40) {
                ForEach(colors) { color in
                    TVSwatchView(color: color, size: swatchSize)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
        }
        .focusSection()
    }
}

#Preview {
    TVSwatchRowView(
        colors: [OpaliteColor.sample, OpaliteColor.sample2],
        swatchSize: .medium
    )
}

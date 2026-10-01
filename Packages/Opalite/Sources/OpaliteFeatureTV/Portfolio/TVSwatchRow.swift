//
//  TVSwatchRow.swift
//  OpaliteFeatureTV
//
//  A shelf of swatches: horizontal, lazy, unclipped so the focus lift can overflow.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVSwatchRow: View {
    let colors: [OpaliteColor]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 48) {
                ForEach(colors) { color in
                    TVSwatchCard(color: color)
                }
            }
            .padding(.horizontal, TVLayout.gutter)
            .padding(.vertical, Brand.Space.xxl)
        }
        .scrollClipDisabled()
        .focusSection()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TVSwatchRow(colors: OpaliteColor.samples)
    }
    .previewEnvironment()
}
#endif
#endif

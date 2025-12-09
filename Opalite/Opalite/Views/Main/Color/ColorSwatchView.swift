//
//  ColorSwatchView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

struct ColorSwatchView: View {
    let color: Color
    let onTap: () -> Void

    init(color: Color, onTap: @escaping () -> Void = {}) {
        self.color = color
        self.onTap = onTap
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.secondary.opacity(0.3))
            )
            .onTapGesture(perform: onTap)
    }
}

#Preview {
    ColorSwatchView(color: .blue) {}
        .padding()
}

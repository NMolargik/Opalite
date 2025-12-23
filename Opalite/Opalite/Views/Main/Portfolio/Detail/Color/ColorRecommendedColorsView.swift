//
//  ColorRecommendedColorsView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct ColorRecommendedColorsView: View {
    let baseColor: OpaliteColor
    let onCreateColor: (OpaliteColor) -> Void

    var body: some View {
        SectionCard(title: "Recommended Colors", systemImage: "paintpalette") {
            let recommended = buildRecommendedColors()
            SwatchRowView(
                colors: recommended,
                palette: nil,
                swatchWidth: 180,
                swatchHeight: 150,
                showOverlays: true,
                showsNavigation: false,
                menuContent: { color in
                    AnyView(
                        Group {
                            Button {
                                HapticsManager.shared.selection()
                                copyHex(for: color)
                            } label: {
                                Label("Copy Hex", systemImage: "number")
                            }
                            
                            Button {
                                HapticsManager.shared.selection()
                                onCreateColor(color)
                            } label: {
                                let addSuffix: String = (baseColor.palette != nil) ? "To Palette" : "To Colors"
                                Label("Add \(addSuffix)", systemImage: "plus")
                            }
                        }
                    )
                }
            )
        }
    }

    private func buildRecommendedColors() -> [OpaliteColor] {
        let complementRaw = baseColor.complementaryColor()
        let harmonyRaw = baseColor.harmoniousColors()

        var recommended: [OpaliteColor] = [
            OpaliteColor(
                name: "Complementary",
                red: complementRaw.red,
                green: complementRaw.green,
                blue: complementRaw.blue,
                alpha: complementRaw.alpha
            )
        ]

        if harmonyRaw.indices.contains(0) {
            recommended.append(
                OpaliteColor(
                    name: "Harmonious",
                    red: harmonyRaw[0].red,
                    green: harmonyRaw[0].green,
                    blue: harmonyRaw[0].blue,
                    alpha: harmonyRaw[0].alpha
                )
            )
        }

        if harmonyRaw.indices.contains(1) {
            recommended.append(
                OpaliteColor(
                    name: "Harmonious",
                    red: harmonyRaw[1].red,
                    green: harmonyRaw[1].green,
                    blue: harmonyRaw[1].blue,
                    alpha: harmonyRaw[1].alpha
                )
            )
        }

        return recommended
    }
}

#Preview("Recommended Colors") {
    ColorRecommendedColorsView(
        baseColor: OpaliteColor(
            name: "Base Color",
            red: 0.5,
            green: 0.3,
            blue: 0.7,
            alpha: 1.0
        ),
        onCreateColor: { _ in }
    )
    .padding()
}

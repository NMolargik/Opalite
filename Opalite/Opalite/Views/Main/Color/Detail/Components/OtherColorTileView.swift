//
//  OtherColorTileView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OtherColorTileView: View {
    let color: OpaliteColor
    let badge: String?
    
    let saveColor: () -> Void
    let saveToPalette: () -> Void

    private var title: String {
        if let name = color.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return color.hexString
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(color.swiftUIColor)
            .frame(width: 130, height: 130)
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThickMaterial, in: Capsule())
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    Button("Save To Palette") {
                        saveToPalette()
                    }
                    Button("Save Color") {
                        saveColor()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(Color.inverseTheme)
                        .padding(4)
                        .background(.ultraThickMaterial, in: Circle())
                        .padding(8)
                }
            }
            .onDrag {
                dragItemProvider()
            }
    }

    private func dragItemProvider() -> NSItemProvider {
    #if os(iOS) || os(visionOS)
        let exportView = Rectangle()
            .fill(color.swiftUIColor)
            .frame(width: 512, height: 512)

        let renderer = ImageRenderer(content: exportView)

        #if canImport(UIKit)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            return NSItemProvider(object: image)
        }
        #endif

        return NSItemProvider()
    #else
        return NSItemProvider()
    #endif
    }
}

#Preview {
    OtherColorTileView(
        color: OpaliteColor.sample,
        badge: "Complimentary",
        saveColor: {},
        saveToPalette: {}
    )
}

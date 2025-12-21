//
//  ImagePreviewView.swift
//  Opalite
//
//  Created by Claude on 12/20/25.
//

import SwiftUI

struct ImagePreviewView: View {
    let image: UIImage
    var scale: CGFloat = 1.0

    private let baseMaxDimension: CGFloat = 200

    private var displaySize: CGSize {
        let maxDimension = baseMaxDimension * scale
        let aspectRatio = image.size.width / image.size.height

        if aspectRatio > 1 {
            // Landscape
            return CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square
            return CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: displaySize.width, height: displaySize.height)
            .opacity(0.7)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 3])
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        ImagePreviewView(
            image: UIImage(systemName: "photo")!,
            scale: 1.0
        )
    }
}

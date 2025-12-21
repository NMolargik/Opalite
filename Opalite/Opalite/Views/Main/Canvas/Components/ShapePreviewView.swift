//
//  ShapePreviewView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct ShapePreviewView: View {
    let shape: CanvasShape
    private let size: CGFloat = 100

    var body: some View {
        Group {
            switch shape {
            case .square:
                Rectangle()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size)

            case .circle:
                Circle()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size)

            case .triangle:
                TriangleShape()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size * 0.866)

            case .line:
                Rectangle()
                    .fill(.black)
                    .frame(width: size, height: 2)

            case .arrow:
                ArrowShape()
                    .stroke(.black, lineWidth: 2)
                    .frame(width: size, height: size * 0.5)
            }
        }
        .opacity(0.6)
    }
}

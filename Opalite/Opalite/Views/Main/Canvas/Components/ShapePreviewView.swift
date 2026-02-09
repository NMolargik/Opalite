//
//  ShapePreviewView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct ShapePreviewView: View {
    let shape: CanvasShape
    var scale: CGFloat = 1.0
    /// Aspect ratio (width/height) for shapes that support non-uniform scaling
    var aspectRatio: CGFloat = 1.0
    /// Explicit width override (used by drag-to-define). When set, `scale` is ignored.
    var explicitWidth: CGFloat?
    /// Explicit height override (used by drag-to-define). When set, `scale` is ignored.
    var explicitHeight: CGFloat?

    private let baseSize: CGFloat = 100

    private var size: CGFloat {
        baseSize * scale
    }

    /// Width for rectangle (uses aspect ratio)
    private var rectWidth: CGFloat {
        size * aspectRatio
    }

    var body: some View {
        Group {
            if let w = explicitWidth, let h = explicitHeight {
                explicitSizeBody(width: w, height: h)
            } else {
                scaledBody
            }
        }
        .opacity(0.6)
    }

    /// Body using explicit width/height (drag-to-define mode)
    @ViewBuilder
    private func explicitSizeBody(width w: CGFloat, height h: CGFloat) -> some View {
        switch shape {
        case .square:
            Rectangle()
                .stroke(.black, lineWidth: 2)
                .frame(width: w, height: h)

        case .rectangle:
            Rectangle()
                .stroke(.black, lineWidth: 2)
                .frame(width: w, height: h)

        case .circle:
            Ellipse()
                .stroke(.black, lineWidth: 2)
                .frame(width: w, height: h)

        case .triangle:
            TriangleShape()
                .stroke(.black, lineWidth: 2)
                .frame(width: w, height: h)

        case .line:
            Rectangle()
                .fill(.black)
                .frame(width: w, height: 2)

        case .arrow:
            ArrowShape()
                .stroke(.black, lineWidth: 2)
                .frame(width: w, height: h)

        case .shirt:
            ShirtShape()
                .stroke(.black, lineWidth: 2)
                .frame(width: w, height: h)
        }
    }

    /// Body using scale-based sizing (legacy/SVG mode)
    @ViewBuilder
    private var scaledBody: some View {
        switch shape {
        case .square:
            Rectangle()
                .stroke(.black, lineWidth: 2)
                .frame(width: size, height: size)

        case .rectangle:
            Rectangle()
                .stroke(.black, lineWidth: 2)
                .frame(width: rectWidth, height: size)

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

        case .shirt:
            ShirtShape()
                .stroke(.black, lineWidth: 2)
                .frame(width: size * 1.26, height: size)
        }
    }
}

// MARK: - Shirt Shape

/// A t-shirt shape for canvas preview
struct ShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Original SVG: 1260x1000, normalized to rect
        let scaleX = rect.width / 1260
        let scaleY = rect.height / 1000

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        // M 305,4
        path.move(to: point(305, 4))

        // L 5,351 219,496 308,394
        path.addLine(to: point(5, 351))
        path.addLine(to: point(219, 496))
        path.addLine(to: point(308, 394))

        // V 996
        path.addLine(to: point(308, 996))

        // H 953
        path.addLine(to: point(953, 996))

        // V 394
        path.addLine(to: point(953, 394))

        // L 1041,496 1255,351 956,4
        path.addLine(to: point(1041, 496))
        path.addLine(to: point(1255, 351))
        path.addLine(to: point(956, 4))

        // H 850
        path.addLine(to: point(850, 4))

        // A 248,248 0 0 1 630,151 - Arc for right neckline
        // Mirror the left neckline's cubic bezier for symmetry
        path.addCurve(
            to: point(630, 151),
            control1: point(807, 92),
            control2: point(725, 151)
        )

        // C 535,151 453,92 410,4 - Cubic bezier for left neckline
        path.addCurve(
            to: point(410, 4),
            control1: point(535, 151),
            control2: point(453, 92)
        )

        // Z - Close path
        path.closeSubpath()

        return path
    }
}

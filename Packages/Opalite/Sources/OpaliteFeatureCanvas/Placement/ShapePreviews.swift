//
//  ShapePreviews.swift
//  OpaliteFeatureCanvas
//
//  The SwiftUI outlines shown while a shape is being placed (and the ghost on hover):
//  built-in shapes draw from `Shape` types; imported SVGs draw their paths fitted to the
//  preview box. Previews mirror `CanvasShapeGeometry`, so what you see is what's inked.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore

struct ShapePreviewView: View {
    let subject: PlacementSubject
    let width: CGFloat
    let height: CGFloat
    var lineWidth: CGFloat = 2
    var tint: Color = .black
    var dashed = false

    var body: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: dashed ? [6, 6] : [])
        Group {
            switch subject {
            case .shape(let shape):
                outline(for: shape).stroke(tint, style: style)
            case .svg(let paths, let bounds, _):
                SVGOutlineShape(paths: paths, svgBounds: bounds).stroke(tint, style: style)
            }
        }
        .frame(width: max(width, 1), height: max(height, 1))
        .accessibilityHidden(true)
    }

    private func outline(for shape: CanvasShape) -> AnyShape {
        switch shape {
        case .square, .rectangle: AnyShape(Rectangle())
        case .circle: AnyShape(Ellipse())
        case .triangle: AnyShape(TriangleShape())
        case .line: AnyShape(LineShape())
        case .arrow: AnyShape(ArrowShape())
        case .shirt: AnyShape(ShirtShape())
        }
    }
}

// MARK: - Shapes

nonisolated struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

nonisolated struct LineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

nonisolated struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let head = min(rect.width * 0.25, rect.height / 2)
        let tip = CGPoint(x: rect.maxX, y: rect.midY)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: tip)
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - head, y: rect.midY - head))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - head, y: rect.midY + head))
        return path
    }
}

nonisolated struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer / 2
        var path = Path()
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The t-shirt outline, scaled from the same path data the ink uses.
nonisolated struct ShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard let path = SVGPathParser().parsePathData(CanvasShapeGeometry.shirtPathData) else { return Path() }
        let native = CanvasShapeGeometry.shirtNativeSize
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / native.width, y: rect.height / native.height)
        return Path(path.copy(using: &transform) ?? path)
    }
}

/// Imported SVG paths fitted into the rect (non-uniform, matching the placement box).
nonisolated struct SVGOutlineShape: Shape {
    /// Immutable CGPaths are safe to share; `Shape` requires Sendable.
    let paths: UncheckedSendableBox<[CGPath]>
    let svgBounds: CGRect

    init(paths: [CGPath], svgBounds: CGRect) {
        self.paths = UncheckedSendableBox(value: paths)
        self.svgBounds = svgBounds
    }

    func path(in rect: CGRect) -> Path {
        guard svgBounds.width > 0, svgBounds.height > 0 else { return Path() }
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / svgBounds.width, y: rect.height / svgBounds.height)
            .translatedBy(x: -svgBounds.minX, y: -svgBounds.minY)
        var result = Path()
        for cgPath in paths.value {
            result.addPath(Path(cgPath.copy(using: &transform) ?? cgPath))
        }
        return result
    }
}
#endif

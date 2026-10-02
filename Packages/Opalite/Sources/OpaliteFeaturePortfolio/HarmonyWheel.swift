//
//  HarmonyWheel.swift
//  OpaliteFeaturePortfolio
//
//  The hue wheel with the current harmony drawn over it: the base color and its
//  harmony partners as dots joined by a line / triangle / quadrilateral. The overlay is
//  animatable, so switching harmonies glides the shape rather than snapping.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

/// Lines joining up to four points on the wheel; angles are degrees clockwise from the top.
nonisolated struct HarmonyOverlayShape: Shape {
    var angle0: Double
    var angle1: Double
    var angle2: Double
    var angle3: Double
    var pointCount: Int

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(angle0, angle1), AnimatablePair(angle2, angle3)) }
        set {
            angle0 = newValue.first.first
            angle1 = newValue.first.second
            angle2 = newValue.second.first
            angle3 = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angles = [angle0, angle1, angle2, angle3]
        var path = Path()
        for (index, angle) in angles.prefix(max(2, min(pointCount, 4))).enumerated() {
            let point = Self.point(on: radius, around: center, degrees: angle)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if pointCount > 2 { path.closeSubpath() }
        return path
    }

    static func point(on radius: CGFloat, around center: CGPoint, degrees: Double) -> CGPoint {
        let radians = (degrees - 90) * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y + radius * CGFloat(sin(radians)))
    }
}

/// The wheel itself with the dots and overlay for a base color and a harmony.
struct HarmonyWheel: View {
    let base: RGBA
    let kind: HarmonyKind
    var diameter: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var angles: [Double] { kind.paddedWheelAngles(baseHue: base.hsl.hue) }
    private var colors: [RGBA] { [base] + kind.colors(for: base) }
    private var ringWidth: CGFloat { diameter * 0.16 }
    private var dotRadius: CGFloat { diameter / 2 - ringWidth / 2 }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AngularGradient.hueWheel, lineWidth: ringWidth)
                .rotationEffect(.degrees(-90))
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                .padding(ringWidth)

            HarmonyOverlayShape(angle0: angles[0], angle1: angles[1], angle2: angles[2], angle3: angles[3], pointCount: kind.pointCount)
                .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .padding(ringWidth / 2)

            ForEach(Array(colors.enumerated()), id: \.offset) { index, rgba in
                Circle()
                    .fill(rgba.color)
                    .frame(width: index == 0 ? 30 : 24, height: index == 0 ? 30 : 24)
                    .overlay(Circle().strokeBorder(.white, lineWidth: index == 0 ? 3 : 2))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .offset(dotOffset(for: angles[min(index, 3)]))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : .snappy(duration: 0.45), value: kind)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(kind.title) harmony wheel"))
        .accessibilityValue(Text(colors.dropFirst().map(\.hexString).joined(separator: ", ")))
    }

    private func dotOffset(for degrees: Double) -> CGSize {
        let point = HarmonyOverlayShape.point(on: dotRadius, around: .zero, degrees: degrees)
        return CGSize(width: point.x, height: point.y)
    }
}

#if DEBUG
#Preview("Wheel") {
    VStack(spacing: 24) {
        HarmonyWheel(base: RGBA(red: 0.2, green: 0.5, blue: 0.8), kind: .triadic)
        HarmonyWheel(base: RGBA(red: 0.9, green: 0.4, blue: 0.2), kind: .tetradic, diameter: 160)
    }
    .padding()
}
#endif
#endif

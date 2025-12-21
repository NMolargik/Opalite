//
//  StarShape.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius / 2
        let pointCount = 5

        var path = Path()
        for i in 0..<(pointCount * 2) {
            let angle = (CGFloat(i) * .pi / CGFloat(pointCount)) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

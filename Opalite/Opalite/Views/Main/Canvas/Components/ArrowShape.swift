//
//  ArrowShape.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let arrowHeadSize = rect.width * 0.25

        // Main line
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))

        // Arrow head
        path.move(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: midY - arrowHeadSize))
        path.move(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - arrowHeadSize, y: midY + arrowHeadSize))

        return path
    }
}

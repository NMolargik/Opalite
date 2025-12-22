//
//  ColorDetailsSectionView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct ColorDetailsSectionView: View {
    let color: OpaliteColor

    var body: some View {
        SectionCard(title: "Details", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 16) {
                DetailRowView(icon: "person", title: "Created By", value: color.createdByDisplayName ?? "—")
                DetailRowView(icon: DeviceKind.from(color.createdOnDeviceName).symbolName, title: "Created On", value: color.createdOnDeviceName ?? "—")
                DetailRowView(icon: "calendar", title: "Created At", value: formatted(color.createdAt))

                Divider().opacity(0.25)

                DetailRowView(icon: "clock.arrow.circlepath", title: "Updated At", value: formatted(color.updatedAt))
                DetailRowView(icon: DeviceKind.from(color.updatedOnDeviceName).symbolName, title: "Updated On", value: color.updatedOnDeviceName ?? "—")
            }
            .padding([.horizontal, .bottom])
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview("Color Details") {
    ColorDetailsSectionView(
        color: OpaliteColor(
            name: "Sky Blue",
            red: 0.2,
            green: 0.6,
            blue: 0.9,
            alpha: 1.0
        )
    )
    .padding()
}

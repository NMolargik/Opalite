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
                DetailRow(icon: "person", title: "Created By", value: color.createdByDisplayName ?? "—")
                DetailRow(icon: deviceSymbol(for: color.createdOnDeviceName), title: "Created On", value: color.createdOnDeviceName ?? "—")
                DetailRow(icon: "calendar", title: "Created At", value: formatted(color.createdAt))

                Divider().opacity(0.25)

                DetailRow(icon: "clock.arrow.circlepath", title: "Updated At", value: formatted(color.updatedAt))
                DetailRow(icon: deviceSymbol(for: color.updatedOnDeviceName), title: "Updated On", value: color.updatedOnDeviceName ?? "—")
            }
            .padding([.horizontal, .bottom])
        }
    }

    private func deviceSymbol(for deviceName: String?) -> String {
        guard let deviceName, !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "ipad.and.iphone"
        }

        let name = deviceName.lowercased()

        // Apple Watch
        if name.contains("watch") {
            return "applewatch"
        }

        // Vision Pro
        if name.contains("vision") {
            return "vision.pro"
        }

        // iPhone / iPad
        if name.contains("iphone") {
            return "iphone"
        }
        if name.contains("ipad") {
            return "ipad"
        }

        // iMacs
        if name.contains("imac") {
            return "desktopcomputer"
        }

        // Macs
        if name.contains("mac studio") || name.contains("macstudio") {
            return "macstudio"
        }
        if name.contains("mac mini") || name.contains("macmini") {
            return "macmini"
        }
        if name.contains("mac pro") || name.contains("macpro") {
            return "macpro.gen3"
        }
        if name.contains("macbook") {
            return "macbook"
        }

        // Fallback
        return "ipad.and.iphone"
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private struct DetailRow: View {
        let icon: String
        let title: String
        let value: String

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.body)
                }

                Spacer(minLength: 0)
            }
        }
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

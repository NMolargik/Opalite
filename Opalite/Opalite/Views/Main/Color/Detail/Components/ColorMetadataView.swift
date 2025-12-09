//
//  ColorMetadataView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI

struct ColorMetadataView: View {
    @Binding var isExpanded: Bool
    let createdByText: String
    let createdOnDeviceText: String
    let createdAtText: String
    let updatedAtText: String
    let updatedOnDeviceText: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private func deviceSymbol(for text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("iphone") {
            return "iphone"
        }
        if lower.contains("ipad") {
            return "ipad"
        }
        // Mac Studio
        if lower.contains("studio") {
            return "macstudio"
        }
        // Mac mini
        if lower.contains("mini") {
            return "macmini.gen3"
        }
        // Mac Pro
        if lower.contains("pro"), lower.contains("mac"), !lower.contains("macbook") {
            return "macpro.gen3"
        }
        // MacBook (Air/Pro)
        if lower.contains("macbook") {
            return "macbook"
        }
        // iMac
        if lower.contains("imac") {
            return "desktopcomputer"
        }
        if lower.contains("watch") {
            return "applewatch"
        }
        if lower.contains("vision") {
            return "visionpro"
        }

        return "desktopcomputer" // fallback
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRowView(label: "Created By", systemImage: "person.fill", value: createdByText)
                        DetailRowView(label: "Created On", systemImage: deviceSymbol(for: createdOnDeviceText), value: createdOnDeviceText)
                        DetailRowView(label: "Created At", systemImage: "calendar", value: createdAtText)

                        Divider().padding(.vertical, 4)

                        DetailRowView(label: "Updated At", systemImage: "clock.arrow.circlepath", value: updatedAtText)
                        DetailRowView(label: "Updated On", systemImage: deviceSymbol(for: updatedOnDeviceText), value: updatedOnDeviceText)
                    }
                } label: {
                    SectionHeaderView(title: "Details", systemImage: "info.circle")
                        .foregroundStyle(Color.inverseTheme)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeaderView(title: "Details", systemImage: "info.circle")

                    DetailRowView(label: "Created By", systemImage: "person", value: createdByText)
                    DetailRowView(label: "Created On", systemImage: deviceSymbol(for: createdOnDeviceText), value: createdOnDeviceText)
                    DetailRowView(label: "Created At", systemImage: "calendar", value: createdAtText)

                    Divider().padding(.vertical, 4)

                    DetailRowView(label: "Updated At", systemImage: "clock.arrow.circlepath", value: updatedAtText)
                    DetailRowView(label: "Updated On", systemImage: deviceSymbol(for: updatedOnDeviceText), value: updatedOnDeviceText)
                }
            }
        }
        .padding(16)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }
}

#Preview {
    ColorMetadataView(
        isExpanded: .constant(true),
        createdByText: "Nick Molargik",
        createdOnDeviceText: "iPhone 17 Pro",
        createdAtText: Date.now.description,
        updatedAtText: Date.now.description,
        updatedOnDeviceText: "Mac Studio"
    )
}

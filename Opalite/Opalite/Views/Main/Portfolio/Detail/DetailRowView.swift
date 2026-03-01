//
//  DetailRowView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import SwiftUI

struct DetailRowView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}
#Preview("DetailRowView") {
    VStack(alignment: .leading, spacing: 12) {
        DetailRowView(icon: "info.circle", title: "Title", value: "Some value")
        DetailRowView(icon: "clock", title: "Updated", value: "Today, 2:14 PM")
        DetailRowView(icon: "person", title: "Owner", value: "Nick Molargik")
    }
    .padding()
}

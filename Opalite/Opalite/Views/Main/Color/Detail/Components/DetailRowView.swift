//
//  DetailRowView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI

struct DetailRowView: View {
    let label: String
    let systemImage: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
#Preview {
    DetailRowView(
        label: "Label",
        systemImage: "house.fill",
        value: "Value"
    )
}

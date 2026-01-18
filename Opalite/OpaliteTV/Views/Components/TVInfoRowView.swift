//
//  TVInfoRowView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// A simple label-value row for displaying information on tvOS.
struct TVInfoRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(value)
                .font(.body)
                .fontWeight(.medium)

            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TVInfoRowView(label: "Hex", value: "#3380CC")
        TVInfoRowView(label: "RGB", value: "rgb(51, 128, 204)")
        TVInfoRowView(label: "Created By", value: "Nick")
    }
    .padding()
}

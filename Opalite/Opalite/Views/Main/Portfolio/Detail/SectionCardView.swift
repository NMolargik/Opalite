//
//  SectionCardView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .bold()
                Spacer(minLength: 0)
            }
            .padding(16)

            content
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview("Section Card") {
    SectionCard(title: "Details", systemImage: "info.circle") {
        VStack(alignment: .leading, spacing: 8) {
            Text("This is example content inside the card.")
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                Text("Status: Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Primary Action") {}
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
    }
    .padding()
}

#Preview("Section Card – Dark") {
    SectionCard(title: "Details", systemImage: "info.circle") {
        VStack(alignment: .leading, spacing: 8) {
            Text("This is example content inside the card.")
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
                Text("Status: Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Primary Action") {}
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
    }
    .padding()
    .preferredColorScheme(.dark)
}

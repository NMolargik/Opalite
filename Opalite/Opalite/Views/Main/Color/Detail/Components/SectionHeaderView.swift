//
//  SectionHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/9/25.
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.bottom, 4)
    }
}


#Preview {
    SectionHeaderView(
        title: "Title",
        systemImage: "house.fill"
    )
}

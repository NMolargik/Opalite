//
//  ColorRowView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

struct ColorRowView: View {
    let color: OpaliteColor

    var body: some View {
        HStack(spacing: 15) {
            Rectangle()
                .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                .frame(width: 30, height: 30)
                .cornerRadius(5)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(color.name ?? "Untitled Color")
                        .font(.headline)
                    
                    if color.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                if let notes = color.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ColorRowView(color: OpaliteColor.sample2)
}

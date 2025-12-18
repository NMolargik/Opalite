//
//  NotesSectionView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct NotesSectionView: View {
    @Binding var notes: String
    @Binding var isSaving: Bool
    let onSave: () -> Void
    @State private var originalNotes: String = ""

    var body: some View {
        SectionCard(title: "Notes", systemImage: "note.text") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $notes)
                    .frame(minHeight: 160)
                    .onAppear { originalNotes = notes }

                let isDirty = notes.trimmingCharacters(in: .whitespacesAndNewlines) != originalNotes.trimmingCharacters(in: .whitespacesAndNewlines)

                HStack {
                    Spacer()

                    Button {
                        onSave()
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                            }
                            Text("Save")
                                .bold()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .glassEffect(.clear.tint(.blue).interactive())
                    }
                    .disabled(isSaving || !isDirty)
                    .opacity((isSaving || !isDirty) ? 0.6 : 1.0)
                }
            }
            .padding([.horizontal, .bottom])
        }
    }
}


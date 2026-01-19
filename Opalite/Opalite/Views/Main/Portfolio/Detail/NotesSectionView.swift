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
    @State private var debounceTask: Task<Void, Never>?
    @State private var lastSavedAt: Date?

    var body: some View {
        SectionCard(title: "Notes", systemImage: "note.text") {
            VStack(alignment: .leading, spacing: 10) {

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $notes)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        )

                    if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add any notes for this color…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .onAppear {
                originalNotes = notes
            }
            .onDisappear {
                debounceTask?.cancel()
                debounceTask = nil
            }
            .onChange(of: notes) { _, _ in
                scheduleAutosaveIfNeeded()
            }
            .onChange(of: isSaving) { _, newValue in
                if newValue == false {
                    // When a save finishes, treat the current value as the baseline.
                    originalNotes = notes
                    lastSavedAt = Date()
                }
            }
        }
    }

    private var isDirty: Bool {
        notes.trimmingCharacters(in: .whitespacesAndNewlines) != originalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduleAutosaveIfNeeded() {
        debounceTask?.cancel()

        // Don't queue saves while a save is already in progress.
        guard !isSaving else { return }

        // If nothing changed relative to the last saved baseline, no need to save.
        guard isDirty else { return }

        debounceTask = Task { @MainActor in
            // Debounce typing.
            try? await Task.sleep(nanoseconds: 650_000_000)

            // If user kept typing, or a save started, bail.
            guard !Task.isCancelled else { return }
            guard !isSaving else { return }
            guard isDirty else { return }

            onSave()
        }
    }

    private func relativeTimeString(since date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview("Notes Section") {
    struct NotesPreviewHost: View {
        @State private var notes: String = "Some initial notes..."
        @State private var isSaving: Bool = false
        var body: some View {
            NotesSectionView(
                notes: $notes,
                isSaving: $isSaving,
                onSave: {
                    // Simulate a save cycle
                    isSaving = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isSaving = false
                    }
                }
            )
            .padding()
        }
    }
    return NotesPreviewHost()
}

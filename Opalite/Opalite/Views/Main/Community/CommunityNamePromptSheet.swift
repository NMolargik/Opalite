//
//  CommunityNamePromptSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 4/15/26.
//

import SwiftUI

/// One-time prompt shown when the user first opens the Community tab,
/// asking them to choose the display name shown on their publications.
struct CommunityNamePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"

    @State private var draftName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.teal.gradient)
                        .padding(.top, 20)

                    VStack(spacing: 12) {
                        Text("Choose Your Display Name")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text("This name appears on colors and palettes you publish to the Community. You can change it any time in Settings.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Display Name", systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Your name", text: $draftName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isNameFieldFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.quaternary)
                            )
                            .accessibilityLabel("Display name")
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedDraftName.isEmpty)
                }
            }
            .onAppear {
                // Pre-fill with the current value unless it's the default placeholder.
                draftName = (userName == "User") ? "" : userName
                isNameFieldFocused = true
            }
        }
    }

    private func save() {
        let name = trimmedDraftName
        guard !name.isEmpty else { return }
        HapticsManager.shared.selection()
        userName = name
        dismiss()
    }
}

#Preview {
    CommunityNamePromptSheet()
}

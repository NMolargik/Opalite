//
//  ReportItemSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CloudKit

struct ReportItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CommunityManager.self) private var communityManager
    @Environment(ToastManager.self) private var toastManager

    let recordID: CKRecord.ID
    let itemType: CommunityItemType

    @State private var selectedReason: ReportReason?
    @State private var additionalDetails: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Help us keep Opalite safe by reporting content that violates our community guidelines.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)

                Section("Reason") {
                    ForEach(ReportReason.allCases) { reason in
                        Button {
                            HapticsManager.shared.selection()
                            selectedReason = reason
                        } label: {
                            HStack {
                                Image(systemName: reason.icon)
                                    .foregroundStyle(.inverseTheme)
                                    .frame(width: 24)

                                Text(reason.rawValue)
                                    .foregroundStyle(.inverseTheme)

                                Spacer()

                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                    }
                }

                Section("Additional Details (Optional)") {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 100)
                }

                Section {
                    Button {
                        HapticsManager.shared.selection()
                        submitReport()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Submit Report")
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
                }
            }
        }
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }

        isSubmitting = true

        Task {
            do {
                let details = additionalDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                try await communityManager.reportItem(
                    recordID: recordID,
                    type: itemType,
                    reason: reason,
                    details: details.isEmpty ? nil : details
                )
                await MainActor.run {
                    toastManager.showSuccess("Report submitted")
                    dismiss()
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    toastManager.show(error: error)
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    toastManager.show(error: .communityReportFailed(reason: error.localizedDescription))
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    ReportItemSheet(
        recordID: CKRecord.ID(recordName: "sample"),
        itemType: .color
    )
    .environment(CommunityManager())
    .environment(ToastManager())
}

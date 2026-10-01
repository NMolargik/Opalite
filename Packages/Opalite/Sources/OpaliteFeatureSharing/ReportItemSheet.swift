//
//  ReportItemSheet.swift
//  OpaliteFeatureSharing
//
//  Reporting Community content: a reason, optional details, and a confirmation before
//  the report is sent through `CommunityModel.report`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import os

public struct ReportItemSheet: View {
    private let id: CommunityRecordID
    private let type: CommunityItemType

    @Environment(\.dismiss) private var dismiss
    @Environment(CommunityModel.self) private var community
    @State private var draft = ReportDraft()
    @State private var isConfirming = false
    @State private var isSubmitting = false

    public init(id: CommunityRecordID, type: CommunityItemType) {
        self.id = id
        self.type = type
    }

    private var itemName: String {
        switch type {
        case .color: String(localized: "color")
        case .palette: String(localized: "palette")
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    StatusCallout(
                        title: String(localized: "Report this \(itemName)"),
                        message: String(localized: "Help keep the Community safe. Reports are anonymous, and content is hidden automatically once \(CommunityModeration.autoHideThreshold) people report it."),
                        systemImage: "flag.fill",
                        tint: .red
                    )
                }

                Section {
                    Picker("Reason", selection: $draft.reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Label(reason.title, systemImage: reason.systemImage)
                                .tag(Optional(reason))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("sharing.report.reason")
                } header: {
                    Text("Reason")
                }

                Section {
                    TextField("Details", text: $draft.details, prompt: Text("Anything that helps us understand the problem"), axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityLabel(Text("Details"))
                        .accessibilityIdentifier("sharing.report.details")
                } header: {
                    Text("Details (Optional)")
                } footer: {
                    Text("^[\(draft.detailsRemaining) character](inflect: true) left")
                        .foregroundStyle(draft.isDetailsOverLimit ? .red : .secondary)
                        .contentTransition(.numericText())
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ActionBar {
                    Button {
                        Haptics.selection()
                        isConfirming = true
                    } label: {
                        if isSubmitting {
                            Label {
                                Text("Submitting…")
                            } icon: {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                        } else {
                            Label("Submit Report", systemImage: "flag.fill")
                        }
                    }
                    .primaryActionButton(tint: .red)
                    .disabled(!draft.canSubmit || isSubmitting)
                    .accessibilityHint(draft.canSubmit ? Text("Asks you to confirm before sending") : Text("Choose a reason first"))
                    .accessibilityIdentifier("sharing.report.submit")
                }
            }
            .confirmationDialog("Submit this report?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Submit Report", role: .destructive) {
                    Task { await submit() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let reason = draft.reason {
                    Text("The \(itemName) will be reported for \(reason.title). This can't be undone.")
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onChange(of: draft.reason) { Haptics.selection() }
        }
        .sharingSheet(detents: [.medium, .large])
    }

    private func submit() async {
        guard let reason = draft.reason, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        if await community.report(id: id, type: type, reason: reason, details: draft.trimmedDetails) {
            Log.community.info("Reported \(type.rawValue, privacy: .public) \(id.recordName, privacy: .public)")
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }
}

#if DEBUG
#Preview("Report") {
    ReportItemSheet(id: CommunityColor.sample.id, type: .color)
        .previewEnvironment()
}
#endif
#endif

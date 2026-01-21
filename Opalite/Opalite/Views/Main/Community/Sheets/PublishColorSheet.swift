//
//  PublishColorSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

struct PublishColorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CommunityManager.self) private var communityManager
    @Environment(ToastManager.self) private var toastManager

    let color: OpaliteColor

    @State private var isPublishing = false
    @State private var publishError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Color Preview
                SwatchView(
                    color: color,
                    height: 120,
                    badgeText: color.name ?? color.hexString,
                    showOverlays: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share this color with the Opalite community!")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "person.fill", title: "Publisher Name", value: communityManager.publisherName)
                        InfoRow(icon: "calendar", title: "Original Created", value: color.createdAt.formatted(date: .abbreviated, time: .omitted))
                        if let device = color.createdOnDeviceName {
                            InfoRow(icon: "desktopcomputer", title: "Created On", value: device)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Guidelines
                VStack(alignment: .leading, spacing: 8) {
                    Text("Community Guidelines")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Please ensure your content follows our community guidelines. Inappropriate content may be removed and your account may be restricted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                // Publish Button
                Button {
                    HapticsManager.shared.selection()
                    publishColor()
                } label: {
                    HStack {
                        if isPublishing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "person.2")
                        }
                        Text(isPublishing ? "Publishing..." : "Publish to Community")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPublishing ? Color.gray : Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isPublishing || !communityManager.isUserSignedIn)
                .padding(.horizontal)

                if let error = publishError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if !communityManager.isUserSignedIn {
                    Text("Sign in to iCloud in Settings to publish")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
            .navigationTitle("Publish Color")
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

    private func publishColor() {
        isPublishing = true
        publishError = nil

        Task {
            do {
                _ = try await communityManager.publishColor(color)
                await MainActor.run {
                    toastManager.showSuccess("Published to Community!")
                    dismiss()
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    publishError = error.errorDescription
                    isPublishing = false
                }
            } catch {
                await MainActor.run {
                    publishError = error.localizedDescription
                    isPublishing = false
                }
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    PublishColorSheet(color: OpaliteColor.sample)
        .environment(CommunityManager())
        .environment(ToastManager())
}

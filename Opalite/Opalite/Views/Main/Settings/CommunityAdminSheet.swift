//
//  CommunityAdminSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CloudKit

struct CommunityAdminSheet: View {
    @Environment(CommunityManager.self) private var communityManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.dismiss) private var dismiss

    @State private var reportedColors: [CommunityColor] = []
    @State private var reportedPalettes: [CommunityPalette] = []
    @State private var isLoading = true
    @State private var selectedTab = AdminTab.colors

    private enum AdminTab {
        case colors, palettes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Loading reports...")
                    Spacer()
                } else if reportedColors.isEmpty && reportedPalettes.isEmpty {
                    ContentUnavailableView(
                        "No Reports",
                        systemImage: "checkmark.shield",
                        description: Text("All content is clear!")
                    )
                } else {
                    Picker("Type", selection: $selectedTab) {
                        Text("Colors (\(reportedColors.count))").tag(AdminTab.colors)
                        Text("Palettes (\(reportedPalettes.count))").tag(AdminTab.palettes)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    List {
                        if selectedTab == .colors {
                            ForEach(reportedColors) { color in
                                ReportedItemRow(
                                    name: color.name ?? color.hexString,
                                    publisherName: color.publisherName,
                                    reportCount: Int(color.reportCount),
                                    itemLabel: "Color",
                                    deleteMessage: "This will permanently delete \"\(color.name ?? color.hexString)\" from Community.",
                                    onClear: { clearReports(recordID: color.id) },
                                    onDelete: { deleteEntity(recordID: color.id, type: .color) }
                                ) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(color.swiftUIColor)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(.primary.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        } else {
                            ForEach(reportedPalettes) { palette in
                                ReportedItemRow(
                                    name: palette.name,
                                    publisherName: palette.publisherName,
                                    reportCount: Int(palette.reportCount),
                                    itemLabel: "Palette",
                                    deleteMessage: "This will permanently delete \"\(palette.name)\" and its colors from Community.",
                                    onClear: { clearReports(recordID: palette.id) },
                                    onDelete: { deleteEntity(recordID: palette.id, type: .palette) }
                                ) {
                                    HStack(spacing: 2) {
                                        ForEach(palette.colors.prefix(4)) { color in
                                            Rectangle()
                                                .fill(color.swiftUIColor)
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.primary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Community Admin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadReports() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await loadReports()
        }
    }

    private func loadReports() async {
        isLoading = true
        do {
            reportedColors = try await communityManager.fetchReportedColors()
            reportedPalettes = try await communityManager.fetchReportedPalettes()
        } catch {
            toastManager.show(error: error as? OpaliteError ?? .communityFetchFailed(reason: error.localizedDescription))
        }
        isLoading = false
    }

    private func clearReports(recordID: CKRecord.ID) {
        Task {
            do {
                try await communityManager.clearReports(recordID: recordID)
                await loadReports()
                toastManager.showSuccess("Reports cleared")
            } catch {
                toastManager.show(error: error as? OpaliteError ?? .communityFetchFailed(reason: error.localizedDescription))
            }
        }
    }

    private func deleteEntity(recordID: CKRecord.ID, type: CommunityItemType) {
        Task {
            do {
                try await communityManager.adminDeleteEntity(recordID: recordID, type: type)
                await loadReports()
                toastManager.showSuccess("Entity deleted")
            } catch {
                toastManager.show(error: error as? OpaliteError ?? .communityDeleteFailed(reason: error.localizedDescription))
            }
        }
    }
}

// MARK: - Row View

private struct ReportedItemRow<Thumbnail: View>: View {
    let name: String
    let publisherName: String
    let reportCount: Int
    let itemLabel: String
    let deleteMessage: String
    let onClear: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let thumbnail: Thumbnail

    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text("By \(publisherName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(reportCount) reports", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Menu {
                Button {
                    onClear()
                } label: {
                    Label("Clear Reports", systemImage: "checkmark.shield")
                }

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete \(itemLabel)", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
        .alert("Delete \(itemLabel)?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text(deleteMessage)
        }
    }
}

#Preview("Community Admin") {
    CommunityAdminSheet()
        .environment(CommunityManager())
        .environment(ToastManager())
}

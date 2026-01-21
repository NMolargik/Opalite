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
    @State private var selectedTab = 0

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
                        Text("Colors (\(reportedColors.count))").tag(0)
                        Text("Palettes (\(reportedPalettes.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    List {
                        if selectedTab == 0 {
                            ForEach(reportedColors) { color in
                                ReportedColorRow(color: color, onClear: clearReports, onDelete: deleteEntity)
                            }
                        } else {
                            ForEach(reportedPalettes) { palette in
                                ReportedPaletteRow(palette: palette, onClear: clearReports, onDelete: deleteEntity)
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

// MARK: - Row Views

private struct ReportedColorRow: View {
    let color: CommunityColor
    let onClear: (CKRecord.ID) -> Void
    let onDelete: (CKRecord.ID, CommunityItemType) -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.swiftUIColor)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(color.name ?? color.hexString)
                    .font(.headline)
                Text("By \(color.publisherName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(color.reportCount) reports", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Menu {
                Button {
                    onClear(color.id)
                } label: {
                    Label("Clear Reports", systemImage: "checkmark.shield")
                }

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Color", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
        .alert("Delete Color?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete(color.id, .color)
            }
        } message: {
            Text("This will permanently delete \"\(color.name ?? color.hexString)\" from Community.")
        }
    }
}

private struct ReportedPaletteRow: View {
    let palette: CommunityPalette
    let onClear: (CKRecord.ID) -> Void
    let onDelete: (CKRecord.ID, CommunityItemType) -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            // Palette preview
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

            VStack(alignment: .leading, spacing: 4) {
                Text(palette.name)
                    .font(.headline)
                Text("By \(palette.publisherName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(palette.reportCount) reports", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Menu {
                Button {
                    onClear(palette.id)
                } label: {
                    Label("Clear Reports", systemImage: "checkmark.shield")
                }

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Palette", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
        .alert("Delete Palette?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete(palette.id, .palette)
            }
        } message: {
            Text("This will permanently delete \"\(palette.name)\" and its colors from Community.")
        }
    }
}

#Preview("Community Admin") {
    CommunityAdminSheet()
        .environment(CommunityManager())
        .environment(ToastManager())
}

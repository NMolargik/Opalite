//
//  BackupsView.swift
//  OpaliteFeatureSettings
//
//  Settings › Backups: the automatic local backups, "Back Up Now", restore (a merge that
//  only adds what is missing), sharing a backup file, and importing one.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UniformTypeIdentifiers
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared

struct BackupsView: View {
    @Environment(BackupManager.self) private var backups
    @Environment(ToastManager.self) private var toast

    @State private var pendingRestore: BackupRecord?
    @State private var pendingDelete: BackupRecord?
    @State private var isImporting = false

    var body: some View {
        Form {
            actionsSection
            savedSection
        }
        .navigationTitle("Backups")
        .onAppear { backups.reload() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            importBackup(result)
        }
        .confirmationDialog(
            "Restore This Backup?",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible,
            presenting: pendingRestore
        ) { record in
            Button("Restore") { restore(record) }
                .accessibilityIdentifier("backups.confirmRestore")
            Button("Cancel", role: .cancel) {}
        } message: { record in
            Text("Restore only adds colors and palettes from \(record.createdAt.formatted(date: .abbreviated, time: .shortened)) that are missing. Nothing you have now is changed or deleted, and anything you deleted since comes back.")
        }
        .confirmationDialog(
            "Delete This Backup?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { record in
            Button("Delete Backup", role: .destructive) {
                Haptics.warning()
                backups.delete(record)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This removes the backup file from this device. Your colors and palettes aren't affected.")
        }
    }

    // MARK: Actions

    private var actionsSection: some View {
        Section {
            Button {
                Haptics.selection()
                if backups.backUpNow() != nil {
                    toast.showSuccess(String(localized: "Backup saved"), systemImage: "clock.arrow.circlepath")
                } else {
                    toast.show(message: backups.lastErrorMessage ?? String(localized: "The backup couldn't be saved."), style: .error, systemImage: "exclamationmark.triangle.fill")
                }
            } label: {
                HStack {
                    Label("Back Up Now", systemImage: "externaldrive.badge.plus")
                        .labelStyle(.settingsIcon(.blue))
                    if backups.isWorking {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(backups.isWorking)
            .accessibilityIdentifier("backups.backUpNow")

            Button {
                Haptics.selection()
                isImporting = true
            } label: {
                Label("Import Backup File", systemImage: "square.and.arrow.down")
                    .labelStyle(.settingsIcon(.indigo))
            }
            .accessibilityHint(Text("Adds a backup file to the list. It isn't restored until you choose Restore."))
            .accessibilityIdentifier("backups.import")
        } footer: {
            Text("Opalite saves a backup of your colors and palettes on this device once a day and before you delete several items at once. The newest 10 are kept. Backups stay on this device and aren't synced to iCloud. Canvases aren't included.")
        }
    }

    private var savedSection: some View {
        Section {
            if backups.records.isEmpty {
                Text("No backups yet. The first one is saved the next time Opalite opens, or tap Back Up Now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("backups.empty")
            }
            ForEach(backups.records) { record in
                BackupRow(
                    record: record,
                    onRestore: { pendingRestore = record },
                    onDelete: { pendingDelete = record },
                    shareFile: BackupShareFile(manager: backups, record: record)
                )
            }
        } header: {
            Text("Saved Backups")
        } footer: {
            if !backups.records.isEmpty {
                Text("Restoring adds anything that is missing and leaves everything else as it is.")
            }
        }
    }

    // MARK: Work

    private func restore(_ record: BackupRecord) {
        do {
            let summary = try backups.restore(record)
            Haptics.success()
            toast.showSuccess(BackupPresentation.restoreResult(summary), systemImage: "clock.arrow.circlepath")
        } catch {
            Haptics.error()
            toast.show(message: error.localizedDescription, style: .error, systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func importBackup(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            do {
                _ = try backups.importBackup(from: url)
                toast.showSuccess(String(localized: "Backup added to the list"), systemImage: "square.and.arrow.down")
            } catch {
                Haptics.error()
                toast.show(message: error.localizedDescription, style: .error, systemImage: "exclamationmark.triangle.fill")
            }
        case .failure(let error):
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            toast.show(message: error.localizedDescription, style: .error, systemImage: "exclamationmark.triangle.fill")
        }
    }
}

// MARK: - Row

private struct BackupRow: View {
    let record: BackupRecord
    let onRestore: () -> Void
    let onDelete: () -> Void
    let shareFile: BackupShareFile

    var body: some View {
        HStack(spacing: Brand.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body.weight(.medium))
                Text(BackupPresentation.counts(record.header))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(BackupPresentation.reason(record.header.reason)) · \(record.header.deviceName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: Brand.Space.sm)
            Menu {
                Button {
                    Haptics.selection()
                    onRestore()
                } label: {
                    Label("Restore…", systemImage: "arrow.counterclockwise")
                }
                ShareLink(item: shareFile, preview: SharePreview(BackupFileStore.shareFileName(for: record.header))) {
                    Label("Share Backup File", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete…", systemImage: "trash")
                }
                .destructiveMenuItem()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Backup options"))
            .accessibilityIdentifier("backups.row.menu")
        }
        .accessibilityElement(children: .contain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onRestore) {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .tint(.blue)
        }
    }
}

/// A backup travelling through the share sheet under a friendly file name.
@MainActor
struct BackupShareFile: Transferable {
    let manager: BackupManager
    let record: BackupRecord

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            let url = try await MainActor.run { try item.manager.shareCopy(of: item.record) }
            return SentTransferredFile(url)
        }
    }
}

#if DEBUG
#Preview("Backups") {
    NavigationStack { BackupsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

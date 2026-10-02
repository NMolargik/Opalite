//
//  ExportSheet.swift
//  OpaliteFeatureSharing
//
//  The one export flow both public sheets wrap: a live preview, a grouped list of format
//  rows (Onyx-gated ones route to the paywall), a Community row, and an action bar with
//  the share sheet (`ShareLink`) and "Save to Files" (`.fileExporter`). Choosing a format
//  writes the file right away through `ExportService`, so both actions are instant.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices
import os

struct ExportSheet<Format: PresentableExportFormat, Hero: View, PublishSheet: View>: View {
    let title: String
    let subject: String
    let formats: [Format]
    let prepare: @MainActor (Format) throws -> URL
    let previewPNG: @MainActor () -> Data?
    @ContentBuilder let hero: () -> Hero
    @ContentBuilder let publishSheet: () -> PublishSheet

    @Environment(\.dismiss) private var dismiss
    @Environment(\.onyxEntitlement) private var entitlement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppRouter.self) private var router
    @Environment(ToastManager.self) private var toastManager
    @Environment(CommunityModel.self) private var community

    @State private var selectedFormat: Format?
    @State private var exported: ExportedFile?
    @State private var errorMessage: String?
    @State private var isPreparing = false
    @State private var isSavingToFiles = false
    @State private var isShowingPublish = false
    @State private var sharePreviewImage: Image?

    private var hasOnyx: Bool { entitlement.hasOnyx }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    hero()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(formats) { format in
                        FormatRow(
                            format: format,
                            isSelected: selectedFormat == format,
                            isLocked: ExportAccess.isLocked(format, hasOnyx: hasOnyx),
                            isBusy: isPreparing && selectedFormat == format
                        ) {
                            choose(format)
                        }
                    }
                } header: {
                    Text("Format")
                } footer: {
                    if ExportAccess.hasLockedFormats(in: formats, hasOnyx: hasOnyx) {
                        Text("Formats marked Onyx are part of the Onyx upgrade.")
                    }
                }

                Section {
                    publishRow
                } header: {
                    Text("Community")
                } footer: {
                    if !community.isConnected {
                        Text("Publishing needs an internet connection.")
                    } else if !community.isUserSignedIn {
                        Text("Publishing uses your iCloud account.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityIdentifier("sharing.export.close")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
            .task(id: selectedFormat) { await prepareSelected() }
            .fileExporter(
                isPresented: $isSavingToFiles,
                document: exported.map(ExportFileDocument.init),
                contentType: exported?.contentType ?? .data,
                defaultFilename: exported?.baseName
            ) { result in
                handleSaveResult(result)
            }
            .sharedSheet(isPresented: $isShowingPublish) { publishSheet() }
        }
        .sharingSheet(detents: [.large])
        .onAppear {
            if selectedFormat == nil {
                selectedFormat = ExportAccess.defaultFormat(in: formats, hasOnyx: hasOnyx)
            }
        }
        .onDisappear { exported?.removeFromDisk() }
    }

    // MARK: - Rows

    private var publishRow: some View {
        Button {
            Haptics.selection()
            isShowingPublish = true
        } label: {
            HStack(spacing: Brand.Space.md) {
                IconTile(systemImage: community.isConnected ? "person.2.fill" : "wifi.slash", tint: .teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Publish to Community")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(community.isConnected ? "Share \(subject) with everyone using Opalite." : "You're offline right now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: Brand.Space.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!community.isConnected)
        .accessibilityElement(children: .combine)
        .accessibilityHint(community.isConnected ? Text("Opens the publish sheet") : Text("Unavailable while offline"))
        .accessibilityIdentifier("sharing.export.publish")
    }

    // MARK: - Action bar

    private var actionBar: some View {
        ActionBar {
            Group {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("sharing.export.error")
                } else if let exported {
                    Text(exported.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityLabel(Text("File \(exported.filename)"))
                } else {
                    Text("Choose a format to continue")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .default, value: exported)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Brand.Space.md) {
                    shareButton
                    saveButton
                }
                VStack(spacing: Brand.Space.sm) {
                    shareButton
                    saveButton
                }
            }
        }
    }

    @ContentBuilder
    private var shareButton: some View {
        if let exported {
            Group {
                if let sharePreviewImage {
                    ShareLink(item: exported, preview: SharePreview(exported.filename, image: sharePreviewImage)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(item: exported, preview: SharePreview(exported.filename)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .primaryActionButton()
            .simultaneousGesture(TapGesture().onEnded { Haptics.lightImpact() })
            .accessibilityHint(Text("Opens the share sheet for \(exported.filename)"))
            .accessibilityIdentifier("sharing.export.share")
        } else {
            Button {} label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .primaryActionButton()
            .disabled(true)
            .accessibilityIdentifier("sharing.export.share")
        }
    }

    private var saveButton: some View {
        Button {
            Haptics.selection()
            isSavingToFiles = true
        } label: {
            Label("Save to Files", systemImage: "folder")
        }
        .secondaryActionButton()
        .disabled(exported == nil)
        .accessibilityHint(Text("Chooses a folder to save the file in"))
        .accessibilityIdentifier("sharing.export.save")
    }

    // MARK: - Actions

    private func choose(_ format: Format) {
        if ExportAccess.isLocked(format, hasOnyx: hasOnyx) {
            Haptics.warning()
            requestPaywall(for: format)
            return
        }
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            selectedFormat = format
        }
    }

    /// The shell presents the paywall from the root, so this sheet steps aside first.
    private func requestPaywall(for format: Format) {
        let context = String(localized: "Exporting \(format.displayName) files requires Onyx")
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            router.requestPaywall(context: context)
        }
    }

    private func prepareSelected() async {
        guard let format = selectedFormat else { return }
        isPreparing = true
        errorMessage = nil
        let previous = exported
        defer { isPreparing = false }
        do {
            let url = try prepare(format)
            let file = try ExportedFile.load(url, contentType: format.contentType)
            if previous?.url != file.url { previous?.removeFromDisk() }
            exported = file
            if sharePreviewImage == nil, let png = previewPNG(), let image = UIImage(data: png) {
                sharePreviewImage = Image(uiImage: image)
            }
            Log.sharing.info("Prepared \(file.filename, privacy: .public) (\(file.byteCount) bytes)")
        } catch {
            exported = nil
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            Log.sharing.error("Export failed for \(format.fileExtension, privacy: .public): \(error.localizedDescription)")
            Haptics.error()
        }
    }

    private func handleSaveResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            Log.sharing.info("Saved export to \(url.lastPathComponent, privacy: .public)")
            toastManager.showSuccess(String(localized: "Saved \(url.lastPathComponent)"), systemImage: "folder.fill")
            dismiss()
        case .failure(let error):
            // A cancelled picker reports an error too; only surface real failures.
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            toastManager.show(error: OpaliteError.exportFailed(reason: error.localizedDescription))
        }
    }
}

// MARK: - Format row

/// One format: icon tile in the format's tint, name, description, and a selection mark or
/// an Onyx badge when gated.
struct FormatRow<Format: PresentableExportFormat>: View {
    let format: Format
    let isSelected: Bool
    let isLocked: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Brand.Space.md) {
                IconTile(systemImage: format.systemImage, tint: format.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(format.formatDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Brand.Space.sm)
                trailing
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(format.displayName), \(format.fileExtension.uppercased())"))
        .accessibilityValue(isSelected ? Text("Selected") : Text(""))
        .accessibilityHint(isLocked ? Text("Requires Onyx. Double-tap to learn more.") : Text("Double-tap to choose this format."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("sharing.export.format.\(format.id)")
    }

    @ContentBuilder
    private var trailing: some View {
        if isLocked {
            OnyxBadge(compact: true)
        } else if isBusy {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
    }
}

/// The iOS-Settings style glyph tile used by every row in the sheets.
struct IconTile: View {
    let systemImage: String
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(tint.gradient))
            .accessibilityHidden(true)
    }
}
#endif

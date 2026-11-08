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

struct ExportSheet<Format: PresentableExportFormat, Hero: View, Options: View, PublishSheet: View>: View {
    let title: String
    let subject: String
    let formats: [Format]
    /// Changes whenever an option that affects the written file changes, so the file is
    /// prepared again. Sheets without options leave it at its default.
    let optionsRevision: AnyHashable
    let prepare: @MainActor (Format) throws -> URL
    let previewPNG: @MainActor () -> Data?
    @ContentBuilder let hero: () -> Hero
    /// Extra controls for the chosen format, shown as their own section when non-empty.
    @ContentBuilder let options: (Format?) -> Options
    @ContentBuilder let publishSheet: () -> PublishSheet

    init(
        title: String,
        subject: String,
        formats: [Format],
        optionsRevision: AnyHashable = 0,
        prepare: @escaping @MainActor (Format) throws -> URL,
        previewPNG: @escaping @MainActor () -> Data?,
        @ContentBuilder hero: @escaping () -> Hero,
        @ContentBuilder options: @escaping (Format?) -> Options,
        @ContentBuilder publishSheet: @escaping () -> PublishSheet
    ) {
        self.title = title
        self.subject = subject
        self.formats = formats
        self.optionsRevision = optionsRevision
        self.prepare = prepare
        self.previewPNG = previewPNG
        self.hero = hero
        self.options = options
        self.publishSheet = publishSheet
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.onyxEntitlement) private var entitlement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppRouter.self) private var router
    @Environment(ToastManager.self) private var toastManager
    @Environment(CommunityModel.self) private var community
    @Environment(PortfolioModel.self) private var portfolio

    @State private var selectedFormat: Format?
    @State private var path: [ExportGroup] = []
    @State private var exported: ExportedFile?
    @State private var errorMessage: String?
    @State private var isPreparing = false
    @State private var isSavingToFiles = false
    @State private var isShowingPublish = false
    @State private var sharePreviewImage: Image?
    /// The extension of the last pro-format file written, for the review prompt on dismiss.
    @State private var exportedProExtension: String?

    private var hasOnyx: Bool { entitlement.hasOnyx }

    var body: some View {
        NavigationStack(path: $path) {
            let layout = ExportFormatCatalog.layout(formats, idOf: \.groupKey)
            List {
                Section {
                    hero()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(layout.quick) { format in formatRow(format, showsDetail: false) }
                }

                if !layout.groups.isEmpty {
                    Section {
                        if !hasOnyx { onyxNote }
                        ForEach(layout.groups) { entry in groupRow(entry, layout: layout) }
                    }
                }

                options(selectedFormat)

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
            .navigationDestination(for: ExportGroup.self) { group in
                groupList(group, layout: layout)
            }
            #if DEBUG
            .task {
                // Simulator verification: `--export-group=code` opens that group's list.
                guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--export-group=") }),
                      let group = ExportGroup(rawValue: String(argument.dropFirst("--export-group=".count))) else { return }
                try? await Task.sleep(for: .seconds(1))
                path = [group]
            }
            #endif
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
            .task(id: PrepareKey(format: selectedFormat, revision: optionsRevision)) { await prepareSelected() }
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
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .sharingSheet(detents: [.large])
        .onAppear {
            if selectedFormat == nil {
                selectedFormat = ExportAccess.defaultFormat(in: formats, hasOnyx: hasOnyx)
            }
        }
        .onDisappear {
            exported?.removeFromDisk()
            if let exportedProExtension {
                // The sheet is gone; give its animation a beat before the system alert.
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    portfolio.requestReviewAfterExport(fileExtension: exportedProExtension)
                }
            }
        }
    }

    // MARK: - Rows

    private func formatRow(_ format: Format, showsDetail: Bool = true) -> some View {
        FormatRow(
            format: format,
            isSelected: selectedFormat == format,
            isLocked: ExportAccess.isLocked(format, hasOnyx: hasOnyx),
            isBusy: isPreparing && selectedFormat == format,
            showsDetail: showsDetail
        ) {
            choose(format)
        }
    }

    /// One group: a single line with the count, or the chosen format when it holds the selection.
    private func groupRow(_ entry: ExportGroupEntry<Format>, layout: ExportLayout<Format>) -> some View {
        let selected = selectedFormat.flatMap { format in entry.formats.contains(format) ? format : nil }
        return NavigationLink(value: entry.group) {
            HStack(spacing: Brand.Space.md) {
                IconTile(systemImage: ExportRowCopy.systemImage(for: entry.group), tint: ExportRowCopy.tint(for: entry.group))
                Text(ExportRowCopy.title(for: entry.group))
                    .font(.body.weight(.medium))
                Spacer(minLength: Brand.Space.sm)
                if let selected {
                    Text(selected.listTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                } else {
                    Text("\(entry.formats.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(selected.map { Text(verbatim: $0.listTitle) } ?? Text("^[\(entry.formats.count) format](inflect: true)"))
        .accessibilityIdentifier("sharing.export.group.\(entry.group.id)")
    }

    /// The pushed list for one group.
    private func groupList(_ group: ExportGroup, layout: ExportLayout<Format>) -> some View {
        let members = layout.groups.first { $0.group == group }?.formats ?? []
        return List {
            if !hasOnyx {
                Section { onyxNote }
            }
            Section {
                ForEach(members) { format in formatRow(format) }
            } footer: {
                if group != .designApps {
                    Text("Colors keep their wide-gamut values where the format supports them. Other formats get an sRGB approximation.")
                }
            }
            options(selectedFormat)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(ExportRowCopy.title(for: group))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The one place Onyx is mentioned instead of a lock on every row.
    private var onyxNote: some View {
        Button {
            Haptics.warning()
            requestPaywall(context: String(localized: "Exporting files and code requires Onyx"))
        } label: {
            HStack(spacing: Brand.Space.md) {
                Image(systemName: "diamond.fill")
                    .font(.subheadline)
                    .foregroundStyle(LinearGradient.onyx)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("Files and code need Onyx")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Brand.Space.sm)
                Text("Get Onyx")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.opaliteBlue.inkVariant)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens Onyx"))
        .accessibilityIdentifier("sharing.export.onyxNote")
    }

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
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ShareLink(item: exported, preview: SharePreview(exported.filename)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
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
                    .frame(maxWidth: .infinity)
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
                .frame(maxWidth: .infinity)
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
            requestPaywall(context: String(localized: "Exporting \(format.displayName) files requires Onyx"))
            return
        }
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            selectedFormat = format
        }
    }

    /// The shell presents the paywall from the root, so this sheet steps aside first.
    private func requestPaywall(context: String) {
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
            if ReviewMilestone.proExportExtensions.contains(format.fileExtension) {
                exportedProExtension = format.fileExtension
            }
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

extension ExportSheet where Options == EmptyView {
    /// A sheet with no per-format options.
    init(
        title: String,
        subject: String,
        formats: [Format],
        prepare: @escaping @MainActor (Format) throws -> URL,
        previewPNG: @escaping @MainActor () -> Data?,
        @ContentBuilder hero: @escaping () -> Hero,
        @ContentBuilder publishSheet: @escaping () -> PublishSheet
    ) {
        self.init(
            title: title,
            subject: subject,
            formats: formats,
            prepare: prepare,
            previewPNG: previewPNG,
            hero: hero,
            options: { _ in EmptyView() },
            publishSheet: publishSheet
        )
    }
}

/// What a prepared file depends on: the format and the options revision.
private struct PrepareKey<Format: Hashable>: Hashable {
    let format: Format?
    let revision: AnyHashable
}

// MARK: - Format row

/// One format on a single line (name plus file extension) with at most one short line
/// under it, and a selection mark. Gated formats look like the rest: the sheet's one Onyx
/// note explains the gate and tapping one opens the paywall.
struct FormatRow<Format: PresentableExportFormat>: View {
    let format: Format
    let isSelected: Bool
    let isLocked: Bool
    let isBusy: Bool
    var showsDetail = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Brand.Space.md) {
                IconTile(systemImage: format.systemImage, tint: format.tint)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Brand.Space.xs) {
                        Text(format.listTitle)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(verbatim: ".\(format.fileExtension)")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    if showsDetail, let detail = format.listDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: Brand.Space.sm)
                trailing
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(format.listTitle), \(format.fileExtension.uppercased())"))
        .accessibilityValue(isSelected ? Text("Selected") : Text(""))
        .accessibilityHint(isLocked ? Text("Requires Onyx. Double-tap to learn more.") : Text("Double-tap to choose this format."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("sharing.export.format.\(format.id)")
    }

    @ContentBuilder
    private var trailing: some View {
        if isBusy {
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

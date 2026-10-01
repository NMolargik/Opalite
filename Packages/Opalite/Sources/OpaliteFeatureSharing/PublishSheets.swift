//
//  PublishSheets.swift
//  OpaliteFeatureSharing
//
//  Publishing to the Community: a preview, optional notes (and tags for palettes), who
//  it's published as, the guidelines and the hourly limit, and one primary action that is
//  disabled with an explanation when the user is offline, signed out, or rate-limited.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import os

// MARK: - Color

public struct PublishColorSheet: View {
    private let color: OpaliteColor

    @Environment(\.dismiss) private var dismiss
    @Environment(CommunityModel.self) private var community
    @State private var draft: PublishDraft
    @State private var isPublishing = false

    public init(color: OpaliteColor) {
        self.color = color
        _draft = State(initialValue: PublishDraft(notes: color.notes))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    ColorHero(rgba: color.rgba, title: color.displayName)
                        .padding(.vertical, Brand.Space.sm)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Name", value: color.displayName)
                    NotesField(draft: $draft)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Notes are optional and go out with the color. To rename it, edit the color in your Portfolio.")
                }

                PublisherSection(
                    publisherName: community.publisherName,
                    createdAt: color.createdAt,
                    deviceName: color.createdOnDeviceName,
                    colorCount: nil
                )

                GuidelinesSection(includesPaletteNote: false)
            }
            .navigationTitle("Publish Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isPublishing)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PublishActionBar(blocker: blocker, isPublishing: isPublishing, isDisabled: draft.isNotesOverLimit) {
                    Task { await publish() }
                }
            }
            .interactiveDismissDisabled(isPublishing)
        }
        .sharingSheet(detents: [.large])
    }

    private var blocker: PublishBlocker? {
        PublishBlocker.evaluate(isConnected: community.isConnected, isSignedIn: community.isUserSignedIn, canPublish: community.canPublish)
    }

    private func publish() async {
        guard !isPublishing else { return }
        isPublishing = true
        defer { isPublishing = false }
        let snapshot = PublishSnapshot.color(color, notes: draft.trimmedNotes)
        if await community.publish(snapshot) {
            Log.community.info("Published color \(color.id, privacy: .public)")
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }
}

// MARK: - Palette

public struct PublishPaletteSheet: View {
    private let palette: OpalitePalette

    @Environment(\.dismiss) private var dismiss
    @Environment(CommunityModel.self) private var community
    @State private var draft: PublishDraft
    @State private var isPublishing = false

    public init(palette: OpalitePalette) {
        self.palette = palette
        _draft = State(initialValue: PublishDraft(notes: palette.notes, tags: palette.tags))
    }

    private static let previewSize = CGSize(width: 600, height: 300)

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    PaletteHero(name: palette.name, colors: palette.colorValues, background: palette.previewBackground)
                        .padding(.vertical, Brand.Space.sm)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Name", value: palette.name)
                    NotesField(draft: $draft)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Notes are optional and go out with the palette. To rename it, edit the palette in your Portfolio.")
                }

                Section {
                    TextField("Tags", text: $draft.tagsText, prompt: Text("warm, sunset, summer"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .accessibilityLabel(Text("Tags"))
                        .accessibilityHint(Text("Separate tags with commas"))
                        .accessibilityIdentifier("sharing.publish.tags")
                    if !draft.tags.isEmpty {
                        TagChips(tags: draft.tags)
                            .padding(.vertical, Brand.Space.xs)
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    if draft.isTagsOverLimit {
                        Text("Only the first \(PublishDraft.maxTags) tags are published.")
                    } else {
                        Text("Separate tags with commas. Up to \(PublishDraft.maxTags) tags help people find this palette.")
                    }
                }

                PublisherSection(
                    publisherName: community.publisherName,
                    createdAt: palette.createdAt,
                    deviceName: nil,
                    colorCount: palette.colorCount
                )

                GuidelinesSection(includesPaletteNote: true)
            }
            .navigationTitle("Publish Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.selection()
                        dismiss()
                    }
                    .disabled(isPublishing)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PublishActionBar(blocker: blocker, isPublishing: isPublishing, isDisabled: draft.isNotesOverLimit, emptyMessage: palette.colorCount == 0 ? String(localized: "Add at least one color before publishing.") : nil) {
                    Task { await publish() }
                }
            }
            .interactiveDismissDisabled(isPublishing)
        }
        .sharingSheet(detents: [.large])
    }

    private var blocker: PublishBlocker? {
        PublishBlocker.evaluate(isConnected: community.isConnected, isSignedIn: community.isUserSignedIn, canPublish: community.canPublish)
    }

    private func publish() async {
        guard !isPublishing else { return }
        isPublishing = true
        defer { isPublishing = false }
        let snapshot = PublishSnapshot.palette(palette, notes: draft.trimmedNotes, tags: draft.tags)
        let preview = ImageRendering.png(PaletteExportImageView(palette: snapshot, size: Self.previewSize), size: Self.previewSize, scale: 2)
        if await community.publish(snapshot, previewImagePNG: preview) {
            Log.community.info("Published palette \(palette.id, privacy: .public)")
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }
}

// MARK: - Shared pieces

/// The notes field with its remaining-character footer.
private struct NotesField: View {
    @Binding var draft: PublishDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xs) {
            TextField("Notes", text: $draft.notes, prompt: Text("What's the story behind it?"), axis: .vertical)
                .lineLimit(2...6)
                .accessibilityLabel(Text("Notes"))
                .accessibilityIdentifier("sharing.publish.notes")
            if draft.notesRemaining < 60 {
                Text("^[\(draft.notesRemaining) character](inflect: true) left")
                    .font(.caption2)
                    .foregroundStyle(draft.isNotesOverLimit ? .red : .secondary)
                    .contentTransition(.numericText())
                    .accessibilityHidden(draft.notesRemaining > 0)
            }
        }
    }
}

/// Who the item is published as, plus its provenance.
private struct PublisherSection: View {
    let publisherName: String
    let createdAt: Date
    let deviceName: String?
    let colorCount: Int?

    private var displayName: String {
        let trimmed = publisherName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Anonymous") : trimmed
    }

    var body: some View {
        Section {
            LabeledContent {
                Text(displayName)
            } label: {
                Label("Published as", systemImage: "person.fill")
                    .labelStyle(.alignedIcon)
            }
            if let colorCount {
                LabeledContent {
                    Text(colorCount.formatted())
                } label: {
                    Label("Colors", systemImage: "paintpalette.fill")
                        .labelStyle(.alignedIcon)
                }
            }
            LabeledContent {
                Text(createdAt.formatted(date: .abbreviated, time: .omitted))
            } label: {
                Label("Created", systemImage: "calendar")
                    .labelStyle(.alignedIcon)
            }
            if let deviceName, !deviceName.isEmpty {
                LabeledContent {
                    Text(deviceName)
                } label: {
                    Label("Created on", systemImage: "desktopcomputer")
                        .labelStyle(.alignedIcon)
                }
            }
        } header: {
            Text("Publisher")
        } footer: {
            Text("Your name comes from Settings › Profile and is shown with everything you publish.")
        }
    }
}

/// The rules of the road and the hourly limit.
private struct GuidelinesSection: View {
    let includesPaletteNote: Bool

    var body: some View {
        Section {
            Label {
                Text("Keep it yours and keep it kind. Content that breaks the Community guidelines can be removed and may limit your account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.opalitePurple)
            }
            .labelStyle(.alignedIcon)
            if includesPaletteNote {
                Label {
                    Text("Every color in this palette is published with it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(.opalitePurple)
                }
                .labelStyle(.alignedIcon)
            }
            Label {
                Text("To keep the Community fresh, you can publish up to \(PublishRateLimiter.maxPublishesPerHour) items an hour.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.opalitePurple)
            }
            .labelStyle(.alignedIcon)
        } header: {
            Text("Guidelines")
        }
    }
}

/// The publish button, preceded by why it's unavailable when it is.
private struct PublishActionBar: View {
    let blocker: PublishBlocker?
    let isPublishing: Bool
    var isDisabled = false
    var emptyMessage: String? = nil
    let action: () -> Void

    var body: some View {
        ActionBar {
            if let blocker {
                StatusCallout(title: blocker.title, message: blocker.message, systemImage: blocker.systemImage, tint: .orange)
            } else if let emptyMessage {
                StatusCallout(title: String(localized: "Nothing to publish yet"), message: emptyMessage, systemImage: "paintpalette", tint: .orange)
            }
            Button {
                Haptics.selection()
                action()
            } label: {
                if isPublishing {
                    Label {
                        Text("Publishing…")
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                } else {
                    Label("Publish to Community", systemImage: "person.2.fill")
                }
            }
            .primaryActionButton(tint: .teal)
            .disabled(blocker != nil || isPublishing || isDisabled || emptyMessage != nil)
            .accessibilityHint(blocker.map { Text($0.message) } ?? Text("Shares this with everyone using Opalite"))
            .accessibilityIdentifier("sharing.publish.confirm")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Publish Color") {
    PublishColorSheet(color: .sample)
        .previewEnvironment()
}

#Preview("Publish Palette") {
    Text("Host")
        .sheet(isPresented: .constant(true)) {
            PublishPaletteSheet(palette: .sample)
        }
        .previewEnvironment()
}
#endif
#endif

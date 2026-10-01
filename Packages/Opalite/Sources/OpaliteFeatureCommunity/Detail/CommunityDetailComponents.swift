//
//  CommunityDetailComponents.swift
//  OpaliteFeatureCommunity
//
//  Pieces the color and palette detail screens share: the publisher row that pushes a
//  profile, the primary "Save to Portfolio" action, the read-only notes card, the info
//  tile strip, and the width cap that centers detail content on wide windows.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - Publisher row

struct CommunityPublisherRow: View {
    let id: CommunityRecordID
    let displayName: String
    var isMine = false

    var body: some View {
        NavigationLink(value: CommunityDestination.publisher(id: id, displayName: displayName)) {
            HStack(spacing: Brand.Space.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(LinearGradient.opaliteHorizontal)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Brand.Space.sm) {
                        Text(displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if isMine {
                            Text("You")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule(style: .continuous).fill(Color.opaliteBlue.opacity(0.35)))
                        }
                    }
                    Text("View profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isMine ? "Publisher, \(displayName) (you)" : "Publisher, \(displayName)"))
        .accessibilityHint(Text("Opens the publisher's profile"))
        .accessibilityIdentifier("community.publisherRow")
    }
}

// MARK: - Save button

/// The single prominent action on a detail screen. Bounces on success; the model handles
/// the Onyx gate, duplicates, and toasts.
struct CommunitySaveButton: View {
    let isEnabled: Bool
    let action: () async -> Bool

    @Environment(\.onyxEntitlement) private var entitlement
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        Button {
            Haptics.selection()
            Task {
                isSaving = true
                let success = await action()
                isSaving = false
                if success { saved.toggle() }
            }
        } label: {
            Label {
                Text("Save to Portfolio")
            } icon: {
                Image(systemName: "square.and.arrow.down")
                    .symbolEffect(.bounce, value: saved)
            }
        }
        .glassActionButton(tint: .opalitePurple, prominent: true)
        .disabled(!isEnabled || isSaving)
        .overlay(alignment: .topTrailing) {
            if !entitlement.hasOnyx {
                OnyxBadge(compact: true)
                    .offset(x: 6, y: -8)
            }
        }
        .accessibilityHint(Text(entitlement.hasOnyx ? "Adds a copy to your Portfolio" : "Requires Onyx"))
        .accessibilityIdentifier("community.saveButton")
    }
}

// MARK: - Notes

struct CommunityNotesCard: View {
    let notes: String

    @State private var isExpanded = true

    var body: some View {
        SectionCard(String(localized: "Notes"), systemImage: "note.text", tint: .opaliteBlue, isExpanded: $isExpanded) {
            Text(notes)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .selectableText()
        }
    }
}

// MARK: - Info tiles

struct CommunityInfoTileStrip: View {
    struct Tile: Identifiable {
        let id: String
        let title: String
        let value: String
        let systemImage: String
        let tint: Color
    }

    let tiles: [Tile]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Brand.Space.md) {
                ForEach(tiles) { tile in
                    InfoTile(title: tile.title, value: tile.value, systemImage: tile.systemImage, tint: tile.tint)
                }
            }
            VStack(spacing: Brand.Space.md) {
                ForEach(tiles) { tile in
                    InfoTile(title: tile.title, value: tile.value, systemImage: tile.systemImage, tint: tile.tint)
                }
            }
        }
    }
}

// MARK: - Width cap

extension View {
    /// Caps detail content at `Brand.detailMaxWidth` and centers it on wide windows.
    func communityDetailWidth() -> some View {
        frame(maxWidth: Brand.detailMaxWidth)
            .frame(maxWidth: .infinity)
    }

    /// `textSelection(.enabled)` where the platform supports it.
    @ContentBuilder
    func selectableText() -> some View {
        #if os(tvOS) || os(watchOS)
        self
        #else
        textSelection(.enabled)
        #endif
    }
}

#if DEBUG
#Preview("Detail components") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                CommunityInfoTileStrip(tiles: [
                    .init(id: "a", title: "Publisher", value: "Sample User", systemImage: "person.fill", tint: .opalitePurple),
                    .init(id: "b", title: "Created On", value: "iPhone", systemImage: "iphone", tint: .opaliteBlue),
                    .init(id: "c", title: "Published", value: "Jan 21", systemImage: "calendar", tint: .opaliteTan),
                ])
                CommunityPublisherRow(id: .unknown, displayName: "Sample User", isMine: true)
                    .padding()
                    .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                CommunityNotesCard(notes: "A beautiful blue inspired by the ocean.")
                CommunitySaveButton(isEnabled: true) { true }
            }
            .padding()
        }
        .background(groupedBackground)
    }
    .previewEnvironment(hasOnyx: false)
}
#endif
#endif

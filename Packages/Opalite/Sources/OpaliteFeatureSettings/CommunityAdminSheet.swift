//
//  CommunityAdminSheet.swift
//  OpaliteFeatureSettings
//
//  Debug-build moderation: reported Community colors and palettes with clear-reports
//  and remove actions (swipe, context menu, confirmation before removal).
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct CommunityAdminSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            CommunityAdminView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            Haptics.selection()
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Content

/// One reported record, flattened so the list and the confirmation share a shape.
private struct ReportedItem: Identifiable, Equatable {
    let id: CommunityRecordID
    let type: CommunityItemType
    let name: String
    let publisherName: String
    let reportCount: Int
    let colors: [RGBA]

    var kindTitle: String {
        switch type {
        case .color: String(localized: "Color")
        case .palette: String(localized: "Palette")
        }
    }
}

struct CommunityAdminView: View {
    @Environment(CommunityModel.self) private var community
    @Environment(ToastManager.self) private var toast

    @State private var colors: [CommunityColor] = []
    @State private var palettes: [CommunityPalette] = []
    @State private var isLoading = true
    @State private var segment: CommunitySegment = .colors
    @State private var pendingRemoval: ReportedItem?

    private var items: [ReportedItem] {
        switch segment {
        case .colors:
            colors.map { ReportedItem(id: $0.id, type: .color, name: $0.displayName, publisherName: $0.publisherName, reportCount: Int($0.reportCount), colors: [$0.rgba]) }
        case .palettes:
            palettes.map { ReportedItem(id: $0.id, type: .palette, name: $0.name, publisherName: $0.publisherName, reportCount: Int($0.reportCount), colors: $0.colors.prefix(4).map(\.rgba)) }
        }
    }

    private var totalCount: Int { colors.count + palettes.count }

    var body: some View {
        Group {
            if isLoading && totalCount == 0 {
                ProgressView("Loading reports…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if totalCount == 0 {
                EmptyStateView(
                    String(localized: "No Reports"),
                    systemImage: "checkmark.shield.fill",
                    description: String(localized: "Nothing in the Community has been reported.")
                ) {
                    Button("Check Again") { Task { await load() } }
                        .glassActionButton(prominent: false)
                }
            } else {
                list
            }
        }
        .navigationTitle("Moderation")
        .navigationSubtitleIfAvailable(String(localized: "\(totalCount.formatted()) reported"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Haptics.selection()
                    Task { await load() }
                }
                .disabled(isLoading)
            }
        }
        .task { await load() }
        .confirmationDialog(
            "Remove \(pendingRemoval?.kindTitle ?? "")?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button("Remove from Community", role: .destructive) {
                Task { await remove(item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("This permanently removes “\(item.name)” by \(item.publisherName) from the Community.")
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(items) { item in
                    ReportedRow(item: item)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await clear(item) }
                            } label: {
                                Label("Clear Reports", systemImage: "checkmark.shield")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingRemoval = item
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                Task { await clear(item) }
                            } label: {
                                Label("Clear Reports", systemImage: "checkmark.shield")
                            }
                            Button(role: .destructive) {
                                pendingRemoval = item
                            } label: {
                                Label("Remove \(item.kindTitle)", systemImage: "trash")
                            }
                            .destructiveMenuItem()
                        }
                }
            } header: {
                Picker("Content", selection: $segment) {
                    ForEach(CommunitySegment.allCases) { segment in
                        Text("\(segment.title) (\(count(for: segment).formatted()))").tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .padding(.bottom, Brand.Space.sm)
            }
        }
        .refreshable { await load() }
        .animation(.default, value: items)
    }

    private func count(for segment: CommunitySegment) -> Int {
        switch segment {
        case .colors: colors.count
        case .palettes: palettes.count
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        let reported = await community.reportedContent()
        colors = reported.colors
        palettes = reported.palettes
        isLoading = false
    }

    private func clear(_ item: ReportedItem) async {
        guard await community.clearReports(id: item.id) else { return }
        toast.showSuccess(String(localized: "Reports cleared"), systemImage: "checkmark.shield.fill")
        await load()
    }

    private func remove(_ item: ReportedItem) async {
        guard await community.removeEntity(id: item.id, type: item.type) else { return }
        toast.showSuccess(String(localized: "Removed from the Community"), systemImage: "trash.fill")
        await load()
    }
}

// MARK: - Row

private struct ReportedRow: View {
    let item: ReportedItem

    @ScaledMetric(relativeTo: .body) private var thumbnail: CGFloat = 48

    var body: some View {
        HStack(spacing: Brand.Space.md) {
            HStack(spacing: 2) {
                ForEach(Array(item.colors.enumerated()), id: \.offset) { _, rgba in
                    Rectangle().fill(rgba.color)
                }
            }
            .frame(width: thumbnail, height: thumbnail)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("By \(item.publisherName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(item.reportCount.formatted()) reports", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Brand.Space.xs)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Moderation") {
    CommunityAdminSheet()
        .settingsPreviewEnvironment()
}
#endif
#endif

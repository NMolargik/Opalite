//
//  PaletteDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData

struct PaletteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"

    @State private var showDeleteConfirmation = false
    @State private var isEditingName: Bool? = false
    @State private var notesDraft: String = ""
    @State private var isSavingNotes: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingColorEditor: Bool = false

    // Tabbed content selection
    @State private var selectedTab: PaletteDetailTab = .colors

    private enum PaletteDetailTab: String, CaseIterable {
        case colors = "Components"
        case info = "Info"
        case notes = "Notes"

        var icon: String {
            switch self {
            case .colors: return "swatchpalette"
            case .info: return "info.circle"
            case .notes: return "note.text"
            }
        }
    }

    let palette: OpalitePalette

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Hero Preview
                PalettePreviewView(
                    palette: palette,
                    isEditingName: $isEditingName
                )
                .padding(.horizontal)
                .padding(.top)

                // MARK: - Tab Selector
                tabSelector
                    .padding(.top, 16)

                // MARK: - Tab Content
                tabContent
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            notesDraft = palette.notes ?? ""
            colorManager.activePalette = palette
        }
        .onDisappear {
            colorManager.activePalette = nil
        }
        .onChange(of: colorManager.renamePaletteTrigger) { _, newValue in
            if newValue != nil {
                colorManager.renamePaletteTrigger = nil
                withAnimation {
                    isEditingName = true
                }
            }
        }
        .navigationTitle("Palette")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingExportSheet) {
            PaletteExportSheet(palette: palette)
        }
        .alert("Delete \(palette.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }

            Button("Delete Palette", role: .destructive) {
                HapticsManager.shared.selection()
                dismiss()

                do {
                    try colorManager.deletePalette(palette, andColors: false)
                } catch {
                    toastManager.show(error: .paletteDeletionFailed)
                }
            }

            if !(palette.colors?.isEmpty ?? false) {
                Button("Delete Palette and Colors", role: .destructive) {
                    HapticsManager.shared.selection()
                    dismiss()

                    do {
                        try colorManager.deletePalette(palette, andColors: true)
                    } catch {
                        toastManager.show(error: .paletteDeletionFailed)
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .toolbar {
            // Export button first for priority
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingExportSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .disabled(palette.sortedColors.isEmpty)
                .accessibilityLabel("Export palette")
                .accessibilityHint("Opens export options for this palette")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Label("Add Color", systemImage: "plus.square.dashed")
                }
                .tint(.blue)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    withAnimation {
                        isEditingName = true
                    }
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
                .toolbarButtonTint()
            }

            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    HapticsManager.shared.selection()
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
                .tint(.red)
            }
        }
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .fullScreenCover(isPresented: $isShowingColorEditor) {
            ColorEditorView(
                color: nil,
                palette: palette,
                onCancel: {
                    isShowingColorEditor = false
                },
                onApprove: { newColor in
                    do {
                        let createdColor = try colorManager.createColor(existing: newColor)
                        colorManager.attachColor(createdColor, to: palette)
                    } catch {
                        toastManager.show(error: .colorCreationFailed)
                    }

                    isShowingColorEditor = false
                }
            )
        }
    }

    // MARK: - Tab Selector

    @ViewBuilder
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(PaletteDetailTab.allCases, id: \.self) { tab in
                Button {
                    HapticsManager.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.subheadline)
                        Text(tab.rawValue)
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(.purple.opacity(0.9))
                                .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.fill.tertiary, in: Capsule())
        .padding(.horizontal)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .colors:
            colorsTab
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .info:
            infoTab
                .transition(.opacity)
        case .notes:
            notesTab
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Colors Tab

    @ViewBuilder
    private var colorsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaletteMembersView(palette: palette, onRemoveColor: { color in
                withAnimation {
                    colorManager.detachColorFromPalette(color)
                }
            })
        }
        .padding(.horizontal)
    }

    // MARK: - Info Tab

    @ViewBuilder
    private var infoTab: some View {
        VStack(spacing: 16) {
            // Palette stats card
            VStack(spacing: 0) {
                infoRow(icon: "swatchpalette", label: "Colors", value: "\(palette.sortedColors.count)", showDivider: true)
                infoRow(icon: "person", label: "Created By", value: palette.createdByDisplayName ?? "—", showDivider: false)
            }
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Metadata card
            VStack(spacing: 0) {
                infoRow(icon: "calendar", label: "Created", value: formatted(palette.createdAt), showDivider: true)
                infoRow(icon: "clock.arrow.circlepath", label: "Updated", value: formatted(palette.updatedAt), showDivider: false)
            }
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Color breakdown if there are colors
            if !palette.sortedColors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color Distribution")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // Mini color bar showing all colors
                    HStack(spacing: 2) {
                        ForEach(palette.sortedColors) { color in
                            Rectangle()
                                .fill(color.swiftUIColor)
                        }
                    }
                    .frame(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .padding()

            if showDivider {
                Divider()
                    .padding(.leading, 48)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: - Notes Tab

    @ViewBuilder
    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotesSectionView(
                notes: $notesDraft,
                isSaving: $isSavingNotes,
                onSave: {
                    isSavingNotes = true
                    defer { isSavingNotes = false }

                    do {
                        try colorManager.updatePalette(palette) { pal in
                            let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            pal.notes = trimmed.isEmpty ? nil : trimmed
                        }
                    } catch {
                        toastManager.show(error: .paletteUpdateFailed)
                    }
                }
            )
        }
        .padding(.horizontal)
    }
}

#Preview("Palette Detail") {
    // In-memory SwiftData container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    do {
        try manager.loadSamples()
    } catch {
        print("Failed to load samples into context")
    }

    return NavigationStack {
        PaletteDetailView(palette: OpalitePalette.sample)
            .environment(manager)
            .environment(ToastManager())
            .environment(SubscriptionManager())
    }
}

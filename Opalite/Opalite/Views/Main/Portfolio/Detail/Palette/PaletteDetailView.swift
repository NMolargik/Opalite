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
    @State private var isShowingFullScreen: Bool = false
    @State private var showFullScreenControls: Bool = false
    @State private var currentColorIndex: Int = 0
    @State private var lastSqueezeTime: Date = .distantPast
    @State private var lastDoubleTapTime: Date = .distantPast

    @Namespace private var heroNamespace

    let palette: OpalitePalette

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Preview
                    PalettePreviewView(
                        palette: palette,
                        isEditingName: $isEditingName
                    )
                    .opacity(isShowingFullScreen ? 0 : 1)
                    .padding(.horizontal)
                    .padding(.top)
                    .overlay(alignment: .bottom) {
                        PaletteInfoTilesRow(palette: palette)
                            .padding(.horizontal, 30)
                            .offset(y: 45)
                            .zIndex(1)
                            .opacity(isShowingFullScreen ? 0 : 1)
                    }

                    Spacer(minLength: 80)

                    // MARK: - Content Sections
                    VStack(spacing: 20) {
                        // Notes section
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
                    .opacity(isShowingFullScreen ? 0 : 1)
                    .padding(.horizontal)
                    .padding(.top, -20)
                    .padding(.bottom, 24)
                }
            }
            .scrollDisabled(isShowingFullScreen)

            // MARK: - Full Screen Overlay
            if isShowingFullScreen {
                fullScreenOverlay
                    .ignoresSafeArea()

            }
        }
        .toolbar(isShowingFullScreen ? .hidden : .automatic, for: .navigationBar)
        .statusBarHidden(isShowingFullScreen)
        .onAppear {
            notesDraft = palette.notes ?? ""
            colorManager.activePalette = palette
        }
        .onDisappear {
            colorManager.activePalette = nil
            if isShowingFullScreen {
                isShowingFullScreen = false
                showFullScreenControls = false
            }
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
            // Full screen button
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        isShowingFullScreen = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullScreenControls = true
                        }
                    }
                } label: {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .tint(.inverseTheme)
                .disabled(palette.sortedColors.isEmpty)
                .accessibilityLabel("View palette in full screen")
                .accessibilityHint("Shows the palette colors in full screen view")
            }

            // Export button first for priority
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingExportSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .disabled(palette.sortedColors.isEmpty)
                .accessibilityLabel("Share palette")
                .accessibilityHint("Opens share options for this palette")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Label("Add Color", systemImage: "plus.square.dashed")
                }
            }
            
            // Ellipsis menu with palette info and actions
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticsManager.shared.selection()
                        duplicatePalette()
                    } label: {
                        Label("Duplicate Palette", systemImage: "plus.square.on.square")
                    }
                    
                    Button {
                        HapticsManager.shared.selection()
                        withAnimation {
                            isEditingName = true
                        }
                    } label: {
                        Label("Rename", systemImage: "character.cursor.ibeam")
                    }
                    
                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .toolbarButtonTint()
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

    // MARK: - Full Screen Overlay

    private var fullScreenOverlay: some View {
        TabView(selection: $currentColorIndex) {
            ForEach(Array(palette.sortedColors.enumerated()), id: \.element.id) { index, color in
                SwatchView(
                    color: color,
                    cornerRadius: 0,
                    showBorder: false,
                    badgeText: "",
                    showOverlays: false
                )
                .ignoresSafeArea()
                .onPencilDoubleTap { _ in
                    handlePencilDoubleTap()
                }
                .onPencilSqueeze { phase in
                    switch phase {
                    case .active:
                        handlePencilSqueeze()
                    case .ended:
                        break
                    case .failed:
                        break
                    }
                }
                .overlay {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // Left half - go to previous
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    goToPreviousColor()
                                }
                            
                            // Right half - go to next
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    goToNextColor()
                                }
                        }
                    }
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Spacer()
                            
                            Text(color.name ?? color.hexString)
                                .foregroundStyle(color.idealTextColor())
                                .bold()
                                .padding(12)
                                .glassIfAvailable(
                                    GlassConfiguration(style: .clear)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                HapticsManager.shared.selection()
                                dismissFullScreen()
                            } label: {
                                Image(systemName: "arrow.up.right.and.arrow.down.left")
                                    .foregroundStyle(color.idealTextColor())
                                    .bold()
                                    .font(.title2)
                                    .padding(12)
                                    .glassIfAvailable()
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            Spacer()
                            customPageIndicator(for: color)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                    .opacity(showFullScreenControls ? 1 : 0)
                    .allowsHitTesting(true)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func goToPreviousColor() {
        HapticsManager.shared.selection()
        withAnimation {
            if currentColorIndex > 0 {
                currentColorIndex -= 1
            }
        }
    }
    
    private func goToNextColor() {
        HapticsManager.shared.selection()
        withAnimation {
            if currentColorIndex < palette.sortedColors.count - 1 {
                currentColorIndex += 1
            }
        }
    }
    
    private func handlePencilSqueeze() {
        let now = Date()
        let timeSinceLastSqueeze = now.timeIntervalSince(lastSqueezeTime)
        
        // Debounce: only allow one squeeze action per 0.5 seconds
        guard timeSinceLastSqueeze > 0.5 else { return }
        
        lastSqueezeTime = now
        goToNextColor()
    }
    
    private func handlePencilDoubleTap() {
        let now = Date()
        let timeSinceLastDoubleTap = now.timeIntervalSince(lastDoubleTapTime)
        
        // Debounce: only allow one double-tap action per 0.3 seconds
        guard timeSinceLastDoubleTap > 0.3 else { return }
        
        lastDoubleTapTime = now
        goToPreviousColor()
    }
    
    private func customPageIndicator(for color: OpaliteColor) -> some View {
        Text("\(currentColorIndex + 1) of \(palette.sortedColors.count)")
            .foregroundStyle(color.idealTextColor())
            .font(.subheadline)
            .bold()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassIfAvailable(
                GlassConfiguration(style: .clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func dismissFullScreen() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showFullScreenControls = false
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            isShowingFullScreen = false
        }
    }

    // MARK: - Helper Functions

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func duplicatePalette() {
        do {
            let newPalette = try colorManager.createPalette(name: "\(palette.name) Copy")
            // Copy colors to the new palette
            for color in palette.sortedColors {
                let newColor = try colorManager.createColor(
                    name: color.name,
                    notes: color.notes,
                    device: color.createdOnDeviceName,
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: color.alpha,
                    palette: newPalette
                )
                colorManager.attachColor(newColor, to: newPalette)
            }
        } catch {
            toastManager.show(error: .paletteCreationFailed)
        }
    }
}

// MARK: - Palette Info Tiles Row

private struct PaletteInfoTilesRow: View {
    @Bindable var palette: OpalitePalette

    var body: some View {
        HStack(spacing: 12) {
            InfoTileView(
                icon: "swatchpalette.fill",
                value: "\(palette.sortedColors.count)",
                label: "Colors",
                maxWidth: 200,
                glassStyle: .regular
            )

            InfoTileView(
                icon: "person.fill",
                value: palette.createdByDisplayName ?? "Unknown",
                label: "Created By",
                maxWidth: 200,
                glassStyle: .regular
            )

            InfoTileView(
                icon: "clock.fill",
                value: formattedShortDate(palette.updatedAt),
                label: "Updated On",
                maxWidth: 200,
                glassStyle: .regular
            )
        }
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
            .environment(HexCopyManager())
    }
}

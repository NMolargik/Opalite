//
//  ColorDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#endif

struct ColorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(HexCopyManager.self) private var hexCopyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var viewModel: ColorDetailView.ViewModel

    @State private var showDeleteConfirmation = false
    @State private var isShowingColorEditor = false
    @State private var isEditingName: Bool? = false
    @State private var didCopyHex: Bool = false
    @State private var isShowingPaywall: Bool = false
    @State private var isShowingContrastChecker: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingPaletteSheet: Bool = false

    // Tabbed content selection
    @State private var selectedTab: ColorDetailTab = .harmonies

    // Smart color naming
    @State private var nameSuggestionService = ColorNameSuggestionService()

    private enum ColorDetailTab: String, CaseIterable {
        case harmonies = "Harmonies"
        case info = "Info"
        case notes = "Notes"

        var icon: String {
            switch self {
            case .harmonies: return "paintpalette"
            case .info: return "info.circle"
            case .notes: return "note.text"
            }
        }
    }

    let color: OpaliteColor

    init(color: OpaliteColor) {
        self.color = color
        _viewModel = State(wrappedValue: ColorDetailView.ViewModel.init(color: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Hero Swatch
                SwatchView(
                    color: color,
                    height: 220,
                    badgeText: viewModel.badgeText,
                    showOverlays: true,
                    isEditingBadge: $isEditingName,
                    saveBadge: { newName in
                        viewModel.rename(to: newName, using: colorManager) { error in
                            toastManager.show(error: error)
                        }
                        nameSuggestionService.clearSuggestions()
                    },
                    allowBadgeTapToEdit: true,
                    nameSuggestions: nameSuggestionService.suggestions,
                    isLoadingSuggestions: nameSuggestionService.isGenerating,
                    onSuggestionSelected: { suggestion in
                        viewModel.rename(to: suggestion, using: colorManager) { error in
                            toastManager.show(error: error)
                        }
                        nameSuggestionService.clearSuggestions()
                        withAnimation(.easeInOut) {
                            isEditingName = false
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.top)
                .onChange(of: isEditingName) { _, newValue in
                    if newValue == true && nameSuggestionService.isAvailable {
                        Task {
                            await nameSuggestionService.generateSuggestions(for: color)
                        }
                    } else if newValue == false {
                        nameSuggestionService.clearSuggestions()
                    }
                }

                // MARK: - Tab Selector
                tabSelector
                    .padding(.top, 16)

                // MARK: - Tab Content
                tabContent
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete \(color.name ?? color.hexString)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            Button("Delete", role: .destructive) {
                HapticsManager.shared.selection()
                do {
                    try viewModel.deleteColor(using: colorManager)
                    dismiss()
                } catch {
                    toastManager.show(error: .colorDeletionFailed)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $isShowingColorEditor) {
            ColorEditorView(
                color: color,
                palette: color.palette,
                onCancel: {
                    isShowingColorEditor = false
                },
                onApprove: { updatedColor in
                    viewModel.applyEditorUpdate(from: updatedColor, using: colorManager) { error in
                        toastManager.show(error: error)
                    }
                    isShowingColorEditor.toggle()
                }
            )
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Data file export requires Onyx")
        }
        .sheet(isPresented: $isShowingContrastChecker) {
            ColorContrastCheckerView(sourceColor: color)
                .environment(colorManager)
        }
        .sheet(isPresented: $isShowingExportSheet) {
            ColorExportSheet(color: color)
        }
        .sheet(isPresented: $isShowingPaletteSheet) {
            PaletteSelectionSheet(color: color)
        }
        .toolbar {
            // Primary actions - stay visible
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingExportSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .accessibilityLabel("Export color")
                .accessibilityHint("Opens export options for this color")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.below.square.and.square.filled")
                }
                .toolbarButtonTint()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingContrastChecker = true
                } label: {
                    Label("Contrast", systemImage: "circle.righthalf.filled")
                }
                .toolbarButtonTint()
                .accessibilityLabel("Check WCAG contrast")
                .accessibilityHint("Opens contrast checker to compare this color against others")
            }

            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    hexCopyManager.copyHex(for: color)
                    withAnimation(.easeIn(duration: 0.15)) {
                        didCopyHex = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            didCopyHex = false
                        }
                    }
                } label: {
                    Label(
                        didCopyHex ? "Copied" : "Copy Hex",
                        systemImage: didCopyHex ? "checkmark" : "number"
                    )
                }
                .tint(didCopyHex ? .green : .inverseTheme)
                .accessibilityLabel(didCopyHex ? "Copied to clipboard" : "Copy hex code")
                .accessibilityValue(hexCopyManager.formattedHex(for: color))
            }

            // Secondary actions - collapse first
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingPaletteSheet = true
                } label: {
                    Label("Move to Palette", systemImage: "swatchpalette.fill")
                }
                .toolbarButtonTint()
            }

            ToolbarItem(placement: .secondaryAction) {
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

            ToolbarItem(placement: .secondaryAction) {
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
        .onAppear {
            colorManager.activeColor = color
        }
        .onDisappear {
            colorManager.activeColor = nil
        }
        .onChange(of: colorManager.editColorTrigger) { _, newValue in
            if newValue != nil {
                colorManager.editColorTrigger = nil
                isShowingColorEditor = true
            }
        }
    }

    // MARK: - Tab Selector

    @ViewBuilder
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ColorDetailTab.allCases, id: \.self) { tab in
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
                                .fill(color.swiftUIColor.opacity(0.9))
                                .shadow(color: color.swiftUIColor.opacity(0.3), radius: 8, y: 4)
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
        case .harmonies:
            harmoniesTab
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

    // MARK: - Harmonies Tab

    @ViewBuilder
    private var harmoniesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            ColorRecommendedColorsView(
                baseColor: color,
                onCreateColor: { suggested in
                    do {
                        _ = try colorManager.createColor(
                            name: nil,
                            notes: suggested.notes,
                            device: nil,
                            red: suggested.red,
                            green: suggested.green,
                            blue: suggested.blue,
                            alpha: suggested.alpha,
                            palette: color.palette
                        )
                    } catch {
                        toastManager.show(error: .colorCreationFailed)
                    }
                }
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Info Tab

    @ViewBuilder
    private var infoTab: some View {
        VStack(spacing: 16) {
            // Color values card
            VStack(spacing: 0) {
                infoRow(icon: "number", label: "Hex", value: color.hexString, showDivider: true)
                infoRow(icon: "slider.horizontal.3", label: "RGB", value: color.rgbString, showDivider: true)
                infoRow(icon: "circle.lefthalf.filled", label: "HSL", value: color.hslString, showDivider: false)
            }
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Metadata card
            VStack(spacing: 0) {
                infoRow(icon: "person", label: "Created By", value: color.createdByDisplayName ?? "—", showDivider: true)
                infoRow(icon: DeviceKind.from(color.createdOnDeviceName).symbolName, label: "Device", value: color.createdOnDeviceName ?? "—", showDivider: true)
                infoRow(icon: "calendar", label: "Created", value: formatted(color.createdAt), showDivider: true)
                infoRow(icon: "clock.arrow.circlepath", label: "Updated", value: formatted(color.updatedAt), showDivider: false)
            }
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if let palette = color.palette {
                // Palette membership card
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "swatchpalette.fill")
                            .foregroundStyle(.purple)
                            .frame(width: 24)
                        Text("In Palette")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(palette.name)
                            .fontWeight(.medium)
                    }
                    .padding()
                }
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
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
                notes: $viewModel.notesDraft,
                isSaving: $viewModel.isSavingNotes,
                onSave: {
                    viewModel.saveNotes(using: colorManager) { error in
                        toastManager.show(error: error)
                    }
                }
            )
        }
        .padding(.horizontal)
    }
}

#Preview("Color Detail") {
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
        ColorDetailView(color: OpaliteColor.sample)
    }
    .environment(manager)
    .environment(ToastManager())
    .environment(SubscriptionManager())
    .environment(HexCopyManager())
    .modelContainer(container)
}

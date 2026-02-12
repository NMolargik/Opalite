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

    @Namespace private var heroNamespace

    @State private var viewModel: ColorDetailView.ViewModel

    @State private var showDeleteConfirmation = false
    @State private var isShowingColorEditor = false
    @State private var isEditingName: Bool? = false
    @State private var didCopyHex: Bool = false
    @State private var isShowingPaywall: Bool = false
    @State private var isShowingContrastChecker: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingPaletteSheet: Bool = false
    @State private var isShowingFullScreen: Bool = false
    @State private var showFullScreenControls: Bool = false

    // Smart color naming
    @State private var nameSuggestionService = ColorNameSuggestionService()

    let color: OpaliteColor

    init(color: OpaliteColor) {
        self.color = color
        _viewModel = State(wrappedValue: ColorDetailView.ViewModel.init(color: color))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Swatch
                    SwatchView(
                        color: color,
                        height: 220,
                        badgeText: viewModel.badgeText,
                        showOverlays: !isShowingFullScreen,
                        isEditingBadge: $isEditingName,
                        saveBadge: { newName in
                            viewModel.rename(to: newName, using: colorManager) { error in
                                toastManager.show(error: error)
                            }
                            nameSuggestionService.clearSuggestions()
                        },
                        allowBadgeTapToEdit: true,
                        matchedNamespace: heroNamespace,
                        matchedID: "heroSwatch",
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
                    .opacity(isShowingFullScreen ? 0 : 1)
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
                    .overlay(alignment: .bottom) {
                        InfoTilesRow(color: color)
                            .padding(.horizontal, 30)
                            .offset(y: 45)
                            .zIndex(1)
                            .opacity(isShowingFullScreen ? 0 : 1)
                    }

                    Spacer(minLength: 80)

                    // MARK: - Content Sections
                    VStack(spacing: 20) {
                        ColorHarmonyWheelView(
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
            }
        }
        .toolbar(isShowingFullScreen ? .hidden : .automatic, for: .navigationBar)
        .statusBarHidden(isShowingFullScreen)
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
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .accessibilityLabel("Share color")
                .accessibilityHint("Opens share options for this color")
            }
            
            ToolbarItem(placement:.topBarTrailing) {
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
                .accessibilityLabel("View color in full screen")
                .accessibilityHint("Shows the color in full screen view")
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Label("Edit Color", systemImage: "slider.horizontal.below.square.and.square.filled")
                }
                .toolbarButtonTint()
                
                Button {
                    HapticsManager.shared.selection()
                    isShowingPaletteSheet = true
                } label: {
                    Label("Move To Palette", systemImage: "swatchpalette.fill")
                }
            }

            // Info menu with color values and actions
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Color values section - copyable
                    Section("Color Values") {
                        Button {
                            HapticsManager.shared.selection()
                            hexCopyManager.copyHex(for: color)
                            toastManager.show(message: "Code Copied", style: .success)
                        } label: {
                            Label(color.hexString, systemImage: "number")
                        }
                        
                        Button {
                            HapticsManager.shared.selection()
                            copyToClipboard(color.rgbString)
                            toastManager.show(message: "Code Copied", style: .success)
                        } label: {
                            Label(color.rgbString, systemImage: "slider.horizontal.3")
                        }
                        
                        Button {
                            HapticsManager.shared.selection()
                            copyToClipboard(color.hslString)
                            toastManager.show(message: "Code Copied", style: .success)
                        } label: {
                            Label(color.hslString, systemImage: "circle.lefthalf.filled")
                        }
                    }
                    
                    Section {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingContrastChecker = true
                        } label: {
                            Label("Check Contrast", systemImage: "circle.righthalf.filled")
                        }
                        .toolbarButtonTint()
                        .accessibilityLabel("Check WCAG contrast")
                        .accessibilityHint("Opens contrast checker to compare this color against others")
                        
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
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .toolbarButtonTint()
            }
        }
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .onAppear {
            colorManager.activeColor = color
        }
        .onDisappear {
            colorManager.activeColor = nil
            if isShowingFullScreen {
                isShowingFullScreen = false
                showFullScreenControls = false
            }
        }
        .onChange(of: colorManager.editColorTrigger) { _, newValue in
            if newValue != nil {
                colorManager.editColorTrigger = nil
                isShowingColorEditor = true
            }
        }
    }

    private var fullScreenOverlay: some View {
        SwatchView(
            color: color,
            cornerRadius: 0,
            showBorder: false,
            badgeText: "",
            showOverlays: false,
            matchedNamespace: heroNamespace,
            matchedID: "heroSwatch"
        )
        .onTapGesture {
            dismissFullScreen()
        }
        .overlay(alignment: .top) {
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
            }
            .padding()
            .opacity(showFullScreenControls ? 1 : 0)
        }
        .ignoresSafeArea()
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

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Info Tiles Row

private struct InfoTilesRow: View {
    let color: OpaliteColor

    var body: some View {
        HStack(spacing: 12) {
            InfoTileView(
                icon: "person.fill",
                value: color.createdByDisplayName ?? "Unknown",
                label: "Created By",
                glassStyle: .regular
            )

            InfoTileView(
                icon: DeviceKind.from(color.createdOnDeviceName).symbolName,
                value: shortDeviceName(color.createdOnDeviceName),
                label: "Created On",
                glassStyle: .regular

            )

            InfoTileView(
                icon: "clock.fill",
                value: formattedShortDate(color.updatedAt),
                label: "Updated On",
                glassStyle: .regular

            )
        }
    }

    private func shortDeviceName(_ name: String?) -> String {
        guard let name = name else { return "—" }
        // Shorten common device names
        if name.lowercased().contains("iphone") {
            return "iPhone"
        } else if name.lowercased().contains("ipad") {
            return "iPad"
        } else if name.lowercased().contains("mac") {
            return "Mac"
        }
        return name
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Harmonies Row

private struct HarmoniesRow: View {
    @Environment(HexCopyManager.self) private var hexCopyManager

    let baseColor: OpaliteColor
    let onCreateColor: (OpaliteColor) -> Void

    @State private var isShowingInfo = false
    @State private var actionFeedbackColorID: UUID?
    @State private var harmonyColors: [OpaliteColor] = []

    var body: some View {
        SectionCard(title: "Harmonies", systemImage: "paintpalette") {
            SwatchRowView(
                colors: harmonyColors,
                palette: nil,
                swatchWidth: 180,
                swatchHeight: 150,
                showOverlays: true,
                showsNavigation: false,
                acceptsDrops: false,
                menuContent: { color in
                    harmonyMenuContent(for: color)
                },
                contextMenuContent: { color in
                    harmonyMenuContent(for: color)
                },
                copiedColorID: $actionFeedbackColorID
            )
            .clipped()
        } trailing: {
            Button {
                HapticsManager.shared.selection()
                isShowingInfo = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Learn about color harmonies")
        }
        .sheet(isPresented: $isShowingInfo) {
            ColorHarmoniesInfoSheet()
        }
        .onAppear {
            if harmonyColors.isEmpty {
                harmonyColors = buildHarmonyColors()
            }
        }
    }

    private func harmonyMenuContent(for color: OpaliteColor) -> AnyView {
        AnyView(
            Group {
                Button {
                    HapticsManager.shared.selection()
                    hexCopyManager.copyHex(for: color)
                    withAnimation {
                        actionFeedbackColorID = color.id
                    }
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }

                Button {
                    HapticsManager.shared.selection()
                    onCreateColor(color)
                    withAnimation {
                        actionFeedbackColorID = color.id
                    }
                } label: {
                    Label(
                        baseColor.palette != nil ? "Add To Palette" : "Save To Colors",
                        systemImage: "plus"
                    )
                }
            }
        )
    }

    private func buildHarmonyColors() -> [OpaliteColor] {
        var colors: [OpaliteColor] = []

        // Complementary (1)
        colors.append(baseColor.complementaryColor())

        // Analogous (2)
        colors.append(contentsOf: baseColor.analogousColors())

        // Triadic (2)
        colors.append(contentsOf: baseColor.triadicColors())

        // Split-Complementary (2)
        colors.append(contentsOf: baseColor.splitComplementaryColors())

        // Tetradic (3)
        colors.append(contentsOf: baseColor.tetradicColors())

        return colors
    }
}

// MARK: - Color Harmonies Info Sheet

struct ColorHarmoniesInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Color harmonies are combinations of colors that are aesthetically pleasing and work well together. They're based on the position of colors on the color wheel.")
                        .foregroundStyle(.secondary)

                    harmonySection(
                        name: "Complementary",
                        icon: "circle.lefthalf.filled",
                        color: .red,
                        description: "Colors directly opposite each other on the color wheel (180° apart). Creates high contrast and visual tension.",
                        example: "Red & Green, Blue & Orange"
                    )

                    harmonySection(
                        name: "Analogous",
                        icon: "circle.and.line.horizontal",
                        color: .orange,
                        description: "Colors adjacent to each other on the wheel (±30°). Creates a harmonious, cohesive feel with low contrast.",
                        example: "Blue, Blue-Green, Green"
                    )

                    harmonySection(
                        name: "Triadic",
                        icon: "triangle",
                        color: .yellow,
                        description: "Three colors evenly spaced on the wheel (120° apart). Offers strong visual contrast while retaining balance.",
                        example: "Red, Yellow, Blue"
                    )

                    harmonySection(
                        name: "Split-Complementary",
                        icon: "arrow.triangle.branch",
                        color: .green,
                        description: "A base color plus the two colors adjacent to its complement (150° & 210°). High contrast but less tension than complementary.",
                        example: "Blue, Yellow-Orange, Red-Orange"
                    )

                    harmonySection(
                        name: "Tetradic (Square)",
                        icon: "square",
                        color: .blue,
                        description: "Four colors evenly spaced on the wheel (90° apart). Rich color palette that works best when one color dominates.",
                        example: "Red, Yellow, Green, Blue"
                    )
                }
                .padding()
            }
            .navigationTitle("Color Harmonies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func harmonySection(
        name: String,
        icon: String,
        color: Color,
        description: String,
        example: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)

                Text(name)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("Example: \(example)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
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

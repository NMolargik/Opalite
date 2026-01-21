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

    // Smart color naming
    @State private var nameSuggestionService = ColorNameSuggestionService()

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
                .overlay(alignment: .bottom) {
                    InfoTilesRow(color: color)
                        .padding(.horizontal, 30)
                        .offset(y: 45)
                        .zIndex(1)
                }
                
                Spacer(minLength: 80)

                // MARK: - Content Sections
                VStack(spacing: 20) {
                    HarmoniesRow(
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
                .padding(.horizontal)
                .padding(.top, -20)
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
            
            ToolbarItem(placement:.topBarTrailing) {
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
                    Button {
                        HapticsManager.shared.selection()
                        isShowingContrastChecker = true
                    } label: {
                        Label("Check Contrast", systemImage: "circle.righthalf.filled")
                    }
                    .toolbarButtonTint()
                    .accessibilityLabel("Check WCAG contrast")
                    .accessibilityHint("Opens contrast checker to compare this color against others")
                    
                    // Color values section - copyable
                    Section("Color Values") {
                        Button {
                            HapticsManager.shared.selection()
                            hexCopyManager.copyHex(for: color)
                        } label: {
                            Label(color.hexString, systemImage: "number")
                        }

                        Button {
                            HapticsManager.shared.selection()
                            copyToClipboard(color.rgbString)
                        } label: {
                            Label(color.rgbString, systemImage: "slider.horizontal.3")
                        }

                        Button {
                            HapticsManager.shared.selection()
                            copyToClipboard(color.hslString)
                        } label: {
                            Label(color.hslString, systemImage: "circle.lefthalf.filled")
                        }
                    }

                    Section {
                        Button {
                            HapticsManager.shared.selection()
                            withAnimation {
                                isEditingName = true
                            }
                        } label: {
                            Label("Rename", systemImage: "character.cursor.ibeam")
                        }
                    }

                    Section {
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
        }
        .onChange(of: colorManager.editColorTrigger) { _, newValue in
            if newValue != nil {
                colorManager.editColorTrigger = nil
                isShowingColorEditor = true
            }
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

// MARK: - Info Tile View

private struct InfoTileView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(height: 30)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: 200, maxHeight: 85)
        .modifier(GlassTileBackground())
    }
}

private struct GlassTileBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 5)

        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .shadow(radius: 5)
                )
        }
    }
}

// MARK: - Info Tiles Row

private struct InfoTilesRow: View {
    let color: OpaliteColor

    var body: some View {
        HStack(spacing: 12) {
            InfoTileView(
                icon: "person.fill",
                iconColor: .orange,
                value: color.createdByDisplayName ?? "Unknown",
                label: "Created By"
            )

            InfoTileView(
                icon: DeviceKind.from(color.createdOnDeviceName).symbolName,
                iconColor: .secondary,
                value: shortDeviceName(color.createdOnDeviceName),
                label: "Created On"
            )

            InfoTileView(
                icon: "clock.fill",
                iconColor: .indigo,
                value: formattedShortDate(color.updatedAt),
                label: "Updated On"
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
                        baseColor.palette != nil ? "Add To Palette" : "Save to Colors",
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

private struct ColorHarmoniesInfoSheet: View {
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

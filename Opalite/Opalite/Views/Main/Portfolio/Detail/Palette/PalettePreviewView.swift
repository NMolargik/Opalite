//
//  PalettePreviewView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/2/26.
//

import SwiftUI
import SwiftData

struct PalettePreviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(HexCopyManager.self) private var hexCopyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var palette: OpalitePalette
    @Binding var isEditingName: Bool?

    @State private var editedName: String = ""
    @FocusState private var nameFocused: Bool
    @State private var isShowingBackgroundPicker: Bool = false

    // Cached values to survive context resets
    @State private var cachedBackground: PreviewBackground?
    @State private var cachedColors: [OpaliteColor] = []
    @State private var cachedName: String = ""

    // Track which color was copied for feedback
    @State private var copiedColorID: UUID?

    private let padding: CGFloat = 16
    private let mediumSwatchSize: CGFloat = 150

    /// The current background, falling back to theme-appropriate default
    private var currentBackground: PreviewBackground {
        cachedBackground ?? PreviewBackground.defaultFor(colorScheme: colorScheme)
    }

    private let verticalPadding: CGFloat = 50  // Space for badges
    private let spacing: CGFloat = 12

    // State to track measured width for column calculation
    @State private var measuredWidth: CGFloat = 0

    private var columns: Int {
        let availableWidth = measuredWidth - (padding * 2)
        return max(1, Int(availableWidth / (mediumSwatchSize + spacing)))
    }

    private var calculatedHeight: CGFloat {
        let colorCount = cachedColors.count
        guard colorCount > 0 else {
            return 150  // Minimum height for empty state
        }
        let rows = Int(ceil(Double(colorCount) / Double(max(1, columns))))
        let contentHeight = CGFloat(rows) * mediumSwatchSize + CGFloat(max(0, rows - 1)) * spacing
        return contentHeight + verticalPadding * 2 + padding
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            if cachedColors.isEmpty {
                emptyStateView
            } else {
                swatchGridView(columns: columns)
            }
        }
        .frame(height: calculatedHeight)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        measuredWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        measuredWidth = newWidth
                    }
            }
        )
        .overlay(alignment: .topLeading) {
            HStack {
                nameBadge
                    .frame(maxWidth: 350, alignment: .leading)
                    .padding(10)

                Spacer()

                backgroundPickerButton
                    .padding(10)
            }
        }
        .onAppear {
            syncCache()
        }
        .onChange(of: palette.colors?.count) { _, _ in
            // Sync cache when colors are added or removed
            withAnimation {
                cachedColors = palette.sortedColors
            }
        }
        .onChange(of: isEditingName) { _, newValue in
            if newValue == true {
                editedName = cachedName
                DispatchQueue.main.async {
                    nameFocused = true
                }
            }
        }
    }

    private func syncCache() {
        // Safely sync from the palette - this is only called on appear
        cachedBackground = palette.previewBackground
        cachedColors = palette.sortedColors
        cachedName = palette.name
    }

    // MARK: - View Components

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(currentBackground.color)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.thinMaterial, lineWidth: 3)
            )
    }

    private var emptyStateView: some View {
        Text("This palette is empty")
            .foregroundStyle(currentBackground.idealTextColor.opacity(0.6))
            .font(.subheadline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func swatchGridView(columns: Int) -> some View {
        let rows = Int(ceil(Double(cachedColors.count) / Double(columns)))
        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                swatchRow(row: row, columns: columns)
            }
        }
        .padding(.top, verticalPadding + 10)
        .padding(.bottom, verticalPadding - 10)
        .padding(.horizontal, padding)
        .frame(maxWidth: .infinity)
    }

    private func swatchRow(row: Int, columns: Int) -> some View {
        let startIndex = row * columns
        let endIndex = min(startIndex + columns, cachedColors.count)

        return HStack {
            Spacer(minLength: 0)
            HStack(spacing: spacing) {
                ForEach(startIndex..<endIndex, id: \.self) { index in
                    let color = cachedColors[index]
                    NavigationLink {
                        ColorDetailView(color: color)
                    } label: {
                        swatchViewFor(color: color)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func swatchViewFor(color: OpaliteColor) -> some View {
        let isCopied = copiedColorID == color.id
        return SwatchView(
            color: color,
            width: mediumSwatchSize,
            height: mediumSwatchSize,
            badgeText: color.name ?? color.hexString,
            showOverlays: true,
            menu: AnyView(swatchMenuContent(for: color)),
            contextMenu: AnyView(swatchMenuContent(for: color)),
            showCopiedFeedback: Binding(
                get: { isCopied },
                set: { if !$0 { copiedColorID = nil } }
            )
        )
        .frame(width: mediumSwatchSize, height: mediumSwatchSize)
    }

    // MARK: - Name Badge

    @ViewBuilder
    private var nameBadge: some View {
        ZStack(alignment: .trailing) {
            if isEditingName != true {
                // Read-only state
                Text(cachedName)
                    .foregroundStyle(currentBackground.idealTextColor)
                    .bold()
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isEditingName = true
                        }
                    }
            } else {
                // Editing state
                HStack(spacing: 8) {
                    TextField("Name", text: $editedName)
                        .textFieldStyle(.plain)
                        .foregroundStyle(currentBackground.idealTextColor)
                        .bold()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit {
                            saveName()
                        }

                    Button {
                        HapticsManager.shared.selection()
                        saveName()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(.black, .green)
                    }
                    .contentShape(Circle())
                    .hoverEffect(.lift)
                }
            }
        }
        .frame(height: 20)
        .padding(8)
        .glassIfAvailable(
            GlassConfiguration(style: .clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentTransition(.interpolate)
        .animation(.bouncy, value: isEditingName)
    }

    private func saveName() {
        let finalName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalName.isEmpty && finalName != cachedName {
            // Update cache immediately for UI responsiveness
            cachedName = finalName
            do {
                try colorManager.updatePalette(palette) { pal in
                    pal.name = finalName
                }
            } catch {
                toastManager.show(error: .paletteUpdateFailed)
            }
        }
        withAnimation(.easeInOut) {
            isEditingName = false
        }
    }

    // MARK: - Background Picker Button

    @ViewBuilder
    private var backgroundPickerButton: some View {
        Menu {
            ForEach(PreviewBackground.allCases) { bg in
                Button {
                    HapticsManager.shared.selection()
                    setBackground(bg)
                } label: {
                    Label {
                        Text(bg.displayName)
                    } icon: {
                        Image(systemName: bg.iconName)
                    }
                }
            }
        } label: {
            Image(systemName: "square.2.layers.3d.bottom.filled")
                .imageScale(.medium)
                .foregroundStyle(currentBackground.idealTextColor)
                .frame(width: 8, height: 8)
                .padding(12)
                .glassIfAvailable(
                    GlassConfiguration(style: .clear)
                )
                .contentShape(Circle())
                .hoverEffect(.lift)
        }
    }

    private func setBackground(_ background: PreviewBackground) {
        // Update cache immediately before the save to prevent crashes if context resets
        cachedBackground = background
        do {
            try colorManager.updatePalette(palette) { pal in
                pal.previewBackground = background
            }
        } catch {
            toastManager.show(error: .paletteUpdateFailed)
        }
    }

    // MARK: - Swatch Menu Content

    @ViewBuilder
    private func swatchMenuContent(for color: OpaliteColor) -> some View {
        Button {
            HapticsManager.shared.selection()
            hexCopyManager.copyHex(for: color)
            withAnimation {
                copiedColorID = color.id
            }
        } label: {
            Label("Copy Hex", systemImage: "number")
        }

        Button(role: .destructive) {
            HapticsManager.shared.selection()
            withAnimation {
                colorManager.detachColorFromPalette(color)
            }
        } label: {
            Label("Remove From Palette", systemImage: "minus.circle")
        }
    }

}

#Preview("Palette Preview") {
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

    return VStack {
        PalettePreviewView(
            palette: OpalitePalette.sample,
            isEditingName: .constant(false)
        )
        .padding()

        PalettePreviewView(
            palette: OpalitePalette(name: "Empty Palette"),
            isEditingName: .constant(false)
        )
        .padding()
    }
    .environment(manager)
    .environment(ToastManager())
    .environment(HexCopyManager())
}

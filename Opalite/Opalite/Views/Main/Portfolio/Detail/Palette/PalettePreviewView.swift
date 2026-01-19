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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let palette: OpalitePalette
    @Binding var isEditingName: Bool?

    @State private var editedName: String = ""
    @FocusState private var nameFocused: Bool
    @State private var isShowingBackgroundPicker: Bool = false

    private let totalHeight: CGFloat = 300
    private let padding: CGFloat = 16
    private let spacing: CGFloat = 8

    /// The current background, falling back to theme-appropriate default
    private var currentBackground: PreviewBackground {
        palette.previewBackground ?? PreviewBackground.defaultFor(colorScheme: colorScheme)
    }

    private let extraVerticalPadding: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (padding * 2)
            let availableHeight = totalHeight - (padding * 2) - (extraVerticalPadding * 2)
            let colors = palette.sortedColors
            let layout = calculateLayout(
                colorCount: colors.count,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(currentBackground.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.thinMaterial, lineWidth: 3)
                    )

                // Color swatches grid
                if colors.isEmpty {
                    Text("This palette is empty")
                        .foregroundStyle(currentBackground.idealTextColor.opacity(0.6))
                        .font(.subheadline)
                } else {
                    VStack(spacing: layout.verticalSpacing) {
                        ForEach(0..<layout.rows, id: \.self) { row in
                            HStack(spacing: layout.horizontalSpacing) {
                                ForEach(0..<layout.columns, id: \.self) { col in
                                    let index = row * layout.columns + col
                                    if index < colors.count {
                                        let color = colors[index]
                                        SwatchView(
                                            color: color,
                                            width: layout.swatchSize,
                                            height: layout.swatchSize,
                                            badgeText: layout.showHexBadges ? (color.name ?? color.hexString) : "",
                                            showOverlays: layout.showHexBadges
                                        )
                                        .frame(width: layout.swatchSize, height: layout.swatchSize)
                                    } else {
                                        Color.clear
                                            .frame(width: layout.swatchSize, height: layout.swatchSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            nameBadge
                .frame(maxWidth: 350, alignment: .leading)
                .padding(10)
        }
        .overlay(alignment: .bottomTrailing) {
            backgroundPickerButton
                .padding(10)
        }
        .frame(height: totalHeight)
        .onChange(of: isEditingName) { _, newValue in
            if newValue == true {
                editedName = palette.name
                DispatchQueue.main.async {
                    nameFocused = true
                }
            }
        }
    }

    // MARK: - Name Badge

    @ViewBuilder
    private var nameBadge: some View {
        ZStack(alignment: .trailing) {
            if isEditingName != true {
                // Read-only state
                Text(palette.name)
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
        if !finalName.isEmpty && finalName != palette.name {
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
            Image(systemName: "paintbrush.fill")
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
        do {
            try colorManager.updatePalette(palette) { pal in
                pal.previewBackground = background
            }
        } catch {
            toastManager.show(error: .paletteUpdateFailed)
        }
    }

    // MARK: - Layout Calculation

    private struct LayoutInfo {
        let rows: Int
        let columns: Int
        let swatchSize: CGFloat
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat
        let showHexBadges: Bool
    }

    private func calculateLayout(
        colorCount: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> LayoutInfo {
        guard colorCount > 0 else {
            return LayoutInfo(rows: 0, columns: 0, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0, showHexBadges: false)
        }

        let minSpacing: CGFloat = 8
        let maxSpacing: CGFloat = 16

        var bestLayout = LayoutInfo(rows: 1, columns: 1, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0, showHexBadges: false)

        // Try different row configurations (1, 2, or 3 rows)
        for rows in 1...3 {
            let columns = Int(ceil(Double(colorCount) / Double(rows)))

            // Use fixed vertical spacing
            let verticalSpacing: CGFloat = rows > 1 ? minSpacing : 0
            let totalVerticalSpacing = CGFloat(rows - 1) * verticalSpacing

            // Calculate horizontal spacing
            let horizontalSpacing: CGFloat = columns > 1 ? minSpacing : 0
            let totalHorizontalSpacing = CGFloat(columns - 1) * maxSpacing

            // Calculate max swatch size that fits in both dimensions
            let maxHeightPerSwatch = (availableHeight - totalVerticalSpacing) / CGFloat(rows)
            let maxWidthPerSwatch = (availableWidth - totalHorizontalSpacing) / CGFloat(columns)

            // Use the smaller to ensure perfect squares
            let swatchSize = min(maxWidthPerSwatch, maxHeightPerSwatch)

            // Calculate actual horizontal spacing to distribute swatches evenly
            var actualHorizontalSpacing = horizontalSpacing
            if columns > 1 {
                let usedWidth = CGFloat(columns) * swatchSize
                actualHorizontalSpacing = (availableWidth - usedWidth) / CGFloat(columns - 1)
                // Cap at max spacing - if more space available, swatches could be bigger but we've already optimized
                actualHorizontalSpacing = min(actualHorizontalSpacing, maxSpacing)
            }

            // We want the largest possible swatch size
            if swatchSize > bestLayout.swatchSize {
                bestLayout = LayoutInfo(
                    rows: rows,
                    columns: columns,
                    swatchSize: swatchSize,
                    horizontalSpacing: actualHorizontalSpacing,
                    verticalSpacing: verticalSpacing,
                    showHexBadges: swatchSize >= 110 && horizontalSizeClass != .compact
                )
            }
        }

        return bestLayout
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
}

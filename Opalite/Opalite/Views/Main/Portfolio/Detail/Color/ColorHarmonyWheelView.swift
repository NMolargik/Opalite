//
//  ColorHarmonyWheelView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/9/26.
//

import SwiftUI

// MARK: - Harmony Type

enum HarmonyType: String, CaseIterable, Identifiable {
    case complementary = "Complementary"
    case analogous = "Analogous"
    case triadic = "Triadic"
    case splitComplementary = "Split-Comp"
    case tetradic = "Tetradic"

    var id: String { rawValue }

    /// Hue offsets in degrees from the base color
    var hueOffsets: [Double] {
        switch self {
        case .complementary:        return [180]
        case .analogous:            return [-30, 30]
        case .triadic:              return [120, 240]
        case .splitComplementary:   return [150, 210]
        case .tetradic:             return [90, 180, 270]
        }
    }

    var icon: String {
        switch self {
        case .complementary:        return "circle.lefthalf.filled"
        case .analogous:            return "circle.and.line.horizontal"
        case .triadic:              return "triangle"
        case .splitComplementary:   return "arrow.triangle.branch"
        case .tetradic:             return "square"
        }
    }
}

// MARK: - Harmony Overlay Shape

/// Draws lines connecting harmony points on the wheel.
/// Always stores 4 angles for smooth `Animatable` transitions.
/// - 2 unique points → straight line (complementary)
/// - 3 unique points → triangle
/// - 4 unique points → quadrilateral
struct HarmonyOverlayShape: Shape {
    var angle0: Double
    var angle1: Double
    var angle2: Double
    var angle3: Double
    var pointCount: Int

    var animatableData: AnimatablePair<
        AnimatablePair<Double, Double>,
        AnimatablePair<Double, Double>
    > {
        get {
            AnimatablePair(
                AnimatablePair(angle0, angle1),
                AnimatablePair(angle2, angle3)
            )
        }
        set {
            angle0 = newValue.first.first
            angle1 = newValue.first.second
            angle2 = newValue.second.first
            angle3 = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        func point(for angle: Double) -> CGPoint {
            let rad = angle * .pi / 180
            return CGPoint(
                x: center.x + radius * CGFloat(cos(rad)),
                y: center.y + radius * CGFloat(sin(rad))
            )
        }

        var path = Path()

        switch pointCount {
        case 2:
            // Line between two points
            path.move(to: point(for: angle0))
            path.addLine(to: point(for: angle1))
        case 3:
            // Triangle
            path.move(to: point(for: angle0))
            path.addLine(to: point(for: angle1))
            path.addLine(to: point(for: angle2))
            path.closeSubpath()
        default:
            // Quadrilateral
            path.move(to: point(for: angle0))
            path.addLine(to: point(for: angle1))
            path.addLine(to: point(for: angle2))
            path.addLine(to: point(for: angle3))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Color Harmony Wheel View

struct ColorHarmonyWheelView: View {
    @Environment(HexCopyManager.self) private var hexCopyManager

    let baseColor: OpaliteColor
    let onCreateColor: (OpaliteColor) -> Void

    @State private var selectedHarmony: HarmonyType = .complementary
    @State private var isShowingInfo = false

    private var baseHue: Double {
        let hsl = OpaliteColor.rgbToHSL(r: baseColor.red, g: baseColor.green, b: baseColor.blue)
        return hsl.h * 360 // degrees
    }

    /// Colors for the currently selected harmony type
    private var harmonyColors: [OpaliteColor] {
        switch selectedHarmony {
        case .complementary:
            return [baseColor.complementaryColor()]
        case .analogous:
            return baseColor.analogousColors()
        case .triadic:
            return baseColor.triadicColors()
        case .splitComplementary:
            return baseColor.splitComplementaryColors()
        case .tetradic:
            return baseColor.tetradicColors()
        }
    }

    /// All angles on the wheel (base + harmony), offset so 0° = top (12 o'clock)
    private var allAngles: [Double] {
        let base = baseHue - 90 // shift so red-at-0 maps to top
        return [base] + selectedHarmony.hueOffsets.map { base + $0 }
    }

    /// Total point count (base + harmony colors)
    private var totalPoints: Int {
        1 + selectedHarmony.hueOffsets.count
    }

    /// Padded angles array (always 4 elements) for the animatable shape
    private var paddedAngles: [Double] {
        var angles = allAngles
        while angles.count < 4 {
            angles.append(angles.last ?? 0)
        }
        return Array(angles.prefix(4))
    }

    var body: some View {
        SectionCard(title: "Harmonies", systemImage: "paintpalette", isCollapsible: true) {
            VStack(spacing: 16) {
                harmonyPicker

                wheelView
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)

                swatchRow
            }
            .padding(.horizontal, 16)
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
    }

    // MARK: - Harmony Picker

    private var harmonyPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HarmonyType.allCases) { harmony in
                    let isSelected = selectedHarmony == harmony
                    Button {
                        HapticsManager.shared.selection()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            selectedHarmony = harmony
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: harmony.icon)
                                .font(.caption)
                            Text(harmony.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .modifier(HarmonyChipBackground(
                            isSelected: isSelected,
                            tintColor: baseColor.swiftUIColor
                        ))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(harmony.rawValue) harmony")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Wheel

    private var wheelView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let ringWidth: CGFloat = 28
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            let markerRadius = size / 2 - ringWidth / 2

            ZStack {
                // Hue ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        lineWidth: ringWidth
                    )
                    .padding(ringWidth / 2)

                // Overlay shape connecting points
                HarmonyOverlayShape(
                    angle0: paddedAngles[0],
                    angle1: paddedAngles[1],
                    angle2: paddedAngles[2],
                    angle3: paddedAngles[3],
                    pointCount: totalPoints
                )
                .stroke(
                    Color.primary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .padding(ringWidth / 2)

                // Harmony markers (drawn first so base sits on top)
                ForEach(Array(selectedHarmony.hueOffsets.enumerated()), id: \.offset) { index, hueOffset in
                    let angle = (baseHue + hueOffset - 90) * .pi / 180
                    let color = harmonyColors[index]
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().stroke(.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .position(
                            x: centerX + markerRadius * cos(angle),
                            y: centerY + markerRadius * sin(angle)
                        )
                }

                // Base color marker (on top)
                Circle()
                    .fill(baseColor.swiftUIColor)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    .position(
                        x: centerX + markerRadius * cos((baseHue - 90) * .pi / 180),
                        y: centerY + markerRadius * sin((baseHue - 90) * .pi / 180)
                    )
            }
        }
    }

    // MARK: - Swatch Row

    private var swatchRow: some View {
        let showLabels = totalPoints <= 2

        return HStack(spacing: 8) {
            // Base color swatch (tap to copy)
            SwatchView(
                color: baseColor,
                height: 60,
                cornerRadius: 10,
                badgeText: baseColor.name ?? baseColor.hexString,
                showOverlays: showLabels
            )
            .onTapGesture {
                HapticsManager.shared.selection()
                hexCopyManager.copyHex(for: baseColor)
            }
            .accessibilityLabel("Base color \(baseColor.name ?? baseColor.hexString)")
            .accessibilityHint("Tap to copy hex code")

            // Harmony swatches (tap for menu)
            ForEach(Array(harmonyColors.enumerated()), id: \.element.id) { _, harmonyColor in
                Menu {
                    Button {
                        HapticsManager.shared.selection()
                        hexCopyManager.copyHex(for: harmonyColor)
                    } label: {
                        Label("Copy Hex", systemImage: "number")
                    }

                    Button {
                        HapticsManager.shared.selection()
                        onCreateColor(harmonyColor)
                    } label: {
                        Label(
                            baseColor.palette != nil ? "Add To Palette" : "Save To Colors",
                            systemImage: "plus"
                        )
                    }
                } label: {
                    SwatchView(
                        color: harmonyColor,
                        height: 60,
                        cornerRadius: 10,
                        badgeText: harmonyColor.hexString,
                        showOverlays: showLabels
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Harmony color \(harmonyColor.hexString)")
                .accessibilityHint("Tap to show actions")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Harmony Chip Background

private struct HarmonyChipBackground: ViewModifier {
    let isSelected: Bool
    let tintColor: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
            if isSelected {
                content.background(tintColor.opacity(0.25), in: Capsule())
            } else {
                content.glassEffect(.regular, in: Capsule())
            }
        } else {
            if isSelected {
                content.background(Capsule().fill(tintColor.opacity(0.25)))
            } else {
                content.background(Capsule().fill(.fill.tertiary))
            }
        }
    }
}


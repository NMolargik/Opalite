//
//  CanvasSwatchPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/20/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CanvasSwatchPickerView: View {
    @Environment(ColorManager.self) private var colorManager

    let onColorSelected: (OpaliteColor) -> Void
    private let swatchSize: CGFloat = 44

    // Track which color was just selected for checkmark animation
    @State private var selectedColorID: UUID? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // MARK: - Loose Colors Section
                if !colorManager.looseColors.isEmpty {
                    ForEach(colorManager.looseColors.sorted(by: { $0.updatedAt > $1.updatedAt }), id: \.id) { color in
                        swatchButton(for: color)
                    }

                    // Divider after loose colors if there are palettes
                    if !colorManager.palettes.isEmpty {
                        sectionDivider
                    }
                }

                // MARK: - Palette Sections
                ForEach(Array(colorManager.palettes.sorted(by: { $0.updatedAt > $1.updatedAt }).enumerated()), id: \.element.id) { index, palette in
                    let paletteColors = palette.colors?.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []

                    if !paletteColors.isEmpty {
                        ForEach(paletteColors, id: \.id) { color in
                            swatchButton(for: color)
                        }

                        // Divider after each palette except the last
                        if index < colorManager.palettes.count - 1 {
                            sectionDivider
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: swatchSize + 16)
        .background(.ultraThinMaterial)
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private func swatchButton(for color: OpaliteColor) -> some View {
        PencilHapticSwatchButton(
            color: color.swiftUIColor,
            size: swatchSize,
            isSelected: selectedColorID == color.id,
            idealTextColor: color.idealTextColor()
        ) {
            HapticsManager.shared.selection()
            onColorSelected(color)

            // Show checkmark briefly
            withAnimation(.linear(duration: 0.15)) {
                selectedColorID = color.id
            }

            // Hide checkmark after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.linear(duration: 0.15)) {
                    selectedColorID = nil
                }
            }
        }
        .frame(width: swatchSize, height: swatchSize)
    }

    private var sectionDivider: some View {
        Capsule()
            .fill(.secondary.opacity(0.4))
            .frame(width: 2, height: swatchSize * 0.6)
    }
}

// MARK: - Pencil Haptic Swatch Button

#if canImport(UIKit)
/// A UIViewRepresentable that provides Apple Pencil Pro haptic feedback when tapped
struct PencilHapticSwatchButton: UIViewRepresentable {
    let color: Color
    let size: CGFloat
    let isSelected: Bool
    let idealTextColor: Color
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> PencilHapticSwatchView {
        let view = PencilHapticSwatchView()
        view.onTap = { [weak coordinator = context.coordinator] in
            coordinator?.onTap()
        }
        return view
    }

    func updateUIView(_ uiView: PencilHapticSwatchView, context: Context) {
        // Update the coordinator's callback to the latest closure
        context.coordinator.onTap = onTap

        uiView.updateAppearance(
            color: UIColor(color),
            size: size,
            isSelected: isSelected,
            checkmarkColor: UIColor(idealTextColor)
        )
    }

    class Coordinator {
        var onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }
    }
}

/// UIView that handles Apple Pencil touches and triggers haptic feedback
class PencilHapticSwatchView: UIView, UIPointerInteractionDelegate {
    var onTap: (() -> Void)?

    private let colorLayer = CALayer()
    private let borderLayer = CALayer()
    private let checkmarkImageView = UIImageView()

    private var canvasFeedbackGenerator: UICanvasFeedbackGenerator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Color fill layer
        layer.addSublayer(colorLayer)

        // Border layer
        borderLayer.borderWidth = 2
        borderLayer.borderColor = UIColor.systemGray4.cgColor
        layer.addSublayer(borderLayer)

        // Checkmark overlay
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        checkmarkImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        checkmarkImageView.contentMode = .center
        checkmarkImageView.isHidden = true
        addSubview(checkmarkImageView)

        // Enable user interaction
        isUserInteractionEnabled = true

        // Add pointer/hover interaction for iPad cursor lift effect
        let pointerInteraction = UIPointerInteraction(delegate: self)
        addInteraction(pointerInteraction)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Initialize the feedback generator once the view is in the window hierarchy
        if window != nil && canvasFeedbackGenerator == nil {
            canvasFeedbackGenerator = UICanvasFeedbackGenerator(view: self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cornerRadius = min(bounds.width, bounds.height) * 0.3

        colorLayer.frame = bounds
        colorLayer.cornerRadius = cornerRadius

        borderLayer.frame = bounds
        borderLayer.cornerRadius = cornerRadius

        checkmarkImageView.frame = bounds
    }

    func updateAppearance(color: UIColor, size: CGFloat, isSelected: Bool, checkmarkColor: UIColor) {
        colorLayer.backgroundColor = color.cgColor
        checkmarkImageView.tintColor = checkmarkColor
        checkmarkImageView.isHidden = !isSelected

        // Add shadow to checkmark for visibility
        if isSelected {
            checkmarkImageView.layer.shadowColor = checkmarkColor.cgColor
            checkmarkImageView.layer.shadowOffset = CGSize(width: 0, height: 1)
            checkmarkImageView.layer.shadowRadius = 2
            checkmarkImageView.layer.shadowOpacity = 0.5
        }
    }

    // MARK: - UIPointerInteractionDelegate (Hover/Lift Effect)

    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        let cornerRadius = min(bounds.width, bounds.height) * 0.3
        let targetedPreview = UITargetedPreview(view: self)
        return UIPointerStyle(effect: .lift(targetedPreview), shape: .roundedRect(bounds, radius: cornerRadius))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        // Visual feedback - slight scale down
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if touch ended inside the view
        if bounds.contains(location) {
            // Trigger Apple Pencil Pro haptic feedback
            canvasFeedbackGenerator?.alignmentOccurred(at: location)

            // Call the tap handler directly - we're already on main thread
            onTap?()
        }

        // Reset scale
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        // Reset scale
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
        }
    }
}
#endif

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return CanvasSwatchPickerView { color in
        print("Selected: \(color.hexString)")
    }
    .environment(colorManager)
    .padding(.top, 50)
}

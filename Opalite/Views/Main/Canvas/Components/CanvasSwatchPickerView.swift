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
    @Environment(ToastManager.self) private var toastManager

    let canvasFile: CanvasFile
    let onColorSelected: (OpaliteColor) -> Void
    private let swatchSize: CGFloat = 44
    private let itemSpacing: CGFloat = 8

    // Track which color was just selected for checkmark animation
    @State private var selectedColorID: UUID?
    @State private var showAllColors: Bool = false

    /// Whether this canvas has an associated palette
    private var hasAssociatedPalette: Bool {
        canvasFile.palette != nil
    }

    /// Colors to show — filtered by palette if associated and not showing all
    private var allColors: [OpaliteColor] {
        if !showAllColors, let palette = canvasFile.palette {
            return palette.sortedColors
        }
        var colors: [OpaliteColor] = []
        colors.append(contentsOf: colorManager.looseColors)
        for palette in colorManager.palettes {
            colors.append(contentsOf: palette.sortedColors)
        }
        return colors
    }

    var body: some View {
        HStack(spacing: 0) {
            HapticSwatchScrollView(
                colors: allColors,
                swatchSize: swatchSize,
                itemSpacing: itemSpacing,
                selectedColorID: selectedColorID,
                onColorSelected: { color in
                    HapticsManager.shared.selection()
                    onColorSelected(color)

                    // Show toast with color name or hex
                    let colorLabel = color.name?.isEmpty == false ? color.name! : color.hexString
                    toastManager.show(ToastItem(message: colorLabel, style: .info, icon: "paintbrush.fill", duration: 1.5))

                    // Show checkmark briefly
                    withAnimation(.linear(duration: 0.15)) {
                        selectedColorID = color.id
                    }

                    // Hide checkmark after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.linear(duration: 0.15)) {
                            selectedColorID = nil
                        }
                    }
                }
            )

            if hasAssociatedPalette {
                Divider()
                    .frame(height: swatchSize)

                Button {
                    HapticsManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllColors.toggle()
                    }
                } label: {
                    Image(systemName: showAllColors ? "swatchpalette.fill" : "paintpalette.fill")
                        .font(.title3)
                        .foregroundColor(showAllColors ? .secondary : .red)
                        .frame(width: 44, height: swatchSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .frame(height: swatchSize + 16)
        .background(.ultraThinMaterial)
        .clipShape(Rectangle())
    }
}

// MARK: - Haptic Scroll View

#if canImport(UIKit)
/// A horizontal scroll view that triggers haptic feedback as items scroll past the center
struct HapticSwatchScrollView: UIViewRepresentable {
    let colors: [OpaliteColor]
    let swatchSize: CGFloat
    let itemSpacing: CGFloat
    let selectedColorID: UUID?
    let onColorSelected: (OpaliteColor) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.delegate = context.coordinator

        let contentView = UIView()
        contentView.tag = 100
        scrollView.addSubview(contentView)

        context.coordinator.scrollView = scrollView
        context.coordinator.contentView = contentView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.rebuildContent()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: HapticSwatchScrollView
        weak var scrollView: UIScrollView?
        weak var contentView: UIView?

        private var lastFocusedIndex: Int = -1
        #if !os(visionOS)
        private var selectionFeedback: UISelectionFeedbackGenerator?
        private var canvasFeedback: UICanvasFeedbackGenerator?
        #endif
        private var swatchViews: [PencilHapticSwatchView] = []

        init(parent: HapticSwatchScrollView) {
            self.parent = parent
            super.init()
            #if !os(visionOS)
            selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback?.prepare()
            #endif
        }

        func rebuildContent() {
            guard let scrollView = scrollView, let contentView = contentView else { return }

            // Remove old swatch views
            swatchViews.forEach { $0.removeFromSuperview() }
            swatchViews.removeAll()

            let horizontalPadding: CGFloat = 12
            let swatchSize = parent.swatchSize
            let spacing = parent.itemSpacing

            var xOffset: CGFloat = horizontalPadding

            for (index, color) in parent.colors.enumerated() {
                let swatchView = PencilHapticSwatchView()
                swatchView.frame = CGRect(x: xOffset, y: 8, width: swatchSize, height: swatchSize)
                swatchView.updateAppearance(
                    color: UIColor(color.swiftUIColor),
                    size: swatchSize,
                    isSelected: parent.selectedColorID == color.id,
                    checkmarkColor: UIColor(color.idealTextColor())
                )
                swatchView.tag = index
                swatchView.onTap = { [weak self] in
                    guard let self = self, index < self.parent.colors.count else { return }
                    self.parent.onColorSelected(self.parent.colors[index])
                }
                contentView.addSubview(swatchView)
                swatchViews.append(swatchView)

                xOffset += swatchSize + spacing
            }

            // Adjust final width (remove last spacing, add padding)
            let contentWidth = xOffset - spacing + horizontalPadding
            let contentHeight = swatchSize + 16

            contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)

            // Initialize canvas feedback generator if not already done
            #if !os(visionOS)
            if canvasFeedback == nil {
                canvasFeedback = UICanvasFeedbackGenerator(view: scrollView)
            }
            #endif
        }

        // MARK: - UIScrollViewDelegate

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let centerX = scrollView.contentOffset.x + scrollView.bounds.width / 2
            let focusedIndex = indexOfItem(at: centerX)

            if focusedIndex != lastFocusedIndex && focusedIndex >= 0 && focusedIndex < parent.colors.count {
                lastFocusedIndex = focusedIndex

                // Trigger iPhone haptic
                #if !os(visionOS)
                selectionFeedback?.selectionChanged()
                selectionFeedback?.prepare()
                #endif

                // Trigger Apple Pencil Pro haptic
                #if !os(visionOS)
                let hapticLocation = CGPoint(x: scrollView.bounds.width / 2, y: scrollView.bounds.height / 2)
                canvasFeedback?.alignmentOccurred(at: hapticLocation)
                #endif
            }
        }

        private func indexOfItem(at centerX: CGFloat) -> Int {
            let horizontalPadding: CGFloat = 12
            let swatchSize = parent.swatchSize
            let spacing = parent.itemSpacing
            let itemWidth = swatchSize + spacing

            // Calculate which item index the centerX falls into
            let adjustedX = centerX - horizontalPadding
            if adjustedX < 0 { return 0 }

            let index = Int(adjustedX / itemWidth)
            return min(index, parent.colors.count - 1)
        }
    }
}
#endif

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

    #if !os(visionOS)
    private var canvasFeedbackGenerator: UICanvasFeedbackGenerator?
    #endif

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
        #if !os(visionOS)
        if window != nil && canvasFeedbackGenerator == nil {
            canvasFeedbackGenerator = UICanvasFeedbackGenerator(view: self)
        }
        #endif
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
            #if !os(visionOS)
            canvasFeedbackGenerator?.alignmentOccurred(at: location)
            #endif

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
        CanvasFile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return CanvasSwatchPickerView(canvasFile: CanvasFile()) { color in
        print("Selected: \(color.hexString)")
    }
    .environment(colorManager)
    .environment(ToastManager())
    .padding(.top, 50)
}

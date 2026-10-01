//
//  ImagePickerView.swift
//  OpaliteFeatureColorEditor
//
//  Mode 6: sample from an image — Photos, the camera, a dropped image, or (on Mac) the
//  system screen eyedropper. Tap or drag on the image with a magnifying loupe.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import UIKit

struct ImagePickerView: View {
    let viewModel: ColorEditorViewModel
    var fillsHeight = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var cgImage: CGImage?
    @State private var sampledPoint: CGPoint?
    @State private var sampledColor: RGBA?
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            ImageSourceBar(onImage: setImage, onScreenSample: screenSampled)

            if let image {
                SamplingImageView(
                    image: image,
                    cgImage: cgImage,
                    sampledPoint: sampledPoint,
                    sampledColor: sampledColor,
                    onBegan: { viewModel.beginGesture() },
                    onSample: { rgba, point in
                        sampledColor = rgba
                        sampledPoint = point
                        viewModel.update(rgba)
                    },
                    onEnded: {
                        viewModel.endGesture()
                        Haptics.lightImpact()
                    }
                )
                .frame(maxHeight: fillsHeight ? .infinity : 360)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

                HStack(spacing: Brand.Space.sm) {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.secondary)
                    Text(sampledColor == nil ? "Tap or drag on the image to sample a color" : "Drag to refine, or choose another image")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button(role: .destructive) {
                        Haptics.selection()
                        withAnimation(reduceMotion ? nil : .snappy) { clearImage() }
                    } label: {
                        Label("Remove", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Remove image"))
                }
            } else {
                ImageDropPlaceholder(isTargeted: isDropTargeted)
                    .frame(maxHeight: fillsHeight ? .infinity : nil)
            }

            OpacitySlider(viewModel: viewModel)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: image == nil)
        .dropDestination(for: Data.self) { items, _ in
            guard let data = items.first, let dropped = UIImage(data: data) else { return false }
            setImage(dropped)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private func setImage(_ new: UIImage) {
        image = new
        cgImage = new.sampleableCGImage()
        sampledPoint = nil
        sampledColor = nil
    }

    private func clearImage() {
        image = nil
        cgImage = nil
        sampledPoint = nil
        sampledColor = nil
    }

    private func screenSampled(_ rgba: RGBA) {
        Haptics.lightImpact()
        viewModel.pick(rgba)
    }
}

#if DEBUG
#Preview("Image") {
    ImagePickerView(viewModel: ColorEditorViewModel(mode: .create()))
        .padding()
}
#endif
#endif

//
//  PhotoColorPickerSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit

/// A sheet for picking multiple colors from a photo.
///
/// Users can tap/drag on an image to sample colors, stage them in a list,
/// then import all staged colors at once or cancel.
struct PhotoColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    /// Optional initial image to start with (e.g., from drag-and-drop)
    var initialImage: UIImage?

    @State private var selectedImage: UIImage?
    @State private var sampledPoint: CGPoint?
    @State private var currentColor: OpaliteColor?
    @State private var stagedColors: [OpaliteColor] = []
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imageSourceButtons

                    if let uiImage = selectedImage {
                        imagePickerContent(for: uiImage)

                        if let current = currentColor {
                            currentColorPreview(current)
                        }
                    } else {
                        placeholderView
                    }

                    if !stagedColors.isEmpty {
                        stagedColorsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Sample Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        HapticsManager.shared.impact()
                        importStagedColors()
                    }
                    .disabled(stagedColors.isEmpty)
                }
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            PhotoPickerView(selectedImage: $selectedImage)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView(selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .onChange(of: selectedImage) { _, _ in
            sampledPoint = nil
            currentColor = nil
        }
        .onAppear {
            if let initialImage, selectedImage == nil {
                selectedImage = initialImage
            }
        }
    }

    // MARK: - Image Source Buttons

    @ViewBuilder
    private var imageSourceButtons: some View {
        HStack(spacing: 12) {
            Button {
                HapticsManager.shared.impact()
                isShowingImagePicker = true
            } label: {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)

            Button {
                HapticsManager.shared.impact()
                isShowingCamera = true
            } label: {
                Label("Capture Photo", systemImage: "camera")
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Placeholder

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Select an image to start picking colors")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Image Content

    private func calculateImageDisplayHeight(for uiImage: UIImage, availableWidth: CGFloat) -> CGFloat {
        let aspectRatio = uiImage.size.width / uiImage.size.height
        let maxHeight: CGFloat = 400
        let calculatedHeight = availableWidth / aspectRatio
        return min(calculatedHeight, maxHeight)
    }

    @ViewBuilder
    private func imagePickerContent(for uiImage: UIImage) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let viewSize = geometry.size
                // Calculate where the image actually appears within the view when using scaledToFit
                let imageRect = calculateImageRect(for: uiImage, in: viewSize)

                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: viewSize.width, height: viewSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.secondary.opacity(0.3))
                        )

                    if let point = sampledPoint {
                        Circle()
                            .fill(currentColor?.swiftUIColor ?? .clear)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                            .position(point)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleSample(at: value.location, imageRect: imageRect, image: uiImage)
                        }
                        .onEnded { value in
                            handleSample(at: value.location, imageRect: imageRect, image: uiImage)
                        }
                )
            }
            .frame(height: calculateImageDisplayHeight(for: uiImage, availableWidth: UIScreen.main.bounds.width - 32))

            Text("Tap or drag on the image to pick a color")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Current Color Preview

    @ViewBuilder
    private func currentColorPreview(_ color: OpaliteColor) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.swiftUIColor)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.3))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(color.hexString)
                    .font(.headline.monospaced())

                Text("Tap 'Stage' to add to import list")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                HapticsManager.shared.selection()
                stageCurrentColor()
            } label: {
                Label("Stage", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Staged Colors Section

    @ViewBuilder
    private var stagedColorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Staged Colors")
                    .font(.headline)

                Text("(\(stagedColors.count))")
                    .foregroundStyle(.secondary)

                Spacer()

                Button(role: .destructive) {
                    HapticsManager.shared.selection()
                    withAnimation {
                        stagedColors.removeAll()
                    }
                } label: {
                    Text("Clear All")
                        .font(.caption)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(stagedColors.enumerated()), id: \.element.id) { index, color in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.swiftUIColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(.secondary.opacity(0.3))
                                )
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        HapticsManager.shared.selection()
                                        stagedColors.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white, .red)
                                    }
                                    .offset(x: 6, y: -6)
                                }

                            Text(color.hexString)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func stageCurrentColor() {
        guard let color = currentColor else { return }

        let stagedColor = OpaliteColor(
            name: nil,
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )

        withAnimation {
            stagedColors.append(stagedColor)
        }

        currentColor = nil
        sampledPoint = nil
    }

    private func importStagedColors() {
        withAnimation {
            var successCount = 0

            for color in stagedColors {
                do {
                    _ = try colorManager.createColor(existing: color)
                    successCount += 1
                } catch {
                    // Continue importing other colors
                }
            }

            if successCount > 0 {
                OpaliteTipActions.advanceTipsAfterContentCreation()
            }
        }

        dismiss()
    }

    // MARK: - Image Sampling Helpers

    private func calculateImageRect(for image: UIImage, in viewSize: CGSize) -> CGRect {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
    }

    private func handleSample(at location: CGPoint, imageRect: CGRect, image: UIImage) {
        guard imageRect.contains(location) else { return }

        let normalizedX = (location.x - imageRect.minX) / imageRect.width
        let normalizedY = (location.y - imageRect.minY) / imageRect.height

        if let sampledUIColor = sampleColor(from: image, atNormalized: CGPoint(x: normalizedX, y: normalizedY)) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            sampledUIColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            currentColor = OpaliteColor(
                name: nil,
                red: Double(r),
                green: Double(g),
                blue: Double(b),
                alpha: Double(a)
            )

            sampledPoint = location
        }
    }

    private func sampleColor(from image: UIImage, atNormalized point: CGPoint, radius: Int = 2) -> UIColor? {
        guard let normalizedImage = normalizeImageOrientation(image),
              let cgImage = normalizedImage.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        let pixelX = Int(point.x * CGFloat(width - 1))
        let pixelY = Int(point.y * CGFloat(height - 1))

        let minX = max(0, pixelX - radius)
        let maxX = min(width - 1, pixelX + radius)
        let minY = max(0, pixelY - radius)
        let maxY = min(height - 1, pixelY + radius)

        let sampleWidth = maxX - minX + 1
        let sampleHeight = maxY - minY + 1

        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixelData,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        let drawRect = CGRect(
            x: -minX,
            y: -(height - maxY - 1),
            width: width,
            height: height
        )
        context.draw(cgImage, in: drawRect)

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var totalA: CGFloat = 0
        var count: CGFloat = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = y * bytesPerRow + x * bytesPerPixel

                let r = CGFloat(pixelData[offset]) / 255.0
                let g = CGFloat(pixelData[offset + 1]) / 255.0
                let b = CGFloat(pixelData[offset + 2]) / 255.0
                let a = CGFloat(pixelData[offset + 3]) / 255.0

                if a > 0 {
                    totalR += r / a
                    totalG += g / a
                    totalB += b / a
                    totalA += a
                } else {
                    totalR += r
                    totalG += g
                    totalB += b
                    totalA += a
                }
                count += 1
            }
        }

        guard count > 0 else { return nil }

        return UIColor(
            red: min(1, totalR / count),
            green: min(1, totalG / count),
            blue: min(1, totalB / count),
            alpha: totalA / count
        )
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }

        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)

    return PhotoColorPickerSheet()
        .environment(manager)
        .environment(ToastManager())
        .modelContainer(container)
}

#endif

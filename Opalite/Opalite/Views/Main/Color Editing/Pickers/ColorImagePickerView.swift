//
//  ColorImagePickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct ColorImagePickerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var color: OpaliteColor

    @State private var selectedImage: UIImage?
    @State private var sampledPoint: CGPoint?
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if horizontalSizeClass == .regular {
                Spacer(minLength: 0)
            }

            // Header
            HStack(spacing: 8) {
                Image(systemName: "eyedropper.halffull")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                Text("From Image")
                    .font(.headline)

                Spacer()
            }

            // Card container
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        HapticsManager.shared.impact()
                        isShowingImagePicker = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)

                    Spacer()

                    #if !os(visionOS)
                    Button {
                        HapticsManager.shared.impact()
                        isShowingCamera = true
                    } label: {
                        Label("Capture Photo", systemImage: "camera")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                    #endif
                }

                if let uiImage = selectedImage {
                    imagePickerContent(for: uiImage)
                } else {
                    Text("Select an image to start sampling colors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
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
        }
    }

    @ViewBuilder
    private func imagePickerContent(for uiImage: UIImage) -> some View {
        GeometryReader { geometry in
            let imageRect = calculateImageRect(for: uiImage, in: geometry.size)

            ZStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.3))
                    )

                // Sampling indicator
                if let point = sampledPoint {
                    Circle()
                        .fill(color.swiftUIColor)
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
            .accessibilityLabel("Image sampling area")
            .accessibilityHint("Tap or drag on the image to sample a color")
        }
        .aspectRatio(uiImage.size, contentMode: .fit)
        .frame(maxHeight: horizontalSizeClass == .compact ? 350 : nil)

        Text("Tap or drag on the image to pick a color.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// Calculate where the image is actually drawn within the view (accounting for scaledToFit)
    private func calculateImageRect(for image: UIImage, in viewSize: CGSize) -> CGRect {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            // Image is wider - constrained by width
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            // Image is taller - constrained by height
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
    }

    private func handleSample(at location: CGPoint, imageRect: CGRect, image: UIImage) {
        // Ensure tap is within the image bounds
        guard imageRect.contains(location) else { return }

        // Convert view coordinates to normalized image coordinates (0-1)
        let normalizedX = (location.x - imageRect.minX) / imageRect.width
        let normalizedY = (location.y - imageRect.minY) / imageRect.height

        // Sample the color
        if let sampledColor = sampleColor(from: image, atNormalized: CGPoint(x: normalizedX, y: normalizedY)) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            sampledColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            color.red = Double(r)
            color.green = Double(g)
            color.blue = Double(b)
            color.alpha = Double(a)

            sampledPoint = location
        }
    }

    /// Sample a color from the image at normalized coordinates (0-1 range)
    private func sampleColor(from image: UIImage, atNormalized point: CGPoint, radius: Int = 2) -> UIColor? {
        // Normalize the image orientation first - this ensures pixel data matches displayed orientation
        guard let normalizedImage = normalizeImageOrientation(image),
              let cgImage = normalizedImage.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Convert normalized coordinates to pixel coordinates
        let pixelX = Int(point.x * CGFloat(width - 1))
        let pixelY = Int(point.y * CGFloat(height - 1))

        // Sample area bounds (clamped to image)
        let minX = max(0, pixelX - radius)
        let maxX = min(width - 1, pixelX + radius)
        let minY = max(0, pixelY - radius)
        let maxY = min(height - 1, pixelY + radius)

        let sampleWidth = maxX - minX + 1
        let sampleHeight = maxY - minY + 1

        // Create a small bitmap context in a known format (RGBA, 8 bits per component)
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

        // Draw the relevant portion of the image into our context
        // CGContext uses bottom-left origin, so we need to flip and offset
        let drawRect = CGRect(
            x: -minX,
            y: -(height - maxY - 1),
            width: width,
            height: height
        )
        context.draw(cgImage, in: drawRect)

        // Average all pixels in the sample area
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

                // Unpremultiply alpha if needed
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

    /// Renders the image to a new CGImage with orientation applied.
    /// This ensures the pixel data matches the displayed orientation.
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage? {
        // If already oriented correctly, return as-is
        guard image.imageOrientation != .up else { return image }

        // Render the image to a new context with the correct orientation
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var color = OpaliteColor.sample
        var body: some View {
            ColorImagePickerView(color: $color)
                .padding()
        }
    }
    return PreviewContainer()
}

#elseif canImport(AppKit)
import AppKit

/// macOS placeholder: image-based color picking is not available here.
struct ColorImagePickerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var color: OpaliteColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if horizontalSizeClass == .regular {
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "eyedropper.halffull")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                Text("From Image")
                    .font(.headline)
                Spacer()
            }
            Text("Image-based color picking is not available on macOS.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var color = OpaliteColor.sample
        var body: some View {
            ColorImagePickerView(color: $color)
                .padding()
        }
    }
    return PreviewContainer()
}

#endif

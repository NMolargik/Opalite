//
//  ImageSampling.swift
//  OpaliteFeatureColorEditor
//
//  Everything the image mode and the photo sampler share: pixel averaging from a
//  `CGImage`, the tap/drag sampling surface with its magnifying loupe, the image source
//  bar (Photos, camera, Catalyst screen sampler), and the camera capture wrapper.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import CoreGraphics
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import UIKit
import os
#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Pixel sampling

nonisolated enum ImageSampler {
    /// The average sRGB color in a (2·radius + 1)² block around a normalized point.
    static func rgba(in image: CGImage, atNormalized point: CGPoint, radius: Int = 2) -> RGBA? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }

        let pixelX = Int((point.x * CGFloat(width - 1)).rounded())
        let pixelY = Int((point.y * CGFloat(height - 1)).rounded())
        let minX = max(0, pixelX - radius), maxX = min(width - 1, pixelX + radius)
        let minY = max(0, pixelY - radius), maxY = min(height - 1, pixelY + radius)
        let sampleWidth = maxX - minX + 1, sampleHeight = maxY - minY + 1

        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // Core Graphics draws bottom-up: shift so the block of interest lands at the origin.
            context.draw(image, in: CGRect(x: -minX, y: -(height - maxY - 1), width: width, height: height))
            return true
        }
        guard drew else { return nil }

        var red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0
        let count = Double(sampleWidth * sampleHeight)
        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let a = Double(pixels[offset + 3]) / 255
                let unpremultiply = a > 0 ? 1 / a : 1
                red += Double(pixels[offset]) / 255 * unpremultiply
                green += Double(pixels[offset + 1]) / 255 * unpremultiply
                blue += Double(pixels[offset + 2]) / 255 * unpremultiply
                alpha += a
            }
        }
        return RGBA(
            red: ColorMath.clamp(red / count),
            green: ColorMath.clamp(green / count),
            blue: ColorMath.clamp(blue / count),
            alpha: ColorMath.clamp(alpha / count)
        )
    }

    /// The rectangle an aspect-fit image occupies inside `bounds`.
    static func fittedRect(for imageSize: CGSize, in bounds: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }
}

extension UIImage {
    /// A `CGImage` whose pixel rows match the displayed orientation, capped in size so
    /// sampling and the loupe stay responsive with large camera captures.
    func sampleableCGImage(maxDimension: CGFloat = 2048) -> CGImage? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        if imageOrientation == .up, scale == 1, let cgImage { return cgImage }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }
}

// MARK: - Sampling surface

/// Shows an image and reports the color under a tap or drag, with a magnifying loupe.
struct SamplingImageView: View {
    let image: UIImage
    let cgImage: CGImage?
    /// The last sampled point, normalized to the image (0...1), if any.
    let sampledPoint: CGPoint?
    let sampledColor: RGBA?
    var onBegan: () -> Void = {}
    let onSample: (RGBA, CGPoint) -> Void
    var onEnded: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var loupeSize: CGFloat = 96
    @State private var isDragging = false

    private let zoom: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let rect = ImageSampler.fittedRect(for: image.size, in: proxy.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous).strokeBorder(.quaternary))

                if let sampledPoint, let sampledColor {
                    marker(at: sampledPoint, in: rect, color: sampledColor)
                    if isDragging || !reduceMotion {
                        loupe(at: sampledPoint, in: rect, bounds: proxy.size, color: sampledColor)
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onBegan()
                        }
                        sample(at: gesture.location, in: rect)
                    }
                    .onEnded { gesture in
                        sample(at: gesture.location, in: rect)
                        isDragging = false
                        onEnded()
                    }
            )
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isDragging)
        }
        .aspectRatio(image.size, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Image sampling area"))
        .accessibilityValue(Text(sampledColor.map { $0.hexString } ?? String(localized: "Nothing sampled yet")))
        .accessibilityHint(Text("Tap or drag on the image to sample a color"))
        .accessibilityAction(named: Text("Sample the center")) { sampleNormalized(CGPoint(x: 0.5, y: 0.5)) }
        .accessibilityAction(named: Text("Sample the top left")) { sampleNormalized(CGPoint(x: 0.1, y: 0.1)) }
        .accessibilityAction(named: Text("Sample the bottom right")) { sampleNormalized(CGPoint(x: 0.9, y: 0.9)) }
    }

    private func marker(at point: CGPoint, in rect: CGRect, color: RGBA) -> some View {
        Circle()
            .fill(color.color)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .frame(width: 24, height: 24)
            .position(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            .allowsHitTesting(false)
    }

    private func loupe(at point: CGPoint, in rect: CGRect, bounds: CGSize, color: RGBA) -> some View {
        let anchor = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        let half = loupeSize / 2
        // Float the loupe above the finger, flipping below near the top edge, clamped horizontally.
        let above = anchor.y - half - 36 >= 0
        let center = CGPoint(
            x: min(max(anchor.x, half), max(bounds.width - half, half)),
            y: above ? anchor.y - half - 36 : anchor.y + half + 36
        )
        let magnified = CGSize(width: rect.width * zoom, height: rect.height * zoom)

        return ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: magnified.width, height: magnified.height)
                .offset(x: half - point.x * magnified.width, y: half - point.y * magnified.height)
            Circle()
                .strokeBorder(color.color, lineWidth: 6)
            Circle()
                .strokeBorder(.white, lineWidth: 1.5)
                .padding(6)
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(color.idealTextColor.opacity(0.9))
                .frame(width: loupeSize, height: loupeSize)
        }
        .frame(width: loupeSize, height: loupeSize)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .position(center)
        .allowsHitTesting(false)
    }

    private func sample(at location: CGPoint, in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        let normalized = CGPoint(
            x: min(max((location.x - rect.minX) / rect.width, 0), 1),
            y: min(max((location.y - rect.minY) / rect.height, 0), 1)
        )
        sampleNormalized(normalized)
    }

    private func sampleNormalized(_ point: CGPoint) {
        guard let cgImage, let rgba = ImageSampler.rgba(in: cgImage, atNormalized: point) else { return }
        onSample(rgba, point)
    }
}

// MARK: - Image sources

/// The row of ways to bring an image in: Photos, the camera (iPhone/iPad), and on Mac
/// the system-wide screen eyedropper.
struct ImageSourceBar: View {
    let onImage: (UIImage) -> Void
    var onScreenSample: ((RGBA) -> Void)? = nil

    #if canImport(PhotosUI)
    @State private var photoItem: PhotosPickerItem?
    #endif
    @State private var isShowingCamera = false
    @State private var isSampling = false

    var body: some View {
        HStack(spacing: Brand.Space.sm) {
            #if canImport(PhotosUI)
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            .glassActionButton(tint: .opalitePurple, prominent: true)
            .accessibilityIdentifier("colorEditor.image.photos")
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await load(item) }
            }
            #endif

            #if os(iOS) && !targetEnvironment(macCatalyst)
            if CameraCaptureView.isAvailable {
                Button {
                    Haptics.lightImpact()
                    isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .glassActionButton(tint: .opaliteBlue, prominent: false)
                .accessibilityIdentifier("colorEditor.image.camera")
            }
            #endif

            #if targetEnvironment(macCatalyst)
            if let onScreenSample {
                Button {
                    Haptics.lightImpact()
                    isSampling = true
                    Task {
                        if let rgba = await SystemColorSampler.sample() { onScreenSample(rgba) }
                        isSampling = false
                    }
                } label: {
                    Label("Screen", systemImage: "eyedropper")
                }
                .glassActionButton(tint: .opaliteBlue, prominent: false)
                .disabled(isSampling)
                .accessibilityLabel(Text("Sample a color from the screen"))
                .accessibilityIdentifier("colorEditor.image.screenSampler")
            }
            #endif

            Spacer(minLength: 0)
        }
        .controlSize(.regular)
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in onImage(image) }
                .ignoresSafeArea()
        }
        #endif
    }

    #if canImport(PhotosUI)
    private func load(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                onImage(image)
            } else {
                Log.app.error("Photos picker returned no decodable image")
            }
        } catch {
            Log.app.error("Photos picker load failed: \(error.localizedDescription)")
        }
        photoItem = nil
    }
    #endif
}

// MARK: - Camera

#if os(iOS) && !targetEnvironment(macCatalyst)
/// The system camera, returning the captured still.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif

// MARK: - Drop zone

/// The dashed placeholder shown before an image is chosen; also the drop target hint.
struct ImageDropPlaceholder: View {
    var isTargeted = false

    var body: some View {
        VStack(spacing: Brand.Space.md) {
            Image(systemName: "photo.badge.plus")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.opalitePurple)
                .symbolEffect(.bounce, value: isTargeted)
            Text("Choose a Photo")
                .font(.headline)
            Text("Pick from Photos, take a picture, or drop an image here. Then tap or drag on it to sample a color.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Brand.readableWidth)
        }
        .padding(Brand.Space.xl)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color.opalitePurple.opacity(isTargeted ? 0.18 : 0.06), in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                .strokeBorder(Color.opalitePurple.opacity(isTargeted ? 0.8 : 0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        )
        .accessibilityElement(children: .combine)
    }
}
#endif

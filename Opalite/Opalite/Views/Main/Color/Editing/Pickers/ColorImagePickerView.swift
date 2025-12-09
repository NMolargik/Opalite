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
    @Binding var color: OpaliteColor

    @State private var selectedImage: UIImage?
    @State private var sampledImagePoint: CGPoint?
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        isShowingImagePicker = true
                    } label: {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Spacer()

                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .foregroundStyle(.black)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let uiImage = selectedImage {
                    GeometryReader { proxy in
                        ZStack {
                            // Display the image with "fit" behavior similar to system picker
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.secondary.opacity(0.3))
                                )
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            sampleColor(from: uiImage,
                                                        at: value.location,
                                                        in: proxy.size)
                                        }
                                        .onEnded { value in
                                            sampleColor(from: uiImage,
                                                        at: value.location,
                                                        in: proxy.size)
                                        }
                                )

                            if let point = sampledImagePoint {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .shadow(radius: 2)
                                    .frame(width: 24, height: 24)
                                    .position(point)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(uiImage.size, contentMode: .fit)

                    Text("Tap on the image to pick a color.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView(selectedImage: $selectedImage)
        }
    }

    /// Given a tap/drag point in the view space and the view size, sample the corresponding pixel color from the UIImage.
    /// Coordinates are mapped assuming the image is drawn with a top-left origin, matching SwiftUI/CGImage default behavior.
    private func sampleColor(from image: UIImage, at location: CGPoint, in viewSize: CGSize) {
        guard let cgImage = image.cgImage else { return }

        // Compute the rect within the view where the image is actually drawn when using .scaledToFit
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        var drawRect = CGRect(origin: .zero, size: viewSize)

        if imageAspect > viewAspect {
            // Image is wider than the view: fit width
            let scaledHeight = viewSize.width / imageAspect
            let y = (viewSize.height - scaledHeight) / 2.0
            drawRect = CGRect(x: 0, y: y, width: viewSize.width, height: scaledHeight)
        } else {
            // Image is taller than the view: fit height
            let scaledWidth = viewSize.height * imageAspect
            let x = (viewSize.width - scaledWidth) / 2.0
            drawRect = CGRect(x: x, y: 0, width: scaledWidth, height: viewSize.height)
        }

        // Ensure the tap is within the drawn image rect
        guard drawRect.contains(location) else { return }

        // Convert tap location into normalized coordinates within the drawn image
        let normalizedX = (location.x - drawRect.minX) / drawRect.width
        let normalizedY = (location.y - drawRect.minY) / drawRect.height

        // Map to pixel coordinates in the original image (top-left origin)
        let pixelX = Int(normalizedX * CGFloat(cgImage.width - 1))
        let pixelY = Int(normalizedY * CGFloat(cgImage.height - 1))

        // Sample an average color from a small area around the tap point
        guard let uiColor = averageColor(in: cgImage, aroundX: pixelX, y: pixelY, radius: 3) else { return }

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }

        // Update the bound OpaliteColor
        color.red = Double(r)
        color.green = Double(g)
        color.blue = Double(b)
        color.alpha = Double(a)

        // Remember the last sampled point for the on-screen indicator
        sampledImagePoint = location
    }

    /// Reads a single pixel's color from the given CGImage by accessing its raw data buffer.
    /// This avoids any coordinate transforms or scaling issues from Core Graphics drawing.
    private func colorAtPixel(in cgImage: CGImage, x: Int, y: Int) -> UIColor? {
        guard x >= 0, x < cgImage.width,
              y >= 0, y < cgImage.height else {
            return nil
        }

        guard let dataProvider = cgImage.dataProvider,
              let cfData = dataProvider.data else {
            return nil
        }

        guard let rawBytes = CFDataGetBytePtr(cfData) else {
            return nil
        }
        // Use a non-optional pointer for subscript access
        let bytes: UnsafePointer<UInt8> = rawBytes
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let bytesPerRow = cgImage.bytesPerRow

        let offset = y * bytesPerRow + x * bytesPerPixel

        let bitmapInfo = cgImage.bitmapInfo
        let alphaInfo = cgImage.alphaInfo
        let isLittleEndian = bitmapInfo.contains(.byteOrder32Little)
        let isBigEndian = bitmapInfo.contains(.byteOrder32Big)

        // Determine channel order. On iOS most images are BGRA little-endian with premultipliedFirst/noneSkipFirst.
        // We'll branch for BGRA vs RGBA, ignoring premultiplication for reading.
        if isLittleEndian {
            // BGRA order in memory
            let b = CGFloat(bytes[offset + 0]) / 255.0
            let g = CGFloat(bytes[offset + 1]) / 255.0
            let r = CGFloat(bytes[offset + 2]) / 255.0
            // Alpha may be first (premultipliedFirst/first) or noneSkipFirst; in all cases, the 4th byte is alpha or padding.
            let a: CGFloat
            switch alphaInfo {
            case .premultipliedFirst, .first, .noneSkipFirst:
                a = CGFloat(bytes[offset + 3]) / 255.0
            case .premultipliedLast, .last, .noneSkipLast:
                // Rare with little-endian, but handle just in case
                a = CGFloat(bytes[offset + 3]) / 255.0
            default:
                a = 1.0
            }
            return UIColor(red: r, green: g, blue: b, alpha: a)
        } else if isBigEndian {
            // RGBA order in memory
            let r = CGFloat(bytes[offset + 0]) / 255.0
            let g = CGFloat(bytes[offset + 1]) / 255.0
            let b = CGFloat(bytes[offset + 2]) / 255.0
            let a: CGFloat
            switch alphaInfo {
            case .premultipliedLast, .last, .noneSkipLast:
                a = CGFloat(bytes[offset + 3]) / 255.0
            case .premultipliedFirst, .first, .noneSkipFirst:
                a = CGFloat(bytes[offset + 3]) / 255.0
            default:
                a = 1.0
            }
            return UIColor(red: r, green: g, blue: b, alpha: a)
        } else {
            // Fallback: assume RGBA
            let r = CGFloat(bytes[offset + 0]) / 255.0
            let g = CGFloat(bytes[offset + 1]) / 255.0
            let b = CGFloat(bytes[offset + 2]) / 255.0
            let a = CGFloat(bytes[offset + 3]) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
    }

    /// Computes an average color from a small square region around the given pixel.
    /// This helps reduce noise and gives a result that feels closer to what the user "sees".
    private func averageColor(in cgImage: CGImage, aroundX x: Int, y: Int, radius: Int = 3) -> UIColor? {
        let minX = max(0, x - radius)
        let maxX = min(cgImage.width - 1, x + radius)
        let minY = max(0, y - radius)
        let maxY = min(cgImage.height - 1, y + radius)

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var totalA: CGFloat = 0
        var count: Int = 0

        for xi in minX...maxX {
            for yi in minY...maxY {
                guard let color = colorAtPixel(in: cgImage, x: xi, y: yi) else { continue }

                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0

                guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { continue }

                totalR += r
                totalG += g
                totalB += b
                totalA += a
                count += 1
            }
        }

        guard count > 0 else { return nil }

        let avgR = totalR / CGFloat(count)
        let avgG = totalG / CGFloat(count)
        let avgB = totalB / CGFloat(count)
        let avgA = totalA / CGFloat(count)

        return UIColor(red: avgR, green: avgG, blue: avgB, alpha: avgA)
    }
}

private struct ColorImagePickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorImagePickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorImagePickerPreviewContainer()
}

#elseif canImport(AppKit)
import AppKit
/// macOS placeholder: image-based color picking is not available here.
struct ColorImagePickerView: View {
    @Binding var color: OpaliteColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

private struct ColorImagePickerPreviewContainer: View {
    @State var color: OpaliteColor = .sample
    var body: some View {
        ColorImagePickerView(color: $color)
            .padding()
    }
}

#Preview {
    ColorImagePickerPreviewContainer()
}

#endif

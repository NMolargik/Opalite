//
//  ImageRendering.swift
//  OpaliteDesignSystem
//
//  Renders SwiftUI content to PNG bytes (drag previews, share images, Community palette
//  previews) with the platform's display scale.
//

import SwiftUI
import OpaliteCore
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

public enum ImageRendering {
    public static let defaultSize = CGSize(width: 512, height: 512)

    /// PNG bytes for `content` at `size`, or nil when rendering isn't possible here.
    @MainActor
    public static func png<Content: View>(_ content: Content, size: CGSize, opaque: Bool = false, scale: CGFloat? = nil) -> Data? {
        #if canImport(UIKit) && !os(watchOS)
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = opaque
        renderer.scale = scale ?? UITraitCollection.current.displayScale
        return renderer.uiImage?.pngData()
        #elseif os(macOS)
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale ?? (NSScreen.main?.backingScaleFactor ?? 2)
        guard let cgImage = renderer.cgImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    /// A flat swatch of one color.
    @MainActor
    public static func solidPNG(_ rgba: RGBA, size: CGSize = defaultSize) -> Data? {
        png(Rectangle().fill(rgba.color), size: size, opaque: rgba.alpha >= 1)
    }

    /// A left-to-right gradient of the given colors.
    @MainActor
    public static func gradientPNG(_ colors: [RGBA], size: CGSize = defaultSize) -> Data? {
        let stops = colors.isEmpty ? [Color.clear, Color.clear] : colors.map(\.color)
        return png(LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing), size: size, opaque: colors.allSatisfy { $0.alpha >= 1 } && !colors.isEmpty)
    }

    #if canImport(UIKit) && !os(watchOS)
    @MainActor
    public static func uiImage<Content: View>(_ content: Content, size: CGSize, opaque: Bool = false) -> UIImage? {
        png(content, size: size, opaque: opaque).flatMap(UIImage.init(data:))
    }
    #endif
}

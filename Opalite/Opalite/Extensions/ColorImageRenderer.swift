//
//  ColorImageRenderer.swift
//  Opalite
//
//  Created by Nick Molargik on 12/25/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - ColorImageRenderer

/// A utility for rendering color swatches and gradients as images.
///
/// This consolidates image rendering logic that was previously scattered across
/// `SwatchView`, `ShareSheetPresenter`, and other files. It handles platform-specific
/// rendering for iOS, macOS, and visionOS.
///
/// ## Usage
/// ```swift
/// // Render a single color
/// let image = ColorImageRenderer.renderSolidColor(color, size: CGSize(width: 512, height: 512))
///
/// // Render a gradient from multiple colors
/// let gradientImage = ColorImageRenderer.renderGradient(colors: [color1, color2], size: size)
///
/// // Render a SwiftUI view as image data
/// let data = ColorImageRenderer.renderView(myView, size: size, opaque: false)
/// ```
enum ColorImageRenderer {

    /// Default size for rendered images
    static let defaultSize = CGSize(width: 512, height: 512)

    // MARK: - Public Methods

    /// Renders a solid color as a UIImage.
    ///
    /// - Parameters:
    ///   - color: The OpaliteColor to render
    ///   - size: The size of the output image (default: 512x512)
    /// - Returns: A UIImage of the solid color, or nil if rendering fails
    #if canImport(UIKit)
    static func renderSolidColor(_ color: OpaliteColor, size: CGSize = defaultSize) -> UIImage? {
        let view = Rectangle()
            .fill(color.swiftUIColor)
            .frame(width: size.width, height: size.height)

        return renderViewAsUIImage(view, size: size, opaque: color.alpha >= 1.0)
    }
    #endif

    /// Renders a gradient from an array of colors as a UIImage.
    ///
    /// - Parameters:
    ///   - colors: The OpaliteColors to use in the gradient (left to right)
    ///   - size: The size of the output image (default: 512x512)
    /// - Returns: A UIImage of the gradient, or nil if rendering fails
    #if canImport(UIKit)
    static func renderGradient(colors: [OpaliteColor], size: CGSize = defaultSize) -> UIImage? {
        let swiftUIColors = colors.map { $0.swiftUIColor }
        let gradientColors = swiftUIColors.isEmpty ? [Color.clear, Color.clear] : swiftUIColors
        let isOpaque = !colors.isEmpty && colors.allSatisfy { $0.alpha >= 1.0 }

        let view = LinearGradient(
            colors: gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size.width, height: size.height)

        return renderViewAsUIImage(view, size: size, opaque: isOpaque)
    }
    #endif

    /// Renders any SwiftUI view as PNG data.
    ///
    /// This method handles platform-specific rendering with proper scale factors
    /// and works around known issues with transparent content on iPad.
    ///
    /// - Parameters:
    ///   - content: The SwiftUI view to render
    ///   - size: The size of the output image
    ///   - opaque: Whether the image should be opaque (affects rendering quality)
    /// - Returns: PNG data of the rendered view, or nil if rendering fails
    static func renderViewAsPNGData<Content: View>(_ content: Content, size: CGSize, opaque: Bool = false) -> Data? {
        #if canImport(UIKit)
        return renderViewAsUIImage(content, size: size, opaque: opaque)?.pngData()
        #elseif os(macOS) && !targetEnvironment(macCatalyst)
        return renderViewAsNSImageData(content, size: size)
        #else
        return nil
        #endif
    }

    // MARK: - Platform-Specific Rendering

    #if canImport(UIKit)
    /// Renders a SwiftUI view as a UIImage using the best available method.
    ///
    /// On iOS 16+, uses `ImageRenderer` for optimal performance.
    /// Falls back to `UIHostingController` + `drawHierarchy` on older versions.
    ///
    /// - Parameters:
    ///   - content: The SwiftUI view to render
    ///   - size: The size of the output image
    ///   - opaque: Whether the image should be opaque
    /// - Returns: A UIImage of the rendered view, or nil if rendering fails
    private static func renderViewAsUIImage<Content: View>(_ content: Content, size: CGSize, opaque: Bool) -> UIImage? {
        // Use ImageRenderer on iOS 16+ for best results
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
            renderer.proposedSize = ProposedViewSize(size)
            renderer.isOpaque = opaque

            // Get display scale from trait collection (avoids deprecated UIScreen.main)
            let hostingController = UIHostingController(rootView: content)
            hostingController.view.frame = CGRect(origin: .zero, size: size)
            renderer.scale = hostingController.traitCollection.displayScale

            return renderer.uiImage
        }

        // Fallback for iOS 15 and earlier
        return renderViewWithHostingController(content, size: size, opaque: opaque)
    }

    /// Fallback rendering method using UIHostingController for iOS 15 and earlier.
    ///
    /// - Parameters:
    ///   - content: The SwiftUI view to render
    ///   - size: The size of the output image
    ///   - opaque: Whether the image should be opaque
    /// - Returns: A UIImage of the rendered view, or nil if rendering fails
    private static func renderViewWithHostingController<Content: View>(_ content: Content, size: CGSize, opaque: Bool) -> UIImage? {
        let controller = UIHostingController(rootView: content.frame(width: size.width, height: size.height))
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = opaque ? .white : .clear
        controller.view.isOpaque = opaque

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = controller.traitCollection.displayScale
        format.opaque = opaque

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    #endif

    #if os(macOS) && !targetEnvironment(macCatalyst)
    /// Renders a SwiftUI view as PNG data on macOS using NSHostingView.
    ///
    /// Uses AppKit's caching APIs to avoid coordinate-system issues that can
    /// produce transparent strips when rendering with raw Core Graphics contexts.
    ///
    /// - Parameters:
    ///   - content: The SwiftUI view to render
    ///   - size: The size of the output image
    /// - Returns: PNG data of the rendered view, or nil if rendering fails
    private static func renderViewAsNSImageData<Content: View>(_ content: Content, size: CGSize) -> Data? {
        let hostingView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }

        rep.size = hostingView.bounds.size
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        return rep.representation(using: .png, properties: [:])
    }
    #endif
}

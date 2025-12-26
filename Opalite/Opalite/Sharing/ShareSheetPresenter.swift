//
//  ShareSheetPresenter.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import LinkPresentation

// MARK: - Image Activity Item Source

final class ImageActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

// MARK: - Share Sheet Presenter

struct ShareSheetPresenter: UIViewControllerRepresentable {
    let image: UIImage?
    let title: String
    @Binding var isPresented: Bool

    init(image: UIImage?, title: String = "Shared from Opalite", isPresented: Binding<Bool>) {
        self.image = image
        self.title = title
        self._isPresented = isPresented
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let image else { return }
        let itemSource = ImageActivityItemSource(image: image, title: title)
        let activity = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { isPresented = false }
        }
        // Configure popover for iPad to avoid crash: sourceView/sourceRect required
        if let popover = activity.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = uiViewController.view.bounds
            popover.permittedArrowDirections = []
        }
        if uiViewController.presentedViewController == nil {
            uiViewController.present(activity, animated: true)
        }
    }
}

// MARK: - File Share Sheet

struct FileShareSheetPresenter: UIViewControllerRepresentable {
    let fileURL: URL?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let url = fileURL else { return }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                isPresented = false
                // Clean up temp file after sharing
                try? FileManager.default.removeItem(at: url)
            }
        }

        // Configure popover for iPad to avoid crash
        if let popover = activity.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = uiViewController.view.bounds
            popover.permittedArrowDirections = []
        }

        if uiViewController.presentedViewController == nil {
            uiViewController.present(activity, animated: true)
        }
    }
}

// MARK: - Image Rendering Helpers

/// Renders a gradient image from an array of colors.
///
/// This is a convenience wrapper around `ColorImageRenderer.renderGradient`.
///
/// - Parameters:
///   - colors: The colors to use in the gradient
///   - size: The size of the output image
/// - Returns: A UIImage of the gradient, or nil if rendering fails
func gradientImage(from colors: [OpaliteColor], size: CGSize = ColorImageRenderer.defaultSize) -> UIImage? {
    ColorImageRenderer.renderGradient(colors: colors, size: size)
}

/// Renders a solid color image.
///
/// This is a convenience wrapper around `ColorImageRenderer.renderSolidColor`.
///
/// - Parameters:
///   - color: The color to render
///   - size: The size of the output image
/// - Returns: A UIImage of the solid color, or nil if rendering fails
func solidColorImage(from color: OpaliteColor, size: CGSize = ColorImageRenderer.defaultSize) -> UIImage? {
    ColorImageRenderer.renderSolidColor(color, size: size)
}

//
//  ShareSheetPresenter.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI

struct ShareSheetPresenter: UIViewControllerRepresentable {
    let image: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let image else { return }
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
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

// MARK: - Helpers
func gradientImage(from colors: [OpaliteColor], size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
    // Convert palette colors to SwiftUI Color; fallback to clear if empty
    let uiColors: [Color] = colors.map { $0.swiftUIColor }
    let contentIsOpaque = !colors.isEmpty && colors.allSatisfy { $0.alpha >= 1.0 }
    let gradientColors = uiColors.isEmpty ? [Color.clear, Color.clear] : uiColors
    let view = LinearGradient(
        colors: gradientColors,
        startPoint: .leading,
        endPoint: .trailing
    )
    .frame(width: size.width, height: size.height)
    .clipped()

    // Render SwiftUI view to UIImage
    let renderer = ImageRenderer(content: view)
    renderer.scale = UIScreen.main.scale
    renderer.proposedSize = .init(size)
    renderer.isOpaque = contentIsOpaque
    return renderer.uiImage
}

func solidColorImage(from color: OpaliteColor, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
    let view = Rectangle()
        .fill(color.swiftUIColor)
        .frame(width: size.width, height: size.height)
        .clipped()

    let renderer = ImageRenderer(content: view)
    renderer.scale = UIScreen.main.scale
    renderer.proposedSize = .init(size)
    renderer.isOpaque = color.alpha >= 1.0
    return renderer.uiImage
}

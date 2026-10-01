//
//  ShareViewController.swift
//  OpaliteShareExtension
//
//  Receives one image from the share sheet, drops it in the App Group hand-off file,
//  and opens the app on the photo sampler.
//

import UIKit
import UniformTypeIdentifiers
import OpaliteCore
import os

final class ShareViewController: UIViewController {
    private let store = SharedImageStore()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await handleSharedContent() }
    }

    private func handleSharedContent() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let attachment = items.lazy.compactMap(\.attachments).joined().first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard let attachment, let image = await loadImage(from: attachment), let png = image.pngData(), store.save(pngData: png) else {
            complete(success: false)
            return
        }
        open(DeepLink.sharedImage.url)
        complete(success: true)
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error { Log.sharing.error("Share image load failed: \(error.localizedDescription)") }
                let image: UIImage?
                switch item {
                case let url as URL: image = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
                case let data as Data: image = UIImage(data: data)
                case let uiImage as UIImage: image = uiImage
                default: image = nil
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// Extensions can't call `UIApplication.shared`; walk the responder chain instead.
    private func open(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    private func complete(success: Bool) {
        if success {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: "com.molargiksoftware.OpaliteShareExtension", code: 1))
        }
    }
}

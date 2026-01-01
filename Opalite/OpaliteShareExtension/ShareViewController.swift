//
//  ShareViewController.swift
//  OpaliteShareExtension
//
//  Created by Nick Molargik on 1/1/26.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupIdentifier = "group.com.molargiksoftware.Opalite"
    private let sharedImageFileName = "shared_image.png"

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeRequest(success: false)
            return
        }

        // Find the first image attachment
        for inputItem in inputItems {
            guard let attachments = inputItem.attachments else { continue }

            for attachment in attachments {
                // Check for image types
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    loadImage(from: attachment)
                    return
                }
            }
        }

        // No image found
        completeRequest(success: false)
    }

    private func loadImage(from attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            if let error = error {
                print("[ShareExtension] Error loading image: \(error)")
                self.completeRequest(success: false)
                return
            }

            var image: UIImage?

            if let url = item as? URL {
                // Image provided as file URL
                if let data = try? Data(contentsOf: url) {
                    image = UIImage(data: data)
                }
            } else if let data = item as? Data {
                // Image provided as raw data
                image = UIImage(data: data)
            } else if let uiImage = item as? UIImage {
                // Image provided directly
                image = uiImage
            }

            if let image = image {
                self.saveAndOpenApp(image: image)
            } else {
                self.completeRequest(success: false)
            }
        }
    }

    private func saveAndOpenApp(image: UIImage) {
        // Save the image to the shared App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            completeRequest(success: false)
            return
        }

        let fileURL = containerURL.appendingPathComponent(sharedImageFileName)

        guard let pngData = image.pngData() else {
            completeRequest(success: false)
            return
        }

        do {
            try pngData.write(to: fileURL, options: .atomic)
        } catch {
            print("[ShareExtension] Failed to save image: \(error)")
            completeRequest(success: false)
            return
        }

        // Open the main app
        openMainApp()
    }

    private func openMainApp() {
        // Use the app's URL scheme to open it
        let urlString = "opalite://sharedImage"
        guard let url = URL(string: urlString) else {
            completeRequest(success: true)
            return
        }

        // Open the containing app via responder chain
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.completeRequest(success: true)
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: use openURL selector if available
        let selector = sel_registerName("openURL:")
        responder = self
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }

        completeRequest(success: true)
    }

    private func completeRequest(success: Bool) {
        DispatchQueue.main.async { [weak self] in
            if success {
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            } else {
                let error = NSError(domain: "com.molargiksoftware.OpaliteShareExtension", code: 1, userInfo: nil)
                self?.extensionContext?.cancelRequest(withError: error)
            }
        }
    }
}

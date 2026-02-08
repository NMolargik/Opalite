//
//  SharedImageManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/31/25.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages shared images between the Share Extension and the main app via App Groups.
final class SharedImageManager {
    static let shared = SharedImageManager()

    private let appGroupIdentifier = "group.com.molargiksoftware.Opalite"
    private let sharedImageFileName = "shared_image.png"

    private init() {}

    /// Returns the shared container URL for the App Group.
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Returns the URL for the shared image file.
    private var sharedImageURL: URL? {
        sharedContainerURL?.appendingPathComponent(sharedImageFileName)
    }

    /// Checks if a shared image exists.
    /// - Returns: True if a shared image is waiting to be processed.
    func hasSharedImage() -> Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let url = sharedImageURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
        #else
        return false
        #endif
    }

    /// Clears the shared image from the container.
    func clearSharedImage() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let url = sharedImageURL else { return }
        try? FileManager.default.removeItem(at: url)
        #endif
    }

    #if canImport(UIKit)
    /// Saves an image to the shared container for the main app to pick up.
    /// - Parameter image: The UIImage to save.
    /// - Returns: True if the image was saved successfully.
    @discardableResult
    func saveSharedImage(_ image: UIImage) -> Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let url = sharedImageURL,
              let data = image.pngData() else {
            return false
        }

        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("[SharedImageManager] Failed to save shared image: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Loads the shared image from the container if one exists.
    /// - Returns: The shared UIImage, or nil if none exists.
    func loadSharedImage() -> UIImage? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let url = sharedImageURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
        #else
        return nil
        #endif
    }
    #endif
}

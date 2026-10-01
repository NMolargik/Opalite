//
//  SharedImageStore.swift
//  OpaliteCore
//
//  The hand-off file the Share Extension writes and the app consumes (an image to sample
//  colors from). Pure file I/O over the App Group container so it's host-testable.
//

import Foundation

nonisolated public struct SharedImageStore: Sendable {
    public static let fileName = "shared_image.png"

    private let containerURL: URL?

    public init(containerURL: URL? = AppGroup.containerURL) {
        self.containerURL = containerURL
    }

    public var fileURL: URL? { containerURL?.appendingPathComponent(Self.fileName) }

    public var hasSharedImage: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Writes PNG data for the app to pick up. Returns whether the write succeeded.
    @discardableResult
    public func save(pngData: Data) -> Bool {
        guard let fileURL else { return false }
        do {
            try pngData.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// The pending image data, if any.
    public func load() -> Data? {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    public func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

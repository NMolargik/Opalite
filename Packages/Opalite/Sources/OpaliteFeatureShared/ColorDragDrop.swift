//
//  ColorDragDrop.swift
//  OpaliteFeatureShared
//
//  Drag-and-drop for colors: the item provider a swatch vends (PNG for other apps, the
//  native JSON for cross-device drops, the id for same-device palette moves) and the
//  drop handler that moves or imports into a palette through the portfolio model.
//

#if !os(watchOS) && !os(tvOS)
import SwiftUI
import UniformTypeIdentifiers
import OpaliteCore
import OpaliteDesignSystem
import os

nonisolated extension UTType {
    /// Drag & drop identifier for an OpaliteColor UUID string.
    public static let opaliteColorID = UTType(exportedAs: OpaliteFileType.colorIDIdentifier, conformingTo: .plainText)
    /// Shareable file type for a single color (.opalitecolor).
    public static let opaliteColor = UTType(exportedAs: OpaliteFileType.colorIdentifier, conformingTo: .json)
    /// Shareable file type for a palette (.opalitepalette).
    public static let opalitePalette = UTType(exportedAs: OpaliteFileType.paletteIdentifier, conformingTo: .json)
}

public enum ColorDragDrop {
    /// Every type a swatch drop target accepts.
    public static let acceptedTypes: [UTType] = [.opaliteColor, .opaliteColorID, .png, .image]

    /// Builds the provider for dragging `color`; `pngData` is the rendered swatch image.
    @MainActor
    public static func itemProvider(for color: OpaliteColor, pngData: Data?) -> NSItemProvider {
        let provider: NSItemProvider
        if let pngData {
            provider = NSItemProvider(item: pngData as NSData, typeIdentifier: UTType.png.identifier)
        } else {
            provider = NSItemProvider()
        }
        provider.suggestedName = color.hasName ? "\(color.displayName).png" : "\(ExportEncoders.filename(fromHex: color.hexString)).png"

        let json = try? color.jsonRepresentation()
        let idData = Data(color.id.uuidString.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.opaliteColor.identifier, visibility: .all) { completion in
            completion(json, json == nil ? CocoaError(.coderInvalidValue) : nil)
            return nil
        }
        provider.registerDataRepresentation(forTypeIdentifier: UTType.opaliteColorID.identifier, visibility: .all) { completion in
            completion(idData, nil)
            return nil
        }
        return provider
    }

    /// Handles a drop of providers onto `palette` (nil = the loose colors area):
    /// same-device drops move the existing color; cross-device drops import it.
    /// Returns whether a provider was recognized.
    @MainActor
    public static func handleDrop(_ providers: [NSItemProvider], into palette: OpalitePalette?, portfolio: PortfolioModel) -> Bool {
        let idProvider = providers.first { $0.hasItemConformingToTypeIdentifier(UTType.opaliteColorID.identifier) }
        let jsonProvider = providers.first { $0.hasItemConformingToTypeIdentifier(UTType.opaliteColor.identifier) }
        guard idProvider != nil || jsonProvider != nil else { return false }
        let paletteID = palette?.id

        Task { @MainActor in
            if let idProvider,
               let data = await idProvider.data(for: .opaliteColorID),
               let text = String(data: data, encoding: .utf8),
               let id = UUID(uuidString: text),
               let color = portfolio.color(withID: id) {
                move(color, intoPaletteID: paletteID, portfolio: portfolio)
                return
            }
            // Not local (Universal Control / another device): import from the JSON.
            guard let jsonProvider,
                  let data = await jsonProvider.data(for: .opaliteColor),
                  let decoded = try? OpaliteFileCodec.decodeColor(from: data) else { return }
            if let existing = portfolio.color(withID: decoded.id) {
                move(existing, intoPaletteID: paletteID, portfolio: portfolio)
                return
            }
            // Generated harmony names shouldn't persist on a dropped copy.
            let generated = ["Complementary", "Analogous", "Triadic", "Tetradic", "Split-Comp"]
            let name = generated.contains(decoded.name ?? "") ? nil : decoded.name
            let target = paletteID.flatMap { portfolio.palette(withID: $0) }
            _ = portfolio.createColor(decoded.rgba, name: name, notes: decoded.notes, in: target)
            Haptics.success()
        }
        return true
    }

    @MainActor
    private static func move(_ color: OpaliteColor, intoPaletteID paletteID: UUID?, portfolio: PortfolioModel) {
        guard color.palette?.id != paletteID else { return }
        let target = paletteID.flatMap { portfolio.palette(withID: $0) }
        Haptics.lightImpact()
        portfolio.move(color, to: target)
    }
}

extension NSItemProvider {
    /// Loads a data representation without the completion-handler dance.
    @MainActor func data(for type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
#endif

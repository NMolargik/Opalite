//
//  ExportTransfer.swift
//  OpaliteFeatureSharing
//
//  The system-sharing faces of an `ExportedFile`: `Transferable` for `ShareLink` (PNGs
//  travel as image data so "Save Image" shows up; everything else as the file itself) and
//  `FileDocument` for `.fileExporter` ("Save to Files").
//

import SwiftUI
import UniformTypeIdentifiers
import OpaliteCore

// MARK: - ShareLink

extension ExportedFile: Transferable {
    nonisolated public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { file in file.data }
            .exportingCondition { file in file.contentType == .png }
        ProxyRepresentation(exporting: \.url)
    }
}

// MARK: - Files

#if os(iOS) || os(visionOS) || os(macOS)
/// Wraps an export's bytes for `.fileExporter`; the sheet picks the content type per format.
nonisolated public struct ExportFileDocument: FileDocument {
    public static let readableContentTypes: [UTType] = [.data]
    public static let writableContentTypes: [UTType] = ExportContentType.all

    public let data: Data

    public init(_ file: ExportedFile) {
        data = file.data
    }

    public init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif

//
//  FileHandlerError.swift
//  Opalite
//
//  Shared error type for QuickLook preview and Thumbnail extension targets.
//

import Foundation

enum FileHandlerError: Error {
    case invalidFormat
    case decodingFailed
}

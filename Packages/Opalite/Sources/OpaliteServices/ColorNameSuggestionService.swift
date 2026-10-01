//
//  ColorNameSuggestionService.swift
//  OpaliteServices
//
//  Creative color names from the on-device Foundation Models session (iOS 26+). The
//  prompt and parser are pure (`ColorNamePrompt` in Core); this is just the session.
//

import Foundation
import Observation
import OpaliteCore
import os
#if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
import FoundationModels
#endif

@MainActor
@Observable
public final class ColorNameSuggestionService: ColorNaming {
    public private(set) var isAvailable = false

    public init() {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            isAvailable = SystemLanguageModel.default.isAvailable
        }
        #endif
    }

    public func suggestNames(for color: RGBA, count: Int = ColorNamePrompt.defaultCount) async throws -> [String] {
        #if canImport(FoundationModels) && !os(tvOS) && !os(watchOS)
        guard isAvailable else { return [] }
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: ColorNamePrompt.build(for: color, count: count))
            return ColorNamePrompt.parse(response.content, count: count)
        }
        #endif
        return []
    }
}

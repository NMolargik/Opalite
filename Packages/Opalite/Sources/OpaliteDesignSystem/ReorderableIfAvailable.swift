//
//  ReorderableIfAvailable.swift
//  OpaliteDesignSystem
//
//  Drag-to-reorder for `ForEach` content on iOS/visionOS 27+ (no-op elsewhere).
//  `onMove` remains the universal path: apply `.onMove(perform:)` to the ForEach first,
//  then `.reorderableIfAvailable()`.
//

import SwiftUI

extension DynamicViewContent {
    @ContentBuilder
    public func reorderableIfAvailable() -> some View {
        #if os(tvOS) || os(watchOS)
        self
        #else
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            reorderable()
        } else {
            self
        }
        #endif
    }
}

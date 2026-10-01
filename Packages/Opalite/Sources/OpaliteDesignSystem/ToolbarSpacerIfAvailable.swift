//
//  ToolbarSpacerIfAvailable.swift
//  OpaliteDesignSystem
//
//  Groups Liquid Glass toolbar items with a `ToolbarSpacer` on iOS/macOS/visionOS 26+ and
//  contributes nothing on earlier systems (and on tvOS/watchOS, which have no toolbar
//  spacers). Use it between toolbar items instead of writing `#available` in features:
//
//      .toolbar {
//          ToolbarItem(placement: .topBarTrailing) { sortMenu }
//          ToolbarSpacerIfAvailable(.fixed, placement: .topBarTrailing)
//          ToolbarItem(placement: .topBarTrailing) { infoButton }
//      }
//

import SwiftUI

public struct ToolbarSpacerIfAvailable: ToolbarContent {
    public enum Sizing: Sendable {
        case fixed
        case flexible
    }

    private let sizing: Sizing
    private let placement: ToolbarItemPlacement

    public init(_ sizing: Sizing = .fixed, placement: ToolbarItemPlacement = .automatic) {
        self.sizing = sizing
        self.placement = placement
    }

    public var body: some ToolbarContent {
        #if os(tvOS) || os(watchOS) || os(visionOS)
        ToolbarItem(placement: placement) { EmptyView() }
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            switch sizing {
            case .fixed: ToolbarSpacer(.fixed, placement: placement)
            case .flexible: ToolbarSpacer(.flexible, placement: placement)
            }
        } else {
            ToolbarItem(placement: placement) { EmptyView() }
        }
        #endif
    }
}

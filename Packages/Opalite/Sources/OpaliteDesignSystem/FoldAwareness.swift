//
//  FoldAwareness.swift
//  OpaliteDesignSystem
//
//  iPhone Duo's hinge and cameras are "reserved regions" (iOS 27.1). These helpers keep
//  the availability check out of feature code, like the other `…IfAvailable` helpers.
//

import SwiftUI

nonisolated public extension GeometryProxy {
    /// Whether this view's window can be divided by a hardware fold, whether or not the
    /// device is folded right now. Grids use it to prefer an even number of columns.
    var hasFoldIfAvailable: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            return !reservedRegions(kind: .division, options: .includeInactive).isEmpty
        }
        #endif
        return false
    }

    /// Whether a fold currently divides this view (the device is partially open). Layouts
    /// widen the gap between columns so nothing sits in the curve.
    var isFoldActiveIfAvailable: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            return !reservedRegions(kind: .division).isEmpty
        }
        #endif
        return false
    }
}

/// What an adaptive layout reads from its container in one geometry pass.
nonisolated public struct LayoutProbe: Equatable, Sendable {
    public var width: CGFloat
    public var hasFold: Bool
    public var isFoldActive: Bool

    public init(width: CGFloat = 0, hasFold: Bool = false, isFoldActive: Bool = false) {
        self.width = width
        self.hasFold = hasFold
        self.isFoldActive = isFoldActive
    }

    public init(_ proxy: GeometryProxy) {
        self.init(width: proxy.size.width, hasFold: proxy.hasFoldIfAvailable, isFoldActive: proxy.isFoldActiveIfAvailable)
    }
}

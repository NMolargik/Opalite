//
//  UncheckedSendableBox.swift
//  OpaliteCore
//
//  Carries a non-Sendable system object (WCSession reply handlers, UIKit values) across an
//  isolation boundary when the framework contract guarantees single ownership.
//

import Foundation

nonisolated public struct UncheckedSendableBox<Value>: @unchecked Sendable {
    public let value: Value
    public init(value: Value) { self.value = value }
}

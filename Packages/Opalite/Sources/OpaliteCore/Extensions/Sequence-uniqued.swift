//
//  Sequence-uniqued.swift
//  OpaliteCore
//

import Foundation

nonisolated extension Sequence where Element: Hashable {
    /// The elements in first-seen order with duplicates removed.
    public func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

nonisolated extension Sequence {
    /// The elements in first-seen order with duplicates (by `key`) removed.
    public func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}

//
//  GridColumns.swift
//  OpaliteCore
//
//  Column counts for the swatch and card grids. Pure so the rules are host-tested; the
//  "prefer even" option exists for iPhone Duo, where a hinge can divide the window and an
//  even count keeps every card on one side of it.
//

import Foundation

nonisolated public enum GridColumns {
    /// How many columns of at least `minimum` points fit in `width` with `spacing` between
    /// them, never fewer than one. With `preferEven`, an odd count above one drops to the
    /// next even number so a fold through the middle never splits a card.
    public static func count(fitting width: CGFloat, minimum: CGFloat, spacing: CGFloat, preferEven: Bool = false) -> Int {
        guard width > 0, minimum > 0 else { return 1 }
        var count = max(1, Int(((width + spacing) / (minimum + spacing)).rounded(.down)))
        if preferEven, count > 1, count % 2 == 1 { count -= 1 }
        return count
    }
}

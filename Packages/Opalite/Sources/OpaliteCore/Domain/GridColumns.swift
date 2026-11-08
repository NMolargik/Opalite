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
    /// Tiles may shrink to this fraction of `minimum` to avoid a lone tile on the last row.
    public static let relaxedFactor: CGFloat = 0.8

    public static func count(fitting width: CGFloat, minimum: CGFloat, spacing: CGFloat, preferEven: Bool = false, items: Int? = nil) -> Int {
        guard width > 0, minimum > 0 else { return 1 }
        var count = max(1, Int(((width + spacing) / (minimum + spacing)).rounded(.down)))
        if preferEven, count > 1, count % 2 == 1 { count -= 1 }
        guard let items, items > count, count > 1, items % count == 1 else { return count }
        // A lone tile on the last row: take one more column if tiles can shrink a little
        // (kept even on a fold), else one fewer when that divides the items evenly.
        let step = preferEven ? 2 : 1
        let wider = count + step
        if items % wider != 1, wider <= items,
           Int(((width + spacing) / (minimum * relaxedFactor + spacing)).rounded(.down)) >= wider {
            return wider
        }
        let narrower = count - step
        if narrower >= 2, items % narrower == 0 { return narrower }
        return count
    }
}

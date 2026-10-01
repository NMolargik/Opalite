//
//  OpaliteFileDecoder.swift
//  Opalite
//
//  Created by Nick Molargik on 2/8/26.
//
//  Shared between QuickLook and Thumbnail extension targets.
//  Add this file to both OpaliteQuickLook and OpaliteThumbnail targets in Xcode.
//

import UIKit

enum OpaliteFileDecoder {
    static func decodeColor(from json: [String: Any]) -> UIColor? {
        guard let red = json["red"] as? Double,
              let green = json["green"] as? Double,
              let blue = json["blue"] as? Double else {
            return nil
        }
        let alpha = json["alpha"] as? Double ?? 1.0
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

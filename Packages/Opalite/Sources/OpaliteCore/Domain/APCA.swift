//
//  APCA.swift
//  OpaliteCore
//
//  APCA (Accessible Perceptual Contrast Algorithm) lightness contrast, W3 0.0.98G-4g constants.
//  Supplemental to WCAG 2.x — shown beside it, never replacing it.
//

import Foundation

nonisolated public enum APCA {
    private static let mainTRC = 2.4
    private static let normBG = 0.56, normTXT = 0.57, revTXT = 0.62, revBG = 0.65
    private static let blkThrs = 0.022, blkClmp = 1.414
    private static let scaleBoW = 1.14, scaleWoB = 1.14
    private static let loBoWoffset = 0.027, loWoBoffset = 0.027
    private static let deltaYmin = 0.0005, loClip = 0.1

    /// APCA's screen luminance (plain 2.4 gamma, not the piecewise sRGB curve).
    public static func luminance(_ color: RGBA) -> Double {
        func channel(_ c: Double) -> Double { pow(ColorMath.clamp(c), mainTRC) }
        return 0.2126729 * channel(color.red) + 0.7151522 * channel(color.green) + 0.0721750 * channel(color.blue)
    }

    /// Lc for `text` on `background`: positive for dark-on-light, negative for light-on-dark (≈ -108...106).
    public static func contrast(text: RGBA, background: RGBA) -> Double {
        lc(textY: luminance(text), backgroundY: luminance(background))
    }

    static func lc(textY: Double, backgroundY: Double) -> Double {
        func soft(_ y: Double) -> Double { y >= blkThrs ? y : y + pow(blkThrs - y, blkClmp) }
        let yt = soft(textY), yb = soft(backgroundY)
        guard abs(yb - yt) >= deltaYmin else { return 0 }
        if yb > yt {
            let sapc = (pow(yb, normBG) - pow(yt, normTXT)) * scaleBoW
            return (sapc < loClip ? 0 : sapc - loBoWoffset) * 100
        } else {
            let sapc = (pow(yb, revBG) - pow(yt, revTXT)) * scaleWoB
            return (sapc > -loClip ? 0 : sapc + loWoBoffset) * 100
        }
    }

    /// "Lc 63" style text using the magnitude (polarity is shown separately).
    public static func lcText(_ lc: Double) -> String { String(format: "Lc %.0f", abs(lc)) }

    /// Rough guidance bands from the APCA readability guide (|Lc|).
    public enum Band: Sendable, Equatable {
        case fail        // < 30
        case spot        // 30–44: large/incidental only
        case large       // 45–59: large headlines
        case content     // 60–74: content text, large body
        case body        // 75–89: body text
        case fluent      // 90+: fluent reading

        public init(lc: Double) {
            switch abs(lc) {
            case ..<30: self = .fail
            case ..<45: self = .spot
            case ..<60: self = .large
            case ..<75: self = .content
            case ..<90: self = .body
            default: self = .fluent
            }
        }
    }
}

// MARK: - Suggest a fix

nonisolated extension ColorMath {
    /// Nudges `foreground`'s OKLCH lightness (hue and chroma kept, gamut-mapped) toward whichever
    /// extreme contrasts more with `background`, returning the closest color that reaches
    /// `targetRatio`. Nil when already passing or when even the extreme can't reach it.
    public static func suggestForeground(
        _ foreground: RGBA,
        on background: RGBA,
        targetRatio: Double = 4.5
    ) -> RGBA? {
        guard foreground.contrastRatio(against: background) < targetRatio else { return nil }
        let start = foreground.oklch
        let towardsLight = white(on: background)
        let endL = towardsLight ? 1.0 : 0.0
        func candidate(_ t: Double) -> RGBA {
            var lch = start
            lch.lightness = start.lightness + (endL - start.lightness) * t
            var mapped = lch.gamutMappedRGBA
            mapped.alpha = foreground.alpha
            return mapped
        }
        guard candidate(1).contrastRatio(against: background) >= targetRatio else { return nil }
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let mid = (low + high) / 2
            if candidate(mid).contrastRatio(against: background) >= targetRatio { high = mid } else { low = mid }
        }
        return candidate(high)
    }

    private static func white(on background: RGBA) -> Bool {
        RGBA.white.contrastRatio(against: background) >= RGBA.black.contrastRatio(against: background)
    }
}

//
//  PaletteExtractor.swift
//  OpaliteCore
//
//  Pure palette extraction: weighted color samples are clustered in OKLab with a seeded
//  k-means++ and reduced to a few representative, well-separated colors ordered by
//  lightness. The same input always yields the same palette. Images (downsampled pixels)
//  and websites (declared colors plus a rendered snapshot) both feed `PaletteSamples`.
//

import Foundation

/// One sample color with a relative weight (a pixel, or a color counted by frequency).
nonisolated public struct WeightedColor: Hashable, Sendable {
    public var rgba: RGBA
    public var weight: Double

    public init(_ rgba: RGBA, weight: Double = 1) {
        self.rgba = rgba
        self.weight = weight
    }
}

/// A color chosen by extraction, with how much of the source it represents (0...1).
nonisolated public struct ExtractedColor: Hashable, Sendable, Identifiable {
    public var rgba: RGBA
    /// Share of the source's weight this color stands for; all results sum to about 1.
    public var prominence: Double

    public var id: String { rgba.hexString }

    public init(rgba: RGBA, prominence: Double) {
        self.rgba = rgba
        self.prominence = prominence
    }
}

/// How extracted colors are ordered.
nonisolated public enum PaletteOrdering: Sendable {
    /// Dark to light (OKLab lightness).
    case lightness
    /// Most prominent first.
    case prominence
}

/// A reusable bag of weighted samples. Extraction can be re-run for any count without
/// re-reading the source image or website.
nonisolated public struct PaletteSamples: Sendable {
    public private(set) var samples: [WeightedColor]

    public init(_ samples: [WeightedColor] = []) {
        self.samples = samples.filter { $0.weight > 0 && $0.rgba.alpha >= PaletteExtractor.minimumAlpha }
    }

    public var isEmpty: Bool { samples.isEmpty }

    public var totalWeight: Double { samples.reduce(0) { $0 + $1.weight } }

    /// Samples from tightly packed 8-bit sRGB RGBA bytes (alpha not premultiplied).
    /// Fully or mostly transparent pixels are skipped.
    public init(rgba8 bytes: [UInt8]) {
        var out: [WeightedColor] = []
        out.reserveCapacity(bytes.count / 4)
        var index = 0
        while index + 3 < bytes.count {
            let alpha = Double(bytes[index + 3]) / 255
            if alpha >= PaletteExtractor.minimumAlpha {
                out.append(WeightedColor(RGBA(
                    red: Double(bytes[index]) / 255,
                    green: Double(bytes[index + 1]) / 255,
                    blue: Double(bytes[index + 2]) / 255
                )))
            }
            index += 4
        }
        self.init(out)
    }

    /// This source scaled so its weights sum to `total`, ready to blend with another.
    public func normalized(to total: Double = 1) -> PaletteSamples {
        let sum = totalWeight
        guard sum > 0 else { return self }
        let scale = total / sum
        return PaletteSamples(samples.map { WeightedColor($0.rgba, weight: $0.weight * scale) })
    }

    /// Blends several sources; each is normalized to its share of the whole.
    public static func blend(_ parts: [(PaletteSamples, share: Double)]) -> PaletteSamples {
        PaletteSamples(parts.flatMap { $0.0.normalized(to: $0.share).samples })
    }

    /// The representative palette: `count` is clamped to `PaletteExtractor.countRange`, and
    /// fewer colors come back when the source simply has less variety.
    public func palette(count: Int = 5, ordering: PaletteOrdering = .lightness) -> [ExtractedColor] {
        PaletteExtractor.extract(from: self, count: count, ordering: ordering)
    }
}

nonisolated public enum PaletteExtractor {
    /// The number of colors a palette may hold.
    public static let countRange = 3...8
    /// Samples below this alpha are treated as background, not color.
    public static let minimumAlpha = 0.5
    /// Two chosen colors must be at least this far apart in OKLab (ΔE ≈ 0.04 is "barely different").
    public static let minimumSeparation = 0.045
    /// Clusters standing for less than this share of the source are noise unless needed to reach the minimum.
    static let minimumShare = 0.01
    /// A fixed seed: extraction is deterministic for a given input.
    static let seed: UInt64 = 0x0A11_7E5E_ED5E_ED01
    /// Cap on samples clustered; larger inputs are strided down deterministically.
    static let maxSamples = 6_000
    static let iterations = 14

    public static func extract(from samples: PaletteSamples, count: Int = 5, ordering: PaletteOrdering = .lightness) -> [ExtractedColor] {
        let target = min(max(count, countRange.lowerBound), countRange.upperBound)
        let points = compact(samples.samples)
        guard !points.isEmpty else { return [] }

        // Over-cluster, then pick the most prominent clusters that stay apart from each other.
        let k = min(points.count, max(target * 2, 10))
        let clusters = kMeans(points, k: k)
        let total = clusters.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [] }

        let byWeight = clusters.sorted {
            $0.weight != $1.weight ? $0.weight > $1.weight : ($0.center.lightness, $0.center.a, $0.center.b) < ($1.center.lightness, $1.center.a, $1.center.b)
        }
        var chosen: [Cluster] = []
        for cluster in byWeight where chosen.count < target {
            guard cluster.weight / total >= minimumShare || chosen.count < countRange.lowerBound else { continue }
            if chosen.allSatisfy({ distance($0.center, cluster.center) >= minimumSeparation }) {
                chosen.append(cluster)
            }
        }
        // Fewer than the minimum survived the share cutoff: top up with the next most prominent distinct ones.
        if chosen.count < min(target, countRange.lowerBound) {
            for cluster in byWeight where chosen.count < min(target, countRange.lowerBound) && !chosen.contains(where: { $0.center == cluster.center }) {
                if chosen.allSatisfy({ distance($0.center, cluster.center) >= minimumSeparation / 2 }) { chosen.append(cluster) }
            }
        }

        let chosenWeight = chosen.reduce(0) { $0 + $1.weight }
        var results = chosen.map { cluster in
            ExtractedColor(rgba: toRGBA(cluster.center), prominence: chosenWeight > 0 ? cluster.weight / chosenWeight : 0)
        }
        switch ordering {
        case .lightness:
            results.sort { ColorSpaces.oklab(from: $0.rgba).lightness < ColorSpaces.oklab(from: $1.rgba).lightness }
        case .prominence:
            results.sort { $0.prominence > $1.prominence }
        }
        return results
    }

    // MARK: - Clustering

    struct Point {
        var lab: OKLab
        var weight: Double
    }

    struct Cluster {
        var center: OKLab
        var weight: Double
    }

    /// OKLab points; identical colors are merged (summing weights) and large inputs strided.
    static func compact(_ samples: [WeightedColor]) -> [Point] {
        // Quantize to 5 bits per channel to collapse noise; each bin keeps the weighted mean of
        // its members so flat colors survive exactly.
        var merged: [UInt32: (r: Double, g: Double, b: Double, w: Double)] = [:]
        for sample in samples {
            let r = UInt32((sample.rgba.red.clampedUnit * 31).rounded())
            let g = UInt32((sample.rgba.green.clampedUnit * 31).rounded())
            let b = UInt32((sample.rgba.blue.clampedUnit * 31).rounded())
            let key = r << 10 | g << 5 | b
            var bin = merged[key] ?? (0, 0, 0, 0)
            bin.r += sample.rgba.red.clampedUnit * sample.weight
            bin.g += sample.rgba.green.clampedUnit * sample.weight
            bin.b += sample.rgba.blue.clampedUnit * sample.weight
            bin.w += sample.weight
            merged[key] = bin
        }
        var points = merged.keys.sorted().map { key -> Point in
            let bin = merged[key]!
            return Point(lab: ColorSpaces.oklab(from: RGBA(red: bin.r / bin.w, green: bin.g / bin.w, blue: bin.b / bin.w)), weight: bin.w)
        }
        if points.count > maxSamples {
            // Keep the heaviest, which carry the palette; ties broken by key order (already sorted).
            points = points.enumerated().sorted { $0.element.weight != $1.element.weight ? $0.element.weight > $1.element.weight : $0.offset < $1.offset }
                .prefix(maxSamples).sorted { $0.offset < $1.offset }.map(\.element)
        }
        return points
    }

    static func distance(_ a: OKLab, _ b: OKLab) -> Double {
        let dl = a.lightness - b.lightness, da = a.a - b.a, db = a.b - b.b
        return (dl * dl + da * da + db * db).squareRoot()
    }

    static func kMeans(_ points: [Point], k: Int) -> [Cluster] {
        var rng = SplitMix64(seed: seed)
        var centers = seedCenters(points, k: k, rng: &rng)
        var assignment = [Int](repeating: 0, count: points.count)

        for _ in 0..<iterations {
            var sums = [(l: Double, a: Double, b: Double, w: Double)](repeating: (0, 0, 0, 0), count: centers.count)
            var moved = false
            for (index, point) in points.enumerated() {
                var best = 0, bestDistance = Double.infinity
                for (c, center) in centers.enumerated() {
                    let d = distance(point.lab, center)
                    if d < bestDistance { bestDistance = d; best = c }
                }
                if assignment[index] != best { moved = true; assignment[index] = best }
                sums[best].l += point.lab.lightness * point.weight
                sums[best].a += point.lab.a * point.weight
                sums[best].b += point.lab.b * point.weight
                sums[best].w += point.weight
            }
            for c in centers.indices where sums[c].w > 0 {
                centers[c] = OKLab(lightness: sums[c].l / sums[c].w, a: sums[c].a / sums[c].w, b: sums[c].b / sums[c].w)
            }
            if !moved { break }
        }

        var weights = [Double](repeating: 0, count: centers.count)
        for (index, point) in points.enumerated() { weights[assignment[index]] += point.weight }
        return centers.indices.compactMap { weights[$0] > 0 ? Cluster(center: centers[$0], weight: weights[$0]) : nil }
    }

    /// k-means++ seeding with a seeded generator.
    static func seedCenters(_ points: [Point], k: Int, rng: inout SplitMix64) -> [OKLab] {
        var centers: [OKLab] = []
        let totalWeight = points.reduce(0) { $0 + $1.weight }
        var pick = rng.nextUnit() * totalWeight
        var first = points.count - 1
        for (index, point) in points.enumerated() {
            pick -= point.weight
            if pick <= 0 { first = index; break }
        }
        centers.append(points[first].lab)
        var nearest = points.map { distance($0.lab, centers[0]) }

        while centers.count < k {
            var scores = 0.0
            let weighted = points.indices.map { index -> Double in
                let score = nearest[index] * nearest[index] * points[index].weight
                scores += score
                return score
            }
            guard scores > 0 else { break }
            var target = rng.nextUnit() * scores
            var chosen = points.count - 1
            for (index, score) in weighted.enumerated() {
                target -= score
                if target <= 0 { chosen = index; break }
            }
            let center = points[chosen].lab
            centers.append(center)
            for index in points.indices { nearest[index] = min(nearest[index], distance(points[index].lab, center)) }
        }
        return centers
    }

    static func toRGBA(_ lab: OKLab) -> RGBA {
        let lch = ColorSpaces.oklch(from: lab)
        let mapped = lch.gamutMappedRGBA
        return RGBA(red: mapped.red.clampedUnit, green: mapped.green.clampedUnit, blue: mapped.blue.clampedUnit)
    }
}

/// A small deterministic generator (SplitMix64), so extraction never depends on system randomness.
nonisolated struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform value in 0..<1.
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

private extension Double {
    nonisolated var clampedUnit: Double { min(max(self, 0), 1) }
}

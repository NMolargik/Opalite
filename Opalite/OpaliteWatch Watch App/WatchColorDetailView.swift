//
//  WatchColorDetailView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 2/7/26.
//

import SwiftUI

struct WatchColorDetailView: View {
    let color: WatchColor

    @Environment(WatchColorManager.self) private var colorManager
    @Environment(\.colorSchemeContrast) private var systemContrast
    @State private var showCopiedFeedback: Bool = false

    @ScaledMetric(relativeTo: .body) private var previewHeight: CGFloat = 100

    private var isHighContrast: Bool {
        systemContrast == .increased || colorManager.highContrastEnabled
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                colorPreview
                copyHexButton
                rgbSection
                hslSection
                cmykSection
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(color.name ?? "Color")
        .onAppear {
            colorManager.playNavigationHaptic()
        }
    }

    // MARK: - Color Preview

    private var colorPreview: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(color.swiftUIColor)
            .frame(height: previewHeight)
            .overlay {
                if let name = color.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(color.idealTextColor())
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                }
            }
            .overlay {
                if isHighContrast {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                }
            }
            .accessibilityLabel("Color preview, \(color.voiceOverDescription)")
    }

    // MARK: - Copy Hex

    private var copyHexButton: some View {
        Button {
            copyHex()
        } label: {
            HStack(spacing: 6) {
                Text(colorManager.formattedHex(for: color))
                    .fontDesign(.monospaced)
                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
            }
            .font(.caption)
            .frame(maxWidth: .infinity)
        }
        .tint(showCopiedFeedback ? .green : .white)
        .accessibilityLabel(showCopiedFeedback
            ? "Copied, \(colorManager.formattedHex(for: color))"
            : "Copy hex, \(colorManager.formattedHex(for: color))")
    }

    // MARK: - Value Sections

    private var rgbSection: some View {
        let r = Int(round(color.red * 255))
        let g = Int(round(color.green * 255))
        let b = Int(round(color.blue * 255))
        return valuesSection(title: "RGB", values: [
            ("R", "\(r)"),
            ("G", "\(g)"),
            ("B", "\(b)")
        ])
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RGB: Red \(r), Green \(g), Blue \(b)")
    }

    private var hslSection: some View {
        let hsl = color.hsl
        let h = Int(round(hsl.hue))
        let s = Int(round(hsl.saturation * 100))
        let l = Int(round(hsl.lightness * 100))
        return valuesSection(title: "HSL", values: [
            ("H", "\(h)"),
            ("S", "\(s)%"),
            ("L", "\(l)%")
        ])
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HSL: Hue \(h) degrees, Saturation \(s) percent, Lightness \(l) percent")
    }

    private var cmykSection: some View {
        let cmyk = color.cmyk
        let c = Int(round(cmyk.cyan * 100))
        let m = Int(round(cmyk.magenta * 100))
        let y = Int(round(cmyk.yellow * 100))
        let k = Int(round(cmyk.key * 100))
        return valuesSection(title: "CMYK", values: [
            ("C", "\(c)%"),
            ("M", "\(m)%"),
            ("Y", "\(y)%"),
            ("K", "\(k)%")
        ])
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CMYK: Cyan \(c) percent, Magenta \(m) percent, Yellow \(y) percent, Key \(k) percent")
    }

    private func valuesSection(title: String, values: [(String, String)]) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(values, id: \.0) { label, value in
                    VStack(spacing: 2) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(isHighContrast ? .primary : .secondary)
                        Text(value)
                            .font(.caption)
                            .fontWeight(.medium)
                            .fontDesign(.monospaced)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background {
                if isHighContrast {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Actions

    private func copyHex() {
        colorManager.playTapHaptic()

        let hex = colorManager.formattedHex(for: color)
        WatchSessionManager.shared.copyHexToiPhone(hex, colorName: color.name)

        withAnimation(.easeIn(duration: 0.15)) {
            showCopiedFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchColorDetailView(color: WatchColor.sample)
            .environment(WatchColorManager())
    }
}

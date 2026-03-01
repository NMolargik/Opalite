//
//  TVPresentationModeView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Full-screen color presentation mode for tvOS.
/// Optimized for TV viewing with large color display and remote navigation.
struct TVPresentationModeView: View {
    let colors: [OpaliteColor]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0

    init(colors: [OpaliteColor], startIndex: Int = 0) {
        self.colors = colors
        self.startIndex = startIndex
        self._currentIndex = State(initialValue: startIndex)
    }

    private var currentColor: OpaliteColor? {
        guard colors.indices.contains(currentIndex) else { return nil }
        return colors[currentIndex]
    }

    var body: some View {
        ZStack {
            // Full-screen color background
            if let color = currentColor {
                color.swiftUIColor
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            // Color info overlay
            VStack {
                Spacer()

                if let color = currentColor {
                    VStack(spacing: 16) {
                        if let name = color.name, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 72, weight: .bold))
                                .foregroundStyle(color.idealTextColor())
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }

                        Text(color.hexString)
                            .font(.system(size: 48, weight: .medium, design: .monospaced))
                            .foregroundStyle(color.idealTextColor().opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 4)

                        // Navigation indicator dots
                        if colors.count > 1 {
                            HStack(spacing: 8) {
                                ForEach(0..<colors.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentIndex ?
                                              color.idealTextColor() :
                                              color.idealTextColor().opacity(0.3))
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .padding(.top, 24)
                            .accessibilityHidden(true)
                        }
                    }
                    .padding(.bottom, 140)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(colorAccessibilityLabel(for: color))
                }
            }

            // Navigation controls overlay
            VStack {
                // Top bar: Back button and counter
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .accessibilityHidden(true)
                            Text("Back")
                        }
                        .font(.callout)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Exits presentation mode")

                    Spacer()

                    if colors.count > 1 {
                        Text("\(currentIndex + 1) / \(colors.count)")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(currentColor?.idealTextColor().opacity(0.7) ?? .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.3), in: Capsule())
                            .accessibilityLabel("Color \(currentIndex + 1) of \(colors.count)")
                    }
                }
                .padding(40)

                Spacer()
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                goToPrevious()
            case .right:
                goToNext()
            default:
                break
            }
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
    }

    // MARK: - Accessibility

    private func colorAccessibilityLabel(for color: OpaliteColor) -> String {
        var parts: [String] = []
        if let name = color.name, !name.isEmpty {
            parts.append(name)
        }
        parts.append(color.hexString)
        if colors.count > 1 {
            parts.append("Color \(currentIndex + 1) of \(colors.count)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Navigation

    private func goToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    private func goToNext() {
        if currentIndex < colors.count - 1 {
            currentIndex += 1
        }
    }
}

#Preview {
    TVPresentationModeView(
        colors: [OpaliteColor.sample, OpaliteColor.sample2],
        startIndex: 0
    )
}

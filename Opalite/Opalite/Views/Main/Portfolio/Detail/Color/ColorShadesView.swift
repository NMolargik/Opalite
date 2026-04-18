//
//  ColorShadesView.swift
//  Opalite
//
//  Created by Claude Code on 12/04/26.
//

import SwiftUI

struct ColorShadesView: View {
    let baseColor: OpaliteColor
    let onCreateColor: (OpaliteColor) -> Void
    
    @State private var shadeColors: [ShadeVariation] = []
    @State private var isShowingInfo = false
    
    var body: some View {
        SectionCard(title: "Tints & Shades", systemImage: "circle.lefthalf.filled", isCollapsible: true, initiallyExpanded: false) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    // Tints (lighter - adding white)
                    shadeRow(title: "Tints", colors: shadeColors.filter { $0.type == .tint })

                    Divider()
                        .padding(.vertical, 4)

                    // Shades (darker - adding black)
                    shadeRow(title: "Shades", colors: shadeColors.filter { $0.type == .shade })
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
        } trailing: {
            Button {
                HapticsManager.shared.selection()
                isShowingInfo = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Learn about tints and shades")
            .padding(.trailing)
        }
        .sheet(isPresented: $isShowingInfo) {
            TintsAndShadesInfoSheet()
        }
        .onAppear {
            generateShadeVariations()
        }
    }
    
    @ViewBuilder
    private func shadeRow(title: String, colors: [ShadeVariation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(colors) { variation in
                        shadeButton(for: variation)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func shadeButton(for variation: ShadeVariation) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(variation.color.swiftUIColor)
            .frame(width: 70, height: 70)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            .contextMenu {
                Button {
                    HapticsManager.shared.selection()
                    onCreateColor(variation.color)
                } label: {
                    Label("Add to Portfolio", systemImage: "plus.circle")
                }
                
                Button {
                    HapticsManager.shared.selection()
                    #if canImport(UIKit)
                    UIPasteboard.general.string = variation.color.hexString
                    #elseif canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(variation.color.hexString, forType: .string)
                    #endif
                } label: {
                    Label("Copy Hex", systemImage: "doc.on.doc")
                }
            }
            
            Text(variation.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func generateShadeVariations() {
        var variations: [ShadeVariation] = []
        
        // Tints (lighter - mix with white)
        let tintSteps = [0.2, 0.4, 0.6, 0.8]
        for (_, amount) in tintSteps.enumerated() {
            let tintedColor = mixWithWhite(amount: amount)
            variations.append(ShadeVariation(
                color: tintedColor,
                type: .tint,
                label: "+\(Int(amount * 100))%"
            ))
        }
        
        // Shades (darker - mix with black)
        let shadeSteps = [0.2, 0.4, 0.6, 0.8]
        for (_, amount) in shadeSteps.enumerated() {
            let shadedColor = mixWithBlack(amount: amount)
            variations.append(ShadeVariation(
                color: shadedColor,
                type: .shade,
                label: "-\(Int(amount * 100))%"
            ))
        }
        
        shadeColors = variations
    }
    
    private func mixWithWhite(amount: Double) -> OpaliteColor {
        let newRed = baseColor.red + (1.0 - baseColor.red) * amount
        let newGreen = baseColor.green + (1.0 - baseColor.green) * amount
        let newBlue = baseColor.blue + (1.0 - baseColor.blue) * amount
        
        return OpaliteColor(
            name: nil,
            red: newRed,
            green: newGreen,
            blue: newBlue,
            alpha: baseColor.alpha
        )
    }
    
    private func mixWithBlack(amount: Double) -> OpaliteColor {
        let newRed = baseColor.red * (1.0 - amount)
        let newGreen = baseColor.green * (1.0 - amount)
        let newBlue = baseColor.blue * (1.0 - amount)
        
        return OpaliteColor(
            name: nil,
            red: newRed,
            green: newGreen,
            blue: newBlue,
            alpha: baseColor.alpha
        )
    }
}

// MARK: - Shade Variation Model

private struct ShadeVariation: Identifiable {
    let id = UUID()
    let color: OpaliteColor
    let type: VariationType
    let label: String
    
    enum VariationType {
        case tint
        case shade
    }
}

#Preview {
    let sampleColor = OpaliteColor(
        name: "Ocean Blue",
        red: 0.2,
        green: 0.4,
        blue: 0.8,
        alpha: 1.0
    )
    
    return ColorShadesView(
        baseColor: sampleColor,
        onCreateColor: { color in
            print("Created color: \(color.hexString)")
        }
    )
    .padding()
}

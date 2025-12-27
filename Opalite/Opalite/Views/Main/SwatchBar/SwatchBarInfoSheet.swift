//
//  SwatchBarInfoSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

struct SwatchBarInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bounceTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "square.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple.gradient)
                        .padding(.top, 20)
                        .accessibilityHidden(true)
                        .symbolEffect(.bounce, options: .speed(0.01), value: bounceTrigger)
                        .onAppear {
                            // Trigger a one-time SF Symbol bounce when the view appears
                            bounceTrigger.toggle()
                        }

                    // Title
                    Text("SwatchBar")
                        .font(.largeTitle)
                        .bold()

                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(
                            icon: "rectangle.on.rectangle",
                            title: "Minimal Footprint",
                            description: "SwatchBar is a secondary window designed for fast color reference while taking up minimal screen real estate. We recommend making it as narrow as possible."
                        )

                        featureRow(
                            icon: "number",
                            title: "Quick Copy",
                            description: "Tap any color swatch to instantly copy its hex value to your clipboard."
                        )

                        featureRow(
                            icon: "eyedropper",
                            title: "Color Sampling",
                            description: "Use your favorite app's color sampler tool to pick colors directly from the SwatchBar window."
                        )

                        featureRow(
                            icon: "arrow.up.and.down.and.arrow.left.and.right",
                            title: "Always Accessible",
                            description: "Position the SwatchBar anywhere on screen for quick access while you work in other applications."
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsManager.shared.selection()
                        AppDelegate.openSwatchBarWindow()
                        dismiss()
                    } label: {
                        Text("Launch")
                    }
                    .tint(.purple)
                }
            }
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SwatchBarInfoSheet()
}

//
//  WatchAppInfoSheet.swift
//  OpaliteFeatureSettings
//
//  "About the Watch App": what Opalite does on Apple Watch and how syncing works.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct WatchAppInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private var features: [(systemImage: String, title: String, detail: String)] {
        [
            ("paintpalette.fill", String(localized: "Browse Your Colors"), String(localized: "Every color and palette, right on your wrist.")),
            ("doc.on.clipboard", String(localized: "Copy Hex Codes"), String(localized: "Tap a color to copy its hex code to your iPhone's clipboard.")),
            ("arrow.triangle.2.circlepath", String(localized: "Automatic Sync"), String(localized: "Colors come straight from your iPhone for fast, reliable access.")),
            ("wifi.slash", String(localized: "Works Offline"), String(localized: "Once synced, your colors stay cached on the watch.")),
        ]
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Brand.Space.xl) {
                    ShowcaseHero(
                        systemImage: "applewatch.watchface",
                        gradient: LinearGradient(colors: [.pink, .opalitePurple], startPoint: .top, endPoint: .bottom),
                        glow: .pink,
                        title: String(localized: "Opalite for Apple Watch"),
                        subtitle: String(localized: "Your colors, on your wrist.")
                    )

                    VStack(spacing: Brand.Space.md) {
                        ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                            ShowcaseFeatureRow(systemImage: feature.systemImage, title: feature.title, detail: feature.detail, tint: .pink)
                        }
                    }

                    VStack(alignment: .leading, spacing: Brand.Space.md) {
                        Text("How Syncing Works")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        ShowcaseStepRow(number: 1, text: String(localized: "Colors and palettes sync automatically while Opalite is open on your iPhone."), tint: .pink)
                        ShowcaseStepRow(number: 2, text: String(localized: "Your watch asks for the latest data when the Watch app opens."), tint: .pink)
                        ShowcaseStepRow(number: 3, text: String(localized: "Pull down on the watch to refresh anytime."), tint: .pink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: Brand.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Brand.Space.lg)
                .padding(.bottom, Brand.Space.xl)
            }
            .scrollContentBackground(.hidden)
            .softScrollEdgesIfAvailable()
            .background {
                ZStack {
                    groupedBackground
                    LinearGradient(colors: [Color.pink.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Apple Watch")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("About the Watch App") {
    WatchAppInfoSheet()
        .settingsPreviewEnvironment()
}
#endif
#endif

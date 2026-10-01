//
//  AboutView.swift
//  OpaliteFeatureSettings
//
//  Version and build, outbound links, credits, acknowledgments, and the App Store review
//  prompt.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import StoreKit
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct AboutView: View {
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.requestReview) private var requestReview

    private let version = AppVersionInfo()
    private var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "—" }

    var body: some View {
        Form {
            Section {
                ShowcaseHero(
                    systemImage: "diamond.fill",
                    gradient: LinearGradient.opalite,
                    glow: .opalitePurple,
                    title: String(localized: "Opalite"),
                    subtitle: version.subtitle
                )
                .padding(.bottom, Brand.Space.sm)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    Haptics.selection()
                    requestReview()
                } label: {
                    Label("Rate Opalite", systemImage: "star.fill")
                        .labelStyle(.settingsIcon(.yellow))
                }
                .accessibilityHint(Text("Asks the App Store for a rating"))
                .accessibilityIdentifier("about.rate")

                Link(destination: SettingsLinks.website) {
                    Label("Website", systemImage: "safari.fill")
                        .labelStyle(.settingsIcon(.blue))
                }
                Link(destination: SettingsLinks.support) {
                    Label("Support", systemImage: "questionmark.circle.fill")
                        .labelStyle(.settingsIcon(.green))
                }
                Link(destination: SettingsLinks.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .labelStyle(.settingsIcon(.gray))
                }
                Link(destination: SettingsLinks.terms) {
                    Label("Terms of Use", systemImage: "doc.text.fill")
                        .labelStyle(.settingsIcon(.gray))
                }
            } header: {
                Text("Links")
            }

            Section {
                LabeledContent("Developer") {
                    Link("Nick Molargik", destination: SettingsLinks.developer)
                }
                LabeledContent("Publisher") {
                    Link("Molargik Software LLC", destination: SettingsLinks.website)
                }
            } header: {
                Text("Credits")
            }

            Section {
                LabeledContent("DeviceKit") {
                    Link("MIT License", destination: SettingsLinks.deviceKit)
                }
            } header: {
                Text("Acknowledgments")
            } footer: {
                Text("Thank you to all of our amazing TestFlight testers!")
            }

            Section {
                DetailRow(String(localized: "Version"), value: version.formatted, monospaced: true) {
                    hexCopy.copy(text: version.formatted, label: String(localized: "version"))
                }
                DetailRow(String(localized: "Bundle"), value: bundleIdentifier, monospaced: true)
            } header: {
                Text("Build")
            }
        }
        .navigationTitle("About")
        .navigationSubtitleIfAvailable(version.subtitle)
    }
}

#if DEBUG
#Preview("About") {
    NavigationStack { AboutView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

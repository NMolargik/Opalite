//
//  TVSettingsView.swift
//  OpaliteFeatureTV
//
//  Grouped settings: library counts, hex prefix, color-blindness simulation, OLED refresh,
//  and about. Everything that can be changed on TV is here; creation stays on the other devices.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVSettingsView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(HexCopyModel.self) private var hexCopy
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var simulationRaw = ColorBlindnessMode.off.rawValue

    @State private var includesPrefix = true
    @State private var isRefreshingOLED = false

    private var simulationMode: ColorBlindnessMode { ColorBlindnessMode(rawValue: simulationRaw) ?? .off }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Colors", value: portfolio.colors.count.formatted())
                    LabeledContent("Palettes", value: portfolio.activePalettes.count.formatted())
                    LabeledContent("Profile name", value: portfolio.authorName.isEmpty ? String(localized: "Not set") : portfolio.authorName)
                } header: {
                    Text("Library")
                } footer: {
                    Text("Your colors and palettes sync from iCloud. Create and edit them on your iPhone, iPad, or Mac.")
                }

                Section {
                    Toggle("Include # Prefix", isOn: $includesPrefix)
                        .accessibilityIdentifier("hexPrefixToggle")
                    LabeledContent("Example", value: hexCopy.formatted("3380CC"))
                } header: {
                    Text("Hex Codes")
                }

                Section {
                    Picker("Color Blindness Simulation", selection: $simulationRaw) {
                        ForEach(ColorBlindnessMode.allCases) { mode in
                            Text(mode.shortTitle).tag(mode.rawValue)
                        }
                    }
                    .accessibilityIdentifier("colorBlindnessPicker")
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text(simulationMode.modeDescription)
                }

                Section {
                    Button("OLED Refresh", systemImage: "tv") {
                        isRefreshingOLED = true
                    }
                    .accessibilityHint(Text("Cycles full-screen colors to reduce image retention. Press Menu to exit."))
                    .accessibilityIdentifier("oledRefreshButton")
                } header: {
                    Text("Screen")
                } footer: {
                    Text("Cycles through solid colors to help clear temporary image retention on OLED displays. Press Menu to exit.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                    LabeledContent("Platform", value: "tvOS")
                } header: {
                    Text("About")
                } footer: {
                    Text("Opalite for Apple TV shows the colors and palettes you've made on your other devices, at the size they deserve.")
                }
            }
            .navigationTitle("Settings")
            .onAppear { includesPrefix = hexCopy.includesPrefix }
            .onChange(of: includesPrefix) { _, newValue in
                if hexCopy.includesPrefix != newValue { hexCopy.includesPrefix = newValue }
            }
            .fullScreenCover(isPresented: $isRefreshingOLED) {
                TVOLEDRefreshView()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

#if DEBUG
#Preview {
    TVSettingsView()
        .previewEnvironment()
}
#endif
#endif

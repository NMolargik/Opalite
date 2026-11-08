//
//  SwatchBarSettingsView.swift
//  OpaliteFeatureSettings
//
//  Explains the SwatchBar (the narrow secondary window) and opens it through the
//  router; the window and its info sheet live in OpaliteFeatureSwatchBar.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct SwatchBarSettingsView: View {
    @Environment(AppRouter.self) private var router
    @AppStorage(AppStorageKeys.skipSwatchBarConfirmation) private var skipsConfirmation = false

    #if targetEnvironment(macCatalyst)
    @AppStorage(AppStorageKeys.eyedropperHotkey) private var hotkeyRaw = EyedropperHotkey.default.rawValue
    @AppStorage(AppStorageKeys.eyedropperCopyFormat) private var copyFormatRaw = EyedropperCopyFormat.hex.rawValue
    @AppStorage(AppStorageKeys.eyedropperAutoCopy) private var autoCopy = true
    @AppStorage(AppStorageKeys.eyedropperKeepSwatchBarHidden) private var keepHidden = false
    #endif

    private var highlights: [(systemImage: String, title: String, detail: String)] {
        var items: [(systemImage: String, title: String, detail: String)] = [
            ("rectangle.on.rectangle", String(localized: "Minimal Footprint"), String(localized: "A compact window for quick reference. Resize it as narrow as you need.")),
            ("doc.on.clipboard", String(localized: "Quick Copy"), String(localized: "Tap any swatch to copy its hex code.")),
            ("paintbrush.pointed.fill", String(localized: "Canvas Ink"), String(localized: "Pick a swatch to set the ink color on your canvas.")),
        ]
        #if targetEnvironment(macCatalyst)
        items.append(("eyedropper.halffull", String(localized: "Color Sampling"), String(localized: "Sample a color from anything on screen.")))
        #endif
        items.append(("macwindow.on.rectangle", String(localized: "Always Within Reach"), String(localized: "Place it beside the apps you're designing in.")))
        return items
    }

    var body: some View {
        Form {
            Section {
                ShowcaseHero(
                    systemImage: "square.stack.fill",
                    gradient: LinearGradient(colors: [.purple, .opalitePurple], startPoint: .top, endPoint: .bottom),
                    glow: .purple,
                    title: String(localized: "SwatchBar"),
                    subtitle: String(localized: "Your colors, always within reach.")
                )
                .padding(.bottom, Brand.Space.sm)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(Array(highlights.enumerated()), id: \.offset) { _, item in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.purple)
                    }
                    .labelStyle(.alignedIcon)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Highlights")
            }

            #if targetEnvironment(macCatalyst)
            Section {
                Picker(selection: $hotkeyRaw) {
                    ForEach(EyedropperHotkey.allCases) { hotkey in
                        Text(hotkey == .off ? String(localized: "Off") : hotkey.symbols).tag(hotkey.rawValue)
                    }
                } label: {
                    Label("Shortcut", systemImage: "keyboard")
                        .labelStyle(.settingsIcon(.purple))
                }
                Toggle(isOn: $autoCopy) {
                    Label("Copy Picked Color", systemImage: "doc.on.clipboard")
                        .labelStyle(.settingsIcon(.purple))
                }
                .toggleStyle(.settingsRow)
                .tint(.purple)
                if autoCopy {
                    Picker(selection: $copyFormatRaw) {
                        ForEach(EyedropperCopyFormat.allCases) { format in
                            Text(format.title).tag(format.rawValue)
                        }
                    } label: {
                        Label("Copy As", systemImage: "textformat")
                            .labelStyle(.settingsIcon(.purple))
                    }
                }
                Toggle(isOn: $keepHidden) {
                    Label("Keep SwatchBar Hidden", systemImage: "eye.slash")
                        .labelStyle(.settingsIcon(.purple))
                }
                .toggleStyle(.settingsRow)
                .tint(.purple)
            } header: {
                Text("Eyedropper")
            } footer: {
                Text("Press the shortcut in any app to sample a color with the magnifier. The pick is saved to your portfolio, and the SwatchBar opens to show it unless you keep it hidden.")
            }
            #endif

            Section {
                Toggle(isOn: $skipsConfirmation) {
                    Label("Open Without Asking", systemImage: "bolt.fill")
                        .labelStyle(.settingsIcon(.purple))
                }
                .toggleStyle(.settingsRow)
                .tint(.purple)
            } footer: {
                Text("Skips the confirmation when a swatch opens the SwatchBar.")
            }

            Section {
                Button {
                    Haptics.mediumImpact()
                    router.open(.swatchBar)
                } label: {
                    Label("Open SwatchBar", systemImage: "arrow.up.forward.square")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionButton(tint: .purple)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityHint(Text("Opens the SwatchBar window"))
                .accessibilityIdentifier("swatchBar.open")

                Button("Learn More") {
                    Haptics.selection()
                    router.present(.swatchBarInfo)
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("SwatchBar")
    }
}

#if targetEnvironment(macCatalyst)
extension EyedropperCopyFormat {
    var title: String {
        switch self {
        case .hex: String(localized: "Hex")
        case .rgb: String(localized: "RGB")
        case .hsl: String(localized: "HSL")
        case .oklch: String(localized: "OKLCH")
        case .displayP3: String(localized: "Display P3")
        }
    }
}
#endif

#if DEBUG
#Preview("SwatchBar") {
    NavigationStack { SwatchBarSettingsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

//
//  WatchSettingsView.swift
//  OpaliteFeatureSettings
//
//  The Apple Watch page (iPhone): pairing / install / reachability from
//  `PhoneConnectivityManager`, the last sync and its counts, how to open the watch app,
//  and the "about" sheet.
//

#if os(iOS) && canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared

struct WatchSettingsView: View {
    @Environment(PhoneConnectivityManager.self) private var connectivity
    @State private var isShowingInfo = false

    private var status: WatchStatusPresentation {
        WatchStatusPresentation(
            isPaired: connectivity.isPaired,
            isWatchAppInstalled: connectivity.isWatchAppInstalled,
            isReachable: connectivity.isReachable
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    StatusMark(isOn: status.isPaired)
                } label: {
                    Label("Paired", systemImage: "applewatch")
                        .labelStyle(.settingsIcon(.pink))
                }
                .accessibilityElement(children: .combine)

                if status.isPaired {
                    LabeledContent {
                        StatusMark(isOn: status.isWatchAppInstalled)
                    } label: {
                        Label("Watch App Installed", systemImage: "app.badge.checkmark")
                            .labelStyle(.settingsIcon(.pink))
                    }
                    .accessibilityElement(children: .combine)
                }

                if status.isWatchAppInstalled {
                    LabeledContent {
                        Text(status.isReachable ? "Connected" : "Not Right Now")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Reachable", systemImage: "dot.radiowaves.left.and.right")
                            .labelStyle(.settingsIcon(.pink))
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Status")
            } footer: {
                Text(status.guidance)
            }

            if status.isWatchAppInstalled {
                Section {
                    LabeledContent("Last Synced") {
                        if let date = connectivity.lastSyncDate {
                            Text("\(Text(date, style: .relative)) ago")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Colors") {
                        Text(connectivity.lastSyncColorCount.formatted())
                            .contentTransition(.numericText())
                    }
                    LabeledContent("Palettes") {
                        Text(connectivity.lastSyncPaletteCount.formatted())
                            .contentTransition(.numericText())
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Your watch asks for the latest colors when Opalite opens on it. Pull down on the watch to refresh anytime.")
                }
            }

            Section {
                ShowcaseStepRow(number: 1, text: String(localized: "Press the Digital Crown to see your apps."), tint: .pink)
                ShowcaseStepRow(number: 2, text: String(localized: "Open Opalite. Your palettes and colors appear in a list."), tint: .pink)
                ShowcaseStepRow(number: 3, text: String(localized: "Tap a color to copy its hex code to your iPhone's clipboard."), tint: .pink)
            } header: {
                Text("Open on Watch")
            }

            Section {
                Button {
                    Haptics.selection()
                    isShowingInfo = true
                } label: {
                    Label("About the Watch App", systemImage: "info.circle.fill")
                        .labelStyle(.settingsIcon(.gray))
                }
            }
        }
        .navigationTitle("Apple Watch")
        .navigationSubtitleIfAvailable(status.summary)
        .sharedSheet(isPresented: $isShowingInfo) { WatchAppInfoSheet() }
    }
}

#if DEBUG
#Preview("Apple Watch") {
    NavigationStack { WatchSettingsView() }
        .settingsPreviewEnvironment()
}
#endif
#endif

//
//  TVSettingsView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Settings view for tvOS.
/// Provides sync controls, OLED refresh mode, and about info.
struct TVSettingsView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    @State private var showOLEDRefresh: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                // Title
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)

                // MARK: - Sync Section
                VStack(alignment: .leading, spacing: 24) {
                    Text("Sync")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)

                    Button {
                        Task {
                            await colorManager.refreshAll()
                            toastManager.showSuccess("Synced with iCloud")
                        }
                    } label: {
                        Label("Refresh from iCloud", systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh from iCloud")
                    .accessibilityHint("Syncs your colors and palettes from iCloud")

                    VStack(spacing: 12) {
                        TVSettingsInfoRow(label: "Colors", value: "\(colorManager.colors.count)")
                        TVSettingsInfoRow(label: "Palettes", value: "\(colorManager.palettes.count)")
                    }
                }

                // MARK: - Display Section
                VStack(alignment: .leading, spacing: 24) {
                    Text("Display")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)

                    Button {
                        showOLEDRefresh = true
                    } label: {
                        Label("OLED Refresh Mode", systemImage: "tv.fill")
                    }
                    .accessibilityLabel("OLED Refresh Mode")
                    .accessibilityHint("Opens a full-screen color cycle to reduce OLED image retention. Press Back to exit.")

                    Text("Cycles through colors to help reduce temporary image retention on OLED displays. Press Back to exit.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // MARK: - About Section
                VStack(alignment: .leading, spacing: 24) {
                    Text("About")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 12) {
                        TVSettingsInfoRow(label: "Version", value: appVersion)
                        TVSettingsInfoRow(label: "Build", value: buildNumber)
                        TVSettingsInfoRow(label: "Platform", value: "tvOS")
                    }

                    Text("Opalite TV is a companion app that displays your colors, and palettes synced via iCloud. Create and edit content on your iPhone, iPad, or Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                Spacer(minLength: 100)
            }
            .padding(48)
        }
        .fullScreenCover(isPresented: $showOLEDRefresh) {
            TVOLEDRefreshView()
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - Settings Info Row

struct TVSettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    TVSettingsView()
}

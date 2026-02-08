//
//  CommunityColorDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import SwiftData
import CloudKit

#if canImport(UIKit)
import UIKit
private typealias PlatformPasteboard = UIPasteboard
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
private typealias PlatformPasteboard = NSPasteboard
#endif

struct CommunityColorDetailView: View {
    let color: CommunityColor

    @Environment(CommunityManager.self) private var communityManager
    @Environment(ColorManager.self) private var colorManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isShowingPaywall = false
    @State private var isShowingReportSheet = false
    @State private var didCopyHex = false

    // Color blindness simulation
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var colorBlindnessMode: ColorBlindnessMode {
        ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
    }

    private var displayColor: Color {
        color.simulatedSwiftUIColor(colorBlindnessMode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Hero Swatch (SwatchView-style)
                heroSwatch
                    .padding(.horizontal)
                    .padding(.top)
                    .overlay(alignment: .bottom) {
                        CommunityColorInfoTilesRow(color: color)
                            .padding(.horizontal, 30)
                            .offset(y: 45)
                            .zIndex(1)
                    }

                Spacer(minLength: 80)

                // MARK: - Content Sections
                VStack(spacing: 20) {
                    // Color values section
                    colorValuesSection

                    // Publisher section
                    publisherSection

                    // Notes section (read-only)
                    if let notes = color.notes, !notes.isEmpty {
                        CommunityNotesSectionView(notes: notes)
                    }
                }
                .padding(.horizontal)
                .padding(.top, -20)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Save to Portfolio button
            ToolbarItem(placement: .confirmationAction) {
                saveToPortfolioButton
            }

            // Report button
            ToolbarItem(placement: .topBarTrailing) {
                reportButton
            }
        }
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Save colors from the community to your portfolio!")
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportItemSheet(recordID: color.id, itemType: .color)
        }
    }

    // MARK: - Toolbar Buttons

    private var saveToPortfolioButton: some View {
        Button {
            HapticsManager.shared.selection()
            saveToPortfolio()
        } label: {
            Label("Save to Portfolio", systemImage: "square.and.arrow.down")
        }
        .tint(.teal)
    }

    private var reportButton: some View {
        Button {
            HapticsManager.shared.selection()
            isShowingReportSheet = true
        } label: {
            Label("Report", systemImage: "flag")
        }
        .tint(.red)
    }

    // MARK: - Color Values Section

    private var colorValuesSection: some View {
        SectionCard(title: "Color Values", systemImage: "slider.horizontal.3") {
            VStack(spacing: 12) {
                colorValueRow(label: "Hex", value: color.hexString, icon: "number")
                colorValueRow(label: "RGB", value: color.rgbString, icon: "slider.horizontal.3")
                colorValueRow(label: "HSL", value: color.hslString, icon: "circle.lefthalf.filled")
            }
            .padding(.horizontal, 16)
        }
    }

    private func colorValueRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)

            Button {
                HapticsManager.shared.selection()
                copyToClipboard(value)
                toastManager.showSuccess("Copied \(label)")
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hero Swatch

    private var heroSwatch: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(displayColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.thinMaterial, lineWidth: 5)
            )
            .frame(height: 220)
            .overlay(alignment: .topLeading) {
                // Name badge
                Text(color.name ?? color.hexString)
                    .foregroundStyle(color.idealTextColor())
                    .bold()
                    .frame(height: 20)
                    .padding(8)
                    .glassIfAvailable(GlassConfiguration(style: .clear))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(8)
            }
    }

    // MARK: - Publisher Section

    private var publisherSection: some View {
        SectionCard(title: "Publisher", systemImage: "person") {
            NavigationLink(value: CommunityNavigationNode.publisherProfile(color.publisherUserRecordID, color.publisherName)) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(color.publisherName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("View profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func saveToPortfolio() {
        guard subscriptionManager.hasOnyxEntitlement else {
            isShowingPaywall = true
            return
        }

        do {
            try communityManager.saveColorToPortfolio(color, colorManager: colorManager, subscriptionManager: subscriptionManager)
            toastManager.showSuccess("Saved to Portfolio")
        } catch let error as OpaliteError {
            toastManager.show(error: error)
        } catch {
            toastManager.show(error: .unknownError(error.localizedDescription))
        }
    }

    private func copyHex() {
        copyToClipboard(color.hexString)
        HapticsManager.shared.impact(.light)
        withAnimation(.easeIn(duration: 0.15)) {
            didCopyHex = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.15)) {
                didCopyHex = false
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Info Tiles Row

private struct CommunityColorInfoTilesRow: View {
    let color: CommunityColor

    var body: some View {
        HStack(spacing: 12) {
            CommunityInfoTileView(
                icon: "person.fill",
                iconColor: color.idealTextColor(),
                value: color.publisherName,
                label: "Publisher"
            )

            CommunityInfoTileView(
                icon: DeviceKind.from(color.createdOnDeviceName).symbolName,
                iconColor: color.idealTextColor(),
                value: shortDeviceName(color.createdOnDeviceName),
                label: "Created On"
            )

            CommunityInfoTileView(
                icon: "person.2",
                iconColor: color.idealTextColor(),
                value: formattedShortDate(color.publishedAt),
                label: "Published"
            )
        }
    }

    private func shortDeviceName(_ name: String?) -> String {
        guard let name = name else { return "—" }
        if name.lowercased().contains("iphone") {
            return "iPhone"
        } else if name.lowercased().contains("ipad") {
            return "iPad"
        } else if name.lowercased().contains("mac") {
            return "Mac"
        }
        return name
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Info Tile View

private struct CommunityInfoTileView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(height: 30)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: 200, maxHeight: 85)
        .modifier(CommunityGlassTileBackground())
    }
}

private struct CommunityGlassTileBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 5)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .shadow(radius: 5)
                )
        }
    }
}

// MARK: - Read-Only Notes Section

struct CommunityNotesSectionView: View {
    let notes: String

    var body: some View {
        SectionCard(title: "Notes", systemImage: "note.text") {
            Text(notes)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        }
    }
}

#Preview("Color Detail") {
    NavigationStack {
        CommunityColorDetailView(color: CommunityColor.sample)
    }
    .environment(CommunityManager())
    .environment(ColorManager(context: try! ModelContainer(for: OpaliteColor.self, OpalitePalette.self, CanvasFile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
    .environment(SubscriptionManager())
    .environment(ToastManager())
}

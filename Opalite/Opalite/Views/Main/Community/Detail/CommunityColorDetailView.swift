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

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingPaywall = false
    @State private var isShowingReportSheet = false
    @State private var isShowingRemoveConfirmation = false
    @State private var didCopyHex = false

    private var isOwnContent: Bool {
        communityManager.currentUserRecordID != nil &&
        color.publisherUserRecordID == communityManager.currentUserRecordID
    }

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

            // Report / Remove button
            ToolbarItem(placement: .topBarTrailing) {
                if isOwnContent {
                    removeFromCommunityButton
                } else {
                    reportButton
                }
            }
        }
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Save colors from the community to your portfolio!")
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportItemSheet(recordID: color.id, itemType: .color)
        }
        .alert("Remove From Community", isPresented: $isShowingRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                removeFromCommunity()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This color will be permanently removed from the Community. This action cannot be undone.")
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
        .accessibilityHint("Saves this community color to your portfolio")
    }

    private var reportButton: some View {
        Button {
            HapticsManager.shared.selection()
            isShowingReportSheet = true
        } label: {
            Label("Report", systemImage: "flag")
        }
        .tint(.red)
        .accessibilityHint("Reports this color for inappropriate content")
    }

    private var removeFromCommunityButton: some View {
        Button(role: .destructive) {
            HapticsManager.shared.selection()
            isShowingRemoveConfirmation = true
        } label: {
            Label("Remove From Community", systemImage: "trash")
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
            .accessibilityLabel("Copy \(label) value")
            .accessibilityHint("Copies \(value) to the clipboard")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Color preview, \(color.name ?? color.hexString)")
    }

    // MARK: - Publisher Section

    private var publisherSection: some View {
        SectionCard(title: "Publisher", systemImage: "person") {
            NavigationLink(value: CommunityNavigationNode.publisherProfile(color.publisherUserRecordID, color.publisherName)) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

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
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Publisher, \(color.publisherName)")
            .accessibilityHint("Opens the publisher's profile")
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

    private func removeFromCommunity() {
        Task {
            do {
                try await communityManager.unpublishColor(recordID: color.id)
                await MainActor.run {
                    toastManager.showSuccess("Removed from Community")
                    dismiss()
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    toastManager.show(error: error)
                }
            } catch {
                await MainActor.run {
                    toastManager.show(error: .unknownError(error.localizedDescription))
                }
            }
        }
    }

    private func copyHex() {
        copyToClipboard(color.hexString)
        #if os(iOS)
        HapticsManager.shared.impact(.light)
        #endif
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
            InfoTileView(
                icon: "person.fill",
                value: color.publisherName,
                label: "Publisher",
                maxWidth: 200,
                glassStyle: .regular
            )

            InfoTileView(
                icon: DeviceKind.from(color.createdOnDeviceName).symbolName,
                value: shortDeviceName(color.createdOnDeviceName),
                label: "Created On",
                maxWidth: 200,
                glassStyle: .regular,
                lineLimit: 2,
                minimumScaleFactor: 0.7
            )

            InfoTileView(
                icon: "person.2",
                value: color.publishedAt.formattedShortDate,
                label: "Published",
                maxWidth: 200,
                glassStyle: .regular,
                lineLimit: 2,
                minimumScaleFactor: 0.7
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

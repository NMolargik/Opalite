//
//  RecentColorsWidget.swift
//  OpaliteWatchWidgets
//
//  Created by Nick Molargik on 2/7/26.
//
//  NOTE: Add WatchModels.swift (from OpaliteWatch Watch App/) to the
//  OpaliteWatchWidgets target in Xcode for shared WatchColor model access.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Storage

/// Reads color data shared between the watch app and its widget via App Group.
struct WatchWidgetStorage {
    static let appGroupIdentifier = "group.com.molargiksoftware.OpaliteWatch"
    static let colorsKey = "watchWidgetColors"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Loads colors from shared App Group storage, sorted most recent first.
    static func loadRecentColors(limit: Int = 3) -> [WatchColor] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: colorsKey),
              let colors = try? JSONDecoder().decode([WatchColor].self, from: data) else {
            return []
        }
        return Array(colors.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    /// Saves colors to shared App Group storage (called from the watch app).
    static func saveColors(_ colors: [WatchColor]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(colors) else {
            return
        }
        defaults.set(data, forKey: colorsKey)
    }
}

// MARK: - Timeline Entry

struct RecentColorsEntry: TimelineEntry {
    let date: Date
    let colors: [WatchColor]
}

// MARK: - Timeline Provider

struct RecentColorsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentColorsEntry {
        RecentColorsEntry(date: Date(), colors: WatchColor.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentColorsEntry) -> Void) {
        let colors = WatchWidgetStorage.loadRecentColors()
        completion(RecentColorsEntry(
            date: Date(),
            colors: colors.isEmpty ? WatchColor.samples : colors
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentColorsEntry>) -> Void) {
        let colors = WatchWidgetStorage.loadRecentColors()
        let entry = RecentColorsEntry(date: Date(), colors: colors)

        // Refresh hourly as a fallback; the watch app also calls
        // WidgetCenter.shared.reloadAllTimelines() on each sync.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct RecentColorsRectangularView: View {
    let entry: RecentColorsEntry

    var body: some View {
        if entry.colors.isEmpty {
            emptyState
        } else {
            colorList
        }
    }

    private var colorList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(entry.colors.prefix(3)) { color in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.swiftUIColor)
                        .frame(width: 14, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        )

                    Text(color.name ?? color.hexString)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel(color.voiceOverDescription)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "paintpalette")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No Colors")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RecentColorsInlineView: View {
    let entry: RecentColorsEntry

    var body: some View {
        if let first = entry.colors.first {
            Label(first.name ?? first.hexString, systemImage: "paintpalette.fill")
        } else {
            Label("No Colors", systemImage: "paintpalette")
        }
    }
}

// MARK: - Widget Definition

struct RecentColorsWidget: Widget {
    let kind: String = "RecentColorsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentColorsProvider()) { entry in
            RecentColorsRectangularView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(widgetURL(for: entry))
        }
        .configurationDisplayName("Recent Colors")
        .description("Shows your most recently created colors.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }

    private func widgetURL(for entry: RecentColorsEntry) -> URL? {
        guard let first = entry.colors.first else { return nil }
        return URL(string: "opalite://color/\(first.id.uuidString)")
    }
}

// MARK: - Previews

#Preview(as: .accessoryRectangular) {
    RecentColorsWidget()
} timeline: {
    RecentColorsEntry(date: .now, colors: WatchColor.samples)
    RecentColorsEntry(date: .now, colors: [])
}

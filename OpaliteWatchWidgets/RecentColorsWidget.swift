//
//  RecentColorsWidget.swift
//  OpaliteWatchWidgets
//
//  Watch complications showing the user's most recent colors, read from the watch
//  app's App Group snapshot.
//

import SwiftUI
import WidgetKit
import OpaliteCore
import OpaliteDesignSystem

struct RecentColorsEntry: TimelineEntry {
    let date: Date
    let colors: [WatchColor]
}

struct RecentColorsProvider: TimelineProvider {
    private let store = WatchWidgetStore()

    func placeholder(in context: Context) -> RecentColorsEntry {
        RecentColorsEntry(date: Date(), colors: WatchColor.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentColorsEntry) -> Void) {
        let colors = store.recentColors()
        completion(RecentColorsEntry(date: Date(), colors: colors.isEmpty ? WatchColor.samples : colors))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentColorsEntry>) -> Void) {
        let entry = RecentColorsEntry(date: Date(), colors: store.recentColors())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RecentColorsRectangularView: View {
    let entry: RecentColorsEntry

    var body: some View {
        if entry.colors.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "paintpalette")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("No Colors")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(entry.colors.prefix(3)) { color in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.swiftUIColor)
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                            .accessibilityHidden(true)
                        Text(color.displayName)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(color.voiceOverDescription)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RecentColorsInlineView: View {
    let entry: RecentColorsEntry

    var body: some View {
        if let first = entry.colors.first {
            Label(first.displayName, systemImage: "paintpalette.fill")
                .accessibilityLabel("Recent color: \(first.voiceOverDescription)")
        } else {
            Label("No Colors", systemImage: "paintpalette")
        }
    }
}

struct RecentColorsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.recentColorsWatch, provider: RecentColorsProvider()) { entry in
            RecentColorsRectangularView(entry: entry)
                .containerBackground(.black, for: .widget)
                .widgetURL(entry.colors.first.map { DeepLink.color($0.id).url })
        }
        .configurationDisplayName("Recent Colors")
        .description("Your most recently created colors.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .accessoryRectangular) {
    RecentColorsWidget()
} timeline: {
    RecentColorsEntry(date: .now, colors: WatchColor.samples)
    RecentColorsEntry(date: .now, colors: [])
}

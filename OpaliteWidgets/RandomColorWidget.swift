//
//  RandomColorWidget.swift
//  OpaliteWidgets
//
//  A home-screen widget that shows a random color from the user's portfolio (read from
//  the App Group snapshot the app maintains) and deep-links to its detail.
//

import SwiftUI
import WidgetKit
import OpaliteCore
import OpaliteDesignSystem

struct RandomColorEntry: TimelineEntry {
    let date: Date
    let color: WidgetColor
}

struct RandomColorProvider: TimelineProvider {
    private let storage = WidgetColorStorage()

    func placeholder(in context: Context) -> RandomColorEntry {
        RandomColorEntry(date: Date(), color: WidgetColor(id: UUID(), name: "Sample Blue", red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
    }

    func getSnapshot(in context: Context, completion: @escaping (RandomColorEntry) -> Void) {
        completion(RandomColorEntry(date: Date(), color: storage.randomColor()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RandomColorEntry>) -> Void) {
        let now = Date()
        let entries = stride(from: 0, to: 60, by: 10).map { minutes in
            RandomColorEntry(date: Calendar.current.date(byAdding: .minute, value: minutes, to: now) ?? now, color: storage.randomColor())
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RandomColorWidgetView: View {
    let entry: RandomColorEntry
    @Environment(\.widgetFamily) private var family

    private var isPlaceholder: Bool { entry.color.id == WidgetColor.placeholder.id }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            entry.color.swiftUIColor
            if isPlaceholder {
                VStack(spacing: 6) {
                    Image(systemName: "paintpalette")
                        .font(.title2)
                    Text("Create a color in Opalite")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HexBadge(entry.color.displayName, onDark: !entry.color.prefersDarkText, font: badgeFont)
                    .padding(badgePadding)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.color.displayName), \(entry.color.hexString)")
        .accessibilityHint("Opens the color in Opalite")
        .widgetURL(isPlaceholder ? DeepLink.createColor.url : DeepLink.color(entry.color.id).url)
    }

    private var badgeFont: Font {
        switch family {
        case .systemSmall: .caption2.weight(.semibold)
        case .systemMedium: .caption.weight(.semibold)
        default: .subheadline.weight(.semibold)
        }
    }

    private var badgePadding: CGFloat {
        switch family {
        case .systemSmall: 8
        case .systemMedium: 10
        default: 12
        }
    }
}

struct RandomColorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.randomColor, provider: RandomColorProvider()) { entry in
            RandomColorWidgetView(entry: entry)
                .containerBackground(entry.color.swiftUIColor, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Random Color")
        .description("A random color from your portfolio. Tap to open it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    RandomColorWidget()
} timeline: {
    RandomColorEntry(date: .now, color: WidgetColor(id: UUID(), name: "Ocean Blue", red: 0.1, green: 0.4, blue: 0.8, alpha: 1))
    RandomColorEntry(date: .now, color: WidgetColor(id: UUID(), name: nil, red: 0.9, green: 0.3, blue: 0.5, alpha: 1))
    RandomColorEntry(date: .now, color: .placeholder)
}

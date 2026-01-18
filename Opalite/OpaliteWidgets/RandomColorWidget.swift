//
//  RandomColorWidget.swift
//  OpaliteWidgets
//
//  Created by Claude on 1/18/26.
//
//  NOTE: Add WidgetColorStorage.swift (from Opalite/Utilities/) to the
//  OpaliteWidgets target in Xcode for shared color data access.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct RandomColorEntry: TimelineEntry {
    let date: Date
    let color: WidgetColor
}

// MARK: - Timeline Provider

struct RandomColorProvider: TimelineProvider {
    func placeholder(in context: Context) -> RandomColorEntry {
        RandomColorEntry(
            date: Date(),
            color: WidgetColor(
                id: UUID(),
                name: "Sample Blue",
                red: 0.2,
                green: 0.5,
                blue: 0.9,
                alpha: 1.0
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RandomColorEntry) -> Void) {
        let entry = RandomColorEntry(
            date: Date(),
            color: WidgetColorStorage.randomColor()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RandomColorEntry>) -> Void) {
        // Create entries that refresh periodically with different random colors
        var entries: [RandomColorEntry] = []
        let currentDate = Date()

        // Generate 6 entries, one every 10 minutes
        for minuteOffset in stride(from: 0, to: 60, by: 10) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = RandomColorEntry(
                date: entryDate,
                color: WidgetColorStorage.randomColor()
            )
            entries.append(entry)
        }

        // Refresh after the last entry
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Widget View

struct RandomColorWidgetView: View {
    var entry: RandomColorEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Fill entire widget corner to corner
            entry.color.swiftUIColor
                .ignoresSafeArea()

            // Color name in bottom right on capsule
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(entry.color.displayName)
                        .font(fontForFamily)
                        .fontWeight(.semibold)
                        .foregroundStyle(entry.color.idealTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, paddingForFamily)
                        .padding(.vertical, verticalPaddingForFamily)
                        .background(
                            Capsule()
                                .fill(entry.color.idealTextColor == .white ? .black.opacity(0.3) : .white.opacity(0.3))
                        )
                        .padding(paddingForFamily)
                }
            }
        }
        .widgetURL(URL(string: "opalite://color/\(entry.color.id.uuidString)"))
    }

    private var fontForFamily: Font {
        switch family {
        case .systemSmall:
            return .caption2
        case .systemMedium:
            return .caption
        case .systemLarge, .systemExtraLarge:
            return .subheadline
        default:
            return .caption2
        }
    }

    private var paddingForFamily: CGFloat {
        switch family {
        case .systemSmall:
            return 8
        case .systemMedium:
            return 10
        case .systemLarge, .systemExtraLarge:
            return 12
        default:
            return 8
        }
    }

    private var verticalPaddingForFamily: CGFloat {
        switch family {
        case .systemSmall:
            return 4
        case .systemMedium:
            return 5
        case .systemLarge, .systemExtraLarge:
            return 6
        default:
            return 4
        }
    }
}

// MARK: - Widget Definition

struct RandomColorWidget: Widget {
    let kind: String = "RandomColorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RandomColorProvider()) { entry in
            RandomColorWidgetView(entry: entry)
                .containerBackground(entry.color.swiftUIColor, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Random Color")
        .description("Displays a random color from your collection. Tap to view details.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    RandomColorWidget()
} timeline: {
    RandomColorEntry(
        date: .now,
        color: WidgetColor(id: UUID(), name: "Ocean Blue", red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0)
    )
    RandomColorEntry(
        date: .now,
        color: WidgetColor(id: UUID(), name: nil, red: 0.9, green: 0.3, blue: 0.5, alpha: 1.0)
    )
}

#Preview(as: .systemMedium) {
    RandomColorWidget()
} timeline: {
    RandomColorEntry(
        date: .now,
        color: WidgetColor(id: UUID(), name: "Sunset Orange", red: 0.95, green: 0.5, blue: 0.2, alpha: 1.0)
    )
}

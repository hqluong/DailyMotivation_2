// MARK: - DailyMotivationWatchWidget.swift

import SwiftUI
import WidgetKit

struct WatchQuoteEntry: TimelineEntry {
    let date: Date
    let quote: WatchQuote
}

/// One entry per day, refreshed at the next midnight so the quote changes with the date.
struct WatchQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchQuoteEntry {
        WatchQuoteEntry(date: Date(), quote: WatchQuoteStore.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchQuoteEntry) -> Void) {
        completion(WatchQuoteEntry(date: Date(), quote: WatchQuoteStore.quote()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchQuoteEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        // Today plus the next two days, each starting at midnight.
        let entries = (0..<3).compactMap { day -> WatchQuoteEntry? in
            guard let date = calendar.date(byAdding: .day, value: day, to: startOfToday) else { return nil }
            return WatchQuoteEntry(date: day == 0 ? now : date, quote: WatchQuoteStore.quote(for: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WatchQuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchQuoteEntry

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Daily Motivation", systemImage: "quote.opening")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                Text(entry.quote.text)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("“\(entry.quote.text)”")
        case .accessoryCorner:
            Image(systemName: "quote.opening")
                .font(.title3.weight(.bold))
                .widgetAccentable()
                .widgetLabel(entry.quote.author)
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "quote.opening")
                    .font(.title3.weight(.bold))
                    .widgetAccentable()
            }
        }
    }
}

struct DailyMotivationWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyMotivationWatchWidget", provider: WatchQuoteProvider()) { entry in
            WatchQuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Quote of the Day")
        .description("Today's quote on your watch face and in the Smart Stack.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct DailyMotivationWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyMotivationWatchWidget()
    }
}

#Preview(as: .accessoryRectangular) {
    DailyMotivationWatchWidget()
} timeline: {
    WatchQuoteEntry(date: .now, quote: WatchQuoteStore.fallback)
}

//
//  DailyMotivationWidget.swift
//  DailyMotivationWidget
//
//  Created by Hung Luong on 12/5/25.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct QuoteWidgetEntry: TimelineEntry {
    struct QuoteSnapshot: Hashable {
        let text: String
        let author: String
    }

    let date: Date
    let quote: QuoteSnapshot
}

// MARK: - Timeline Provider

struct QuoteTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteWidgetEntry {
        QuoteWidgetEntry(date: Date(), quote: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteWidgetEntry) -> Void) {
        let quote = QuoteWidgetDataSource.shared.quote(for: Date())
        completion(QuoteWidgetEntry(date: Date(), quote: quote))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteWidgetEntry>) -> Void) {
        let now = Date()
        let quote = QuoteWidgetDataSource.shared.quote(for: now)
        let entry = QuoteWidgetEntry(date: now, quote: quote)

        // Refresh on the hour to keep content fresh without spamming updates.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget View

struct QuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuoteWidgetEntry

    var body: some View {
        content
            .modifier(WidgetContainerBackground(family: family))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            accessoryInline
        case .accessoryRectangular:
            accessoryRectangular
#if os(iOS)
        case .accessoryCircular:
            accessoryCircular
#endif
        default:
            standardWidget
        }
    }

    private var standardWidget: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.18, blue: 0.36),
                    Color(red: 0.32, green: 0.17, blue: 0.45),
                    Color(red: 0.93, green: 0.41, blue: 0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.12))
                .blur(radius: 40)
                .frame(width: 180, height: 180)
                .offset(x: -40, y: -80)
            Circle()
                .fill(Color.white.opacity(0.12))
                .blur(radius: 50)
                .frame(width: 240, height: 240)
                .offset(x: 80, y: 120)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Today's focus", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text("Tap to open")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text("“\(entry.quote.text)”")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                Text(entry.quote.author)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    actionPill(text: "Favorite", systemImage: "heart.fill")
                    actionPill(text: "Share", systemImage: "square.and.arrow.up")
                    Spacer()
                }
            }
            .padding(16)
        }
        .widgetURL(URL(string: "dailymotivation://today"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Motivation")
                .font(.caption2.smallCaps())
                .foregroundStyle(.secondary)
            Text(entry.quote.text)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
            Text(entry.quote.author)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var accessoryInline: some View {
        Text("“\(entry.quote.text)” — \(entry.quote.author)")
    }

#if os(iOS)
    private var accessoryCircular: some View {
        ZStack {
            Circle().strokeBorder(style: StrokeStyle(lineWidth: 2)).foregroundStyle(.tint)
            Image(systemName: "quote.opening")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.tint)
        }
    }
#endif

    private func actionPill(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.14))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

struct DailyMotivationWidget: Widget {
    private let kind = "DailyMotivationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteTimelineProvider()) { entry in
            QuoteWidgetView(entry: entry)
        }
#if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular])
#else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
#endif
        .configurationDisplayName("Daily Motivation")
        .description("Beautiful motivation on your Home Screen and Lock Screen.")
    }
}

// MARK: - Data Source

final class QuoteWidgetDataSource {
    static let shared = QuoteWidgetDataSource()

    private let quotes: [QuoteWidgetEntry.QuoteSnapshot]
    private let calendar: Calendar

    private init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.quotes = QuoteWidgetDataSource.loadQuotes()
    }

    func quote(for date: Date) -> QuoteWidgetEntry.QuoteSnapshot {
        guard !quotes.isEmpty else {
            return .placeholder
        }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % quotes.count
        return quotes[index]
    }

    private static func loadQuotes() -> [QuoteWidgetEntry.QuoteSnapshot] {
        guard
            let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            data.count <= 256 * 1024 // guard against unexpectedly large payloads
        else {
            return [.fallback]
        }

        do {
            let decoded = try JSONDecoder().decode([RawQuote].self, from: data)
            let sanitized = decoded.compactMap { raw -> QuoteWidgetEntry.QuoteSnapshot? in
                let quote = raw.quote.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !quote.isEmpty else { return nil }
                let author = raw.author?.trimmingCharacters(in: .whitespacesAndNewlines)
                return QuoteWidgetEntry.QuoteSnapshot(
                    text: quote,
                    author: author?.isEmpty == false ? author! : "Unknown"
                )
            }
            return sanitized.isEmpty ? [.fallback] : sanitized
        } catch {
#if DEBUG
            print("Failed to decode quotes for widget: \(error)")
#endif
            return [.fallback]
        }
    }
}

private extension QuoteWidgetEntry.QuoteSnapshot {
    static let placeholder = QuoteWidgetEntry.QuoteSnapshot(
        text: "Excellence is the gradual result of always striving to do better.",
        author: "Pat Riley"
    )

    static let fallback = QuoteWidgetEntry.QuoteSnapshot(
        text: "Believe you can and you're halfway there.",
        author: "Theodore Roosevelt"
    )
}

private struct RawQuote: Decodable {
    let quote: String
    let author: String?
}

// MARK: - Background Helper

private struct WidgetContainerBackground: ViewModifier {
    let family: WidgetFamily
    private let backgroundView = LinearGradient(
        colors: [
            Color.blue.opacity(0.85),
            Color.purple.opacity(0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    backgroundView
                }
        } else {
            content
                .background(backgroundView)
        }
    }
}

// MARK: - Preview

struct DailyMotivationWidget_Previews: PreviewProvider {
    static var previews: some View {
        QuoteWidgetView(
            entry: QuoteWidgetEntry(date: Date(), quote: .placeholder)
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        QuoteWidgetView(
            entry: QuoteWidgetEntry(date: Date(), quote: .placeholder)
        )
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}

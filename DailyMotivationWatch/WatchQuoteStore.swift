// MARK: - WatchQuoteStore.swift

import Foundation

/// Quote of the day for the watch app and its complications.
/// Uses the same bundled quotes.json and day-of-year rotation as the iPhone app and widget,
/// so every surface shows the same quote on a given day.
struct WatchQuote: Hashable {
    let text: String
    let author: String
}

enum WatchQuoteStore {
    static let quotes: [WatchQuote] = load()

    static func quote(for date: Date = Date(), offset: Int = 0, calendar: Calendar = .current) -> WatchQuote {
        guard !quotes.isEmpty else { return fallback }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = ((dayOfYear - 1 + offset) % quotes.count + quotes.count) % quotes.count
        return quotes[index]
    }

    static let fallback = WatchQuote(
        text: "Believe you can and you're halfway there.",
        author: "Theodore Roosevelt"
    )

    private struct RawQuote: Decodable {
        let quote: String
        let author: String?
    }

    private static func load() -> [WatchQuote] {
        guard
            let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([RawQuote].self, from: data)
        else {
            return [fallback]
        }
        let cleaned = decoded.compactMap { raw -> WatchQuote? in
            let text = raw.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let author = raw.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return WatchQuote(text: text, author: author.isEmpty ? "Unknown" : author)
        }
        return cleaned.isEmpty ? [fallback] : cleaned
    }
}

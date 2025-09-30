//
//  QuoteLoader.swift
//  DailyMotivation
//
//  Created by Hung Luong on 3/9/25.
//

import Foundation

/// Loads quotes from the bundled quotes.json file.
struct QuoteLoader {
    /// Loads and decodes quotes from quotes.json in the app bundle.
    /// - Returns: An array of `Quote` objects, or an empty array if loading fails.
    static func loadQuotes() -> [Quote] {
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "json") else {
            print("Quotes file not found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let quotes = try JSONDecoder().decode([Quote].self, from: data)
            return quotes
        } catch {
            print("Error loading quotes: \(error)")
            return []
        }
    }
}

//
//  QuoteViewModel.swift
//  DailyMotivation
//
//  Created by Hung Luong on 4/1/25.
//

// MARK: - QuoteViewModel.swift

import Foundation
import Combine // Needed for ObservableObject

class QuoteViewModel: ObservableObject {
    // Published properties will automatically notify SwiftUI views of changes
    // REMOVED private(set) from allQuotes to allow setting from preview or elsewhere if needed
    @Published var allQuotes: [Quote] = []
    @Published var currentQuote: Quote? = nil
    @Published var errorMessage: String? = nil // To show errors to the user
    
    // Keep a reference to the favorites manager
    // Note: Injected dependency - better for testing and flexibility
    private var favoritesManager: FavoritesManager
    
    init(favoritesManager: FavoritesManager) {
        self.favoritesManager = favoritesManager
        loadQuotes()
        setCurrentQuoteToDaily()
    }
    
    // Load quotes using the QuoteLoader
    /// Loads quotes from the QuoteLoader and sets error messages if needed.
    private func loadQuotes() {
        let loadedQuotes = QuoteLoader.loadQuotes()
        self.allQuotes = loadedQuotes
        if loadedQuotes.isEmpty {
            errorMessage = "Could not load quotes. Please ensure 'quotes.json' is in the app bundle and is valid JSON."
        } else {
            errorMessage = nil
        }
    }
    
    // Set the current quote based on the day of the year
    func setCurrentQuoteToDaily() {
        guard !allQuotes.isEmpty else {
            currentQuote = nil
            return
        }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        // Ensure modulo operation doesn't crash if count is 0 (already guarded, but good practice)
        if allQuotes.count > 0 {
            currentQuote = allQuotes[day % allQuotes.count]
        } else {
            currentQuote = nil
        }
    }
    
    // Set the current quote to a random one from the list
    /// Sets the current quote to a new random quote, avoiding the current one if possible.
    func showNewRandomQuote() {
        guard !allQuotes.isEmpty else {
            currentQuote = nil
            return
        }
        if allQuotes.count == 1 {
            currentQuote = allQuotes.first
            return
        }
        let potentialQuotes = allQuotes.filter { $0.id != currentQuote?.id }
        currentQuote = (potentialQuotes.isEmpty ? allQuotes : potentialQuotes).randomElement()
    }
    
    // Convenience method to check if the *current* quote is a favorite
    func isCurrentQuoteFavorite() -> Bool {
        guard let quote = currentQuote else { return false }
        return favoritesManager.isFavorite(quote: quote)
    }
    
    // Convenience method to toggle the favorite status of the *current* quote
    func toggleCurrentQuoteFavorite() {
        guard let quote = currentQuote else { return }
        favoritesManager.toggleFavorite(quote: quote)
        // The FavoritesManager will publish its changes, and views observing it will update.
    }
    
    /// Returns the full list of favorite quotes.
    func getFavoriteQuotes() -> [Quote] {
        return favoritesManager.getFavoriteQuotes(from: allQuotes)
    }
    // Inside QuoteViewModel.swift class
    
    /// Returns the daily quote based on the day of the year.
    func getDailyQuote() -> Quote? {
        guard !allQuotes.isEmpty else { return nil }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let quoteIndex = (dayOfYear - 1) % allQuotes.count
        return allQuotes[quoteIndex]
    }
}

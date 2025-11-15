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
    @Published var currentQuote: Quote? = nil {
        didSet {
            guard let quote = currentQuote else { return }
            markQuoteAsSeen(quote)
        }
    }
    @Published var errorMessage: String? = nil // To show errors to the user
    
    // Keep references to managers so we can coordinate favorites and engagement tracking
    private var favoritesManager: FavoritesManager
    private var engagementTracker: EngagementTracker
    private let userDefaults: UserDefaults

    // Track which quotes have been shown each day
    private let seenQuoteIDsKey = "DailyMotivation.seenQuoteIDs"
    private let seenQuoteDateKey = "DailyMotivation.seenQuoteDate"
    private var seenQuoteIDs: Set<UUID> = []
    private var seenQuotesDate: Date?
    
    init(
        favoritesManager: FavoritesManager,
        engagementTracker: EngagementTracker,
        userDefaults: UserDefaults = .standard
    ) {
        self.favoritesManager = favoritesManager
        self.engagementTracker = engagementTracker
        self.userDefaults = userDefaults
        loadSeenQuotes()
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
        ensureSeenQuotesAreCurrent()
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        // Ensure modulo operation doesn't crash if count is 0 (already guarded, but good practice)
        if allQuotes.count > 0 {
            let dailyQuote = allQuotes[day % allQuotes.count]
            if seenQuoteIDs.contains(dailyQuote.id),
               let alternateQuote = nextUnseenQuote(from: allQuotes) {
                currentQuote = alternateQuote
            } else {
                currentQuote = dailyQuote
            }
        } else {
            currentQuote = nil
        }
    }
    
    // Set the current quote to a random one from the list
    /// Sets the current quote to a new random quote, avoiding the current one if possible.
    func showNewRandomQuote(category: String? = nil) {
        guard !allQuotes.isEmpty else {
            currentQuote = nil
            return
        }
        ensureSeenQuotesAreCurrent()

        let filteredQuotes: [Quote]
        if let category = category, !category.isEmpty {
            filteredQuotes = allQuotes.filter { $0.category == category }
        } else {
            filteredQuotes = allQuotes
        }

        guard !filteredQuotes.isEmpty else {
            return
        }

        if let nextQuote = nextUnseenQuote(from: filteredQuotes) {
            currentQuote = nextQuote
        }
    }
    
    // Convenience method to check if the *current* quote is a favorite
    func isCurrentQuoteFavorite() -> Bool {
        guard let quote = currentQuote else { return false }
        return favoritesManager.isFavorite(quote: quote)
    }
    
    // Convenience method to toggle the favorite status of the *current* quote
    func toggleCurrentQuoteFavorite() {
        guard let quote = currentQuote else { return }
        let isNowFavorite = favoritesManager.toggleFavorite(quote: quote)
        if isNowFavorite {
            engagementTracker.logQuoteFavorited()
        }
        // The FavoritesManager will publish its changes, and views observing it will update.
    }

    /// Returns the full list of favorite quotes.
    func getFavoriteQuotes() -> [Quote] {
        return favoritesManager.getFavoriteQuotes(from: allQuotes)
    }
    // Inside QuoteViewModel.swift class
    
    /// Records that today's quote was viewed so engagement streaks stay updated.
    func recordDailyQuoteView() {
        guard currentQuote != nil else { return }
        engagementTracker.logQuoteViewed()
    }

    /// Returns the daily quote based on the day of the year.
    func getDailyQuote() -> Quote? {
        guard !allQuotes.isEmpty else { return nil }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let quoteIndex = (dayOfYear - 1) % allQuotes.count
        return allQuotes[quoteIndex]
    }

    // MARK: - Daily seen quote tracking
    private func loadSeenQuotes() {
        let today = Date()
        guard let storedDate = userDefaults.object(forKey: seenQuoteDateKey) as? Date else {
            resetSeenQuotes(for: today)
            return
        }

        if Calendar.current.isDate(storedDate, inSameDayAs: today) {
            let idStrings = userDefaults.stringArray(forKey: seenQuoteIDsKey) ?? []
            seenQuoteIDs = Set(idStrings.compactMap { UUID(uuidString: $0) })
            seenQuotesDate = storedDate
        } else {
            resetSeenQuotes(for: today)
        }
    }

    private func saveSeenQuotes() {
        let idStrings = seenQuoteIDs.map { $0.uuidString }
        userDefaults.set(idStrings, forKey: seenQuoteIDsKey)
        if let date = seenQuotesDate {
            userDefaults.set(date, forKey: seenQuoteDateKey)
        }
    }

    private func resetSeenQuotes(for date: Date = Date()) {
        seenQuoteIDs.removeAll()
        seenQuotesDate = date
        saveSeenQuotes()
    }

    private func ensureSeenQuotesAreCurrent() {
        let today = Date()
        guard let storedDate = seenQuotesDate else {
            resetSeenQuotes(for: today)
            return
        }

        if !Calendar.current.isDate(storedDate, inSameDayAs: today) {
            resetSeenQuotes(for: today)
        }
    }

    private func markQuoteAsSeen(_ quote: Quote) {
        ensureSeenQuotesAreCurrent()
        let wasInserted = seenQuoteIDs.insert(quote.id).inserted
        if wasInserted {
            saveSeenQuotes()
        }
    }

    private func nextUnseenQuote(from quotes: [Quote]) -> Quote? {
        let unseenQuotes = quotes.filter { !seenQuoteIDs.contains($0.id) }
        return unseenQuotes.randomElement()
    }
}

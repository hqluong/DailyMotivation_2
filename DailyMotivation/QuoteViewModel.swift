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
        favoritesManager.cleanupOrphanedFavoriteIDs(validIDs: Set(loadedQuotes.map { $0.id }))
    }
    
    // Set the current quote based on the day of the year
    func setCurrentQuoteToDaily() {
        guard !allQuotes.isEmpty else {
            currentQuote = nil
            return
        }

        ensureSeenQuotesAreCurrent()
        currentQuote = getDailyQuote()
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

    /// Picks a random quote, prioritizing preferred categories and avoiding exclusions.
    func preferredRandomQuote(preferredCategories: [String], excludingIDs: Set<UUID> = []) -> Quote? {
        guard !allQuotes.isEmpty else { return nil }
        ensureSeenQuotesAreCurrent()

        let exclusions = excludingIDs
        let availableQuotes = allQuotes.filter { !exclusions.contains($0.id) }
        guard !availableQuotes.isEmpty else { return nil }

        let preferredSet = Set(preferredCategories)
        let preferredPool = availableQuotes.filter { preferredSet.contains($0.category) }

        if let preferred = nextUnseenQuote(from: preferredPool) ?? preferredPool.randomElement() {
            return preferred
        }

        return nextUnseenQuote(from: availableQuotes) ?? availableQuotes.randomElement()
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

    /// Toggles favorite for a specific quote (useful when the displayed quote differs from currentQuote).
    @discardableResult
    func toggleFavorite(for quote: Quote) -> Bool {
        let isNowFavorite = favoritesManager.toggleFavorite(quote: quote)
        if isNowFavorite {
            engagementTracker.logQuoteFavorited()
        }
        if currentQuote?.id == quote.id {
            currentQuote = quote
        }
        return isNowFavorite
    }

    /// Returns the full list of favorite quotes.
    func getFavoriteQuotes() -> [Quote] {
        return favoritesManager.getFavoriteQuotes(from: allQuotes)
    }

    /// Returns favorites with configurable sort and category filter.
    func getFavoriteQuotes(
        sortedBy sort: FavoriteSortOption,
        filteredBy category: String?
    ) -> [Quote] {
        return favoritesManager.getFavoriteQuotes(
            from: allQuotes,
            sortedBy: sort,
            filteredBy: category
        )
    }

    /// Returns quotes matching the search query across quote text and author.
    func filterQuotes(_ quotes: [Quote], matching query: String) -> [Quote] {
        let normalizedQuery = normalizedSearchText(for: query)
        guard !normalizedQuery.isEmpty else { return quotes }

        return quotes.filter { quote in
            searchableText(for: quote.quote).contains(normalizedQuery) ||
            searchableText(for: quote.author).contains(normalizedQuery)
        }
    }

    /// Returns favorite quotes with sort, category, and search applied.
    func getFavoriteQuotes(
        sortedBy sort: FavoriteSortOption,
        filteredBy category: String?,
        matching query: String
    ) -> [Quote] {
        let favorites = getFavoriteQuotes(sortedBy: sort, filteredBy: category)
        return filterQuotes(favorites, matching: query)
    }

    /// All distinct categories available in the current quote list.
    func availableCategories(includeAll: Bool = true) -> [String] {
        let unique = Set(allQuotes.map { $0.category })
        let base = unique.sorted()
        return includeAll ? ["All"] + base : base
    }

    /// Count of quotes per category so we can show category density.
    func categoryCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for quote in allQuotes {
            counts[quote.category, default: 0] += 1
        }
        return counts
    }
    // Inside QuoteViewModel.swift class
    
    /// Records that today's quote was viewed so engagement streaks stay updated.
    func recordDailyQuoteView() {
        guard currentQuote != nil else { return }
        engagementTracker.logQuoteViewed()
    }

    /// Returns the daily quote based on the day of the year.
    func getDailyQuote() -> Quote? {
        guard let quoteIndex = dailyQuoteIndex() else { return nil }
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

    private func normalizedSearchText(for text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func searchableText(for text: String) -> String {
        normalizedSearchText(for: text)
    }

    private func dailyQuoteIndex(for date: Date = Date()) -> Int? {
        guard !allQuotes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return (dayOfYear - 1) % allQuotes.count
    }
}

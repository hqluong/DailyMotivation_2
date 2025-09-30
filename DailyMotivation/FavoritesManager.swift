//
//  FavoritesManager.swift
//  DailyMotivation
//
//  Created by Hung Luong on 4/1/25.
//

// MARK: - FavoritesManager.swift

import Foundation
import Combine // Needed for ObservableObject

/// Manages the user's favorite quotes, including persistence and data consistency.
class FavoritesManager: ObservableObject {
    /// The key used to store favorite IDs in UserDefaults
    private let favoritesKey = "favoriteQuoteIDs"
    /// Published set of favorite quote IDs so views can react to changes
    @Published private(set) var favoriteIDs: Set<UUID>

    init() {
        // Load saved favorites when the manager is created
        self.favoriteIDs = Self.loadFavorites()
    }

    /// Loads the set of UUIDs from UserDefaults
    private static func loadFavorites() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: "favoriteQuoteIDs"),
              let decodedIDs = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
            return [] // Return empty set if no data or decoding fails
        }
        return decodedIDs
    }

    /// Saves the current set of favorite IDs to UserDefaults
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteIDs)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            print("Error saving favorites: \(error)")
            // In a real app, consider surfacing this error to the user.
        }
    }

    /// Checks if a specific quote is a favorite
    func isFavorite(quote: Quote) -> Bool {
        favoriteIDs.contains(quote.id)
    }

    /// Adds a quote to favorites
    func addFavorite(quote: Quote) {
        objectWillChange.send()
        favoriteIDs.insert(quote.id)
        saveFavorites()
    }

    /// Removes a quote from favorites
    func removeFavorite(quote: Quote) {
        objectWillChange.send()
        favoriteIDs.remove(quote.id)
        saveFavorites()
    }

    /// Toggles the favorite status of a quote
    func toggleFavorite(quote: Quote) {
        if isFavorite(quote: quote) {
            removeFavorite(quote: quote)
        } else {
            addFavorite(quote: quote)
        }
    }

    /// Returns an array of full Quote objects that are favorites, given a list of all quotes.
    /// Also cleans up orphaned favorite IDs that are not present in the current quotes.
    func getFavoriteQuotes(from allQuotes: [Quote]) -> [Quote] {
        let quoteDict = Dictionary(uniqueKeysWithValues: allQuotes.map { ($0.id, $0) })
        // Remove orphaned IDs (not present in allQuotes)
        let validIDs = favoriteIDs.filter { quoteDict[$0] != nil }
        if validIDs.count != favoriteIDs.count {
            // Clean up orphaned IDs
            objectWillChange.send()
            favoriteIDs = Set(validIDs)
            saveFavorites()
        }
        return validIDs.compactMap { quoteDict[$0] }.sorted { $0.quote < $1.quote }
    }
}

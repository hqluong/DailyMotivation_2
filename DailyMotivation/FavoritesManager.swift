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
        // Note: To cleanup orphaned IDs, call `cleanupOrphanedFavoriteIDs(validIDs:)` after loading quotes elsewhere
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
    
    /// Cleans up orphaned favorite IDs by removing IDs not present in validIDs,
    /// then saves the updated favorites.
    /// - Parameter validIDs: Set of UUIDs that are currently valid quotes.
    func cleanupOrphanedFavoriteIDs(validIDs: Set<UUID>) {
        let orphanedIDs = favoriteIDs.subtracting(validIDs)
        guard !orphanedIDs.isEmpty else { return }
        favoriteIDs.subtract(orphanedIDs)
        saveFavorites()
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
    /// - Returns: `true` if the quote is now a favorite, `false` if it was removed.
    @discardableResult
    func toggleFavorite(quote: Quote) -> Bool {
        if isFavorite(quote: quote) {
            removeFavorite(quote: quote)
            return false
        } else {
            addFavorite(quote: quote)
            return true
        }
    }

    /// Returns an array of full Quote objects that are favorites, given a list of all quotes.
    /// Filters out orphaned favorite IDs only in-memory; does not mutate or persist cleanup here.
    func getFavoriteQuotes(from allQuotes: [Quote]) -> [Quote] {
        let quoteDict = Dictionary(uniqueKeysWithValues: allQuotes.map { ($0.id, $0) })
        let validIDs = favoriteIDs.filter { quoteDict[$0] != nil }
        return validIDs.compactMap { quoteDict[$0] }.sorted { $0.quote < $1.quote }
    }
}

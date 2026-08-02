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
    private let favoriteTimestampsKey = "favoriteQuoteTimestamps"
    private let userDefaults: UserDefaults
    private let maxFavoritesCount: Int
    private static let maxStoredDataSize = 64 * 1024
    /// Published set of favorite quote IDs so views can react to changes
    @Published private(set) var favoriteIDs: Set<UUID>
    /// Tracks when a quote was favorited so we can sort by recency.
    @Published private(set) var favoriteTimestamps: [UUID: Date]

    init(userDefaults: UserDefaults = .standard, maxFavoritesCount: Int = 1024) {
        self.userDefaults = userDefaults
        self.maxFavoritesCount = max(0, maxFavoritesCount)
        // Load saved favorites when the manager is created
        self.favoriteIDs = Self.loadFavorites(
            from: userDefaults,
            key: favoritesKey,
            maxCount: self.maxFavoritesCount
        )
        self.favoriteTimestamps = Self.loadFavoriteTimestamps(
            from: userDefaults,
            key: favoriteTimestampsKey
        )
        seedMissingTimestamps()
        // Note: To cleanup orphaned IDs, call `cleanupOrphanedFavoriteIDs(validIDs:)` after loading quotes elsewhere
    }

    /// Loads the set of UUIDs from UserDefaults
    private static func loadFavorites(from userDefaults: UserDefaults, key: String, maxCount: Int) -> Set<UUID> {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        if data.count > maxStoredDataSize {
#if DEBUG
            print("Favorites data exceeded expected size; ignoring persisted payload.")
#endif
            return []
        }

        guard let decodedIDs = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
            // Return empty set if decoding fails to avoid crashing on tampered data
            return []
        }

        if maxCount > 0 && decodedIDs.count > maxCount {
#if DEBUG
            print("Favorites count exceeded limit (\(maxCount)); truncating to prevent abuse.")
#endif
            return truncate(decodedIDs, to: maxCount)
        }

        return decodedIDs
    }

    /// Loads favorite timestamps so we can retain recency ordering.
    private static func loadFavoriteTimestamps(
        from userDefaults: UserDefaults,
        key: String
    ) -> [UUID: Date] {
        guard
            let data = userDefaults.data(forKey: key),
            data.count <= maxStoredDataSize,
            let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else {
            return [:]
        }

        var result: [UUID: Date] = [:]
        for (key, value) in decoded {
            if let id = UUID(uuidString: key) {
                result[id] = value
            }
        }
        return result
    }

    /// Saves the current set of favorite IDs to UserDefaults
    private func saveFavorites() {
        if maxFavoritesCount > 0 && favoriteIDs.count > maxFavoritesCount {
            favoriteIDs = Self.truncate(favoriteIDs, to: maxFavoritesCount)
        }
        favoriteTimestamps = favoriteTimestamps.filter { favoriteIDs.contains($0.key) }

        do {
            let data = try JSONEncoder().encode(favoriteIDs)
            guard data.count <= Self.maxStoredDataSize else {
#if DEBUG
                print("Unable to save favorites: payload too large (\(data.count) bytes).")
#endif
                return
            }
            userDefaults.set(data, forKey: favoritesKey)
        } catch {
#if DEBUG
            print("Error saving favorites: \(error)")
#endif
            // In a real app, consider surfacing this error to the user.
        }
    }

    /// Persists favorite timestamps to disk.
    private func saveFavoriteTimestamps() {
        let codableDict = favoriteTimestamps.reduce(into: [String: Date]()) { dict, entry in
            dict[entry.key.uuidString] = entry.value
        }

        do {
            let data = try JSONEncoder().encode(codableDict)
            guard data.count <= Self.maxStoredDataSize else { return }
            userDefaults.set(data, forKey: favoriteTimestampsKey)
        } catch {
#if DEBUG
            print("Error saving favorite timestamps: \(error)")
#endif
        }
    }

    /// Ensures every favorite ID has a timestamp, useful for users upgrading from older versions.
    private func seedMissingTimestamps() {
        let now = Date()
        for id in favoriteIDs where favoriteTimestamps[id] == nil {
            favoriteTimestamps[id] = now
        }
        saveFavoriteTimestamps()
    }
    
    /// Cleans up orphaned favorite IDs by removing IDs not present in validIDs,
    /// then saves the updated favorites.
    /// - Parameter validIDs: Set of UUIDs that are currently valid quotes.
    func cleanupOrphanedFavoriteIDs(validIDs: Set<UUID>) {
        let orphanedIDs = favoriteIDs.subtracting(validIDs)
        guard !orphanedIDs.isEmpty else { return }
        favoriteIDs.subtract(orphanedIDs)
        for id in orphanedIDs {
            favoriteTimestamps.removeValue(forKey: id)
        }
        saveFavorites()
        saveFavoriteTimestamps()
    }

    /// Checks if a specific quote is a favorite
    func isFavorite(quote: Quote) -> Bool {
        favoriteIDs.contains(quote.id)
    }

    /// Adds a quote to favorites
    func addFavorite(quote: Quote) {
        objectWillChange.send()
        favoriteIDs.insert(quote.id)
        favoriteTimestamps[quote.id] = Date()
        saveFavorites()
        saveFavoriteTimestamps()
    }

    /// Removes a quote from favorites
    func removeFavorite(quote: Quote) {
        objectWillChange.send()
        favoriteIDs.remove(quote.id)
        favoriteTimestamps.removeValue(forKey: quote.id)
        saveFavorites()
        saveFavoriteTimestamps()
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

    func resetAll() {
        favoriteIDs.removeAll()
        favoriteTimestamps.removeAll()
        userDefaults.removeObject(forKey: favoritesKey)
        userDefaults.removeObject(forKey: favoriteTimestampsKey)
    }

    /// Returns an array of full Quote objects that are favorites, given a list of all quotes.
    /// Filters out orphaned favorite IDs only in-memory; does not mutate or persist cleanup here.
    func getFavoriteQuotes(
        from allQuotes: [Quote],
        sortedBy sort: FavoriteSortOption = .recent,
        filteredBy category: String? = nil
    ) -> [Quote] {
        let quoteDict = Dictionary(uniqueKeysWithValues: allQuotes.map { ($0.id, $0) })
        let validIDs = favoriteIDs.filter { quoteDict[$0] != nil }

        let filtered = validIDs.compactMap { quoteDict[$0] }.filter { quote in
            guard let category else { return true }
            return quote.category == category
        }

        switch sort {
        case .recent:
            return filtered.sorted {
                let lhsDate = favoriteTimestamps[$0.id] ?? .distantPast
                let rhsDate = favoriteTimestamps[$1.id] ?? .distantPast
                return lhsDate > rhsDate
            }
        case .alphabetical:
            return filtered.sorted {
                $0.quote.localizedCaseInsensitiveCompare($1.quote) == .orderedAscending
            }
        }
    }

    private static func truncate(_ ids: Set<UUID>, to limit: Int) -> Set<UUID> {
        guard limit > 0, ids.count > limit else { return ids }
        return Set(ids.prefix(limit))
    }
}

/// Sorting options for favorites so the UI can switch between recent and alphabetical.
enum FavoriteSortOption: String, CaseIterable, Identifiable {
    case recent
    case alphabetical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .alphabetical: return "A–Z"
        }
    }
}

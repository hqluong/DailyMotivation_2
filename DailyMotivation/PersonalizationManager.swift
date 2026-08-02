import Foundation
import Combine

/// Learns lightweight category preferences on-device from saves and skips.
final class PersonalizationManager: ObservableObject {
    @Published private(set) var categoryScores: [String: Int]

    private let userDefaults: UserDefaults
    private let scoresKey = "personalization.categoryScores.v1"
    private static let scoreRange = -20...50
    private static let maxStoredDataSize = 16 * 1024

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.categoryScores = Self.loadScores(from: userDefaults, key: scoresKey)
    }

    func recordSaved(_ quote: Quote) {
        adjust(category: quote.category, by: 3)
    }

    func recordSkipped(_ quote: Quote) {
        adjust(category: quote.category, by: -1)
    }

    func rankedCategories(availableCategories: [String]) -> [String] {
        availableCategories.sorted { lhs, rhs in
            let leftScore = categoryScores[lhs, default: 0]
            let rightScore = categoryScores[rhs, default: 0]
            if leftScore == rightScore {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            return leftScore > rightScore
        }
    }

    func resetAll() {
        categoryScores.removeAll()
        userDefaults.removeObject(forKey: scoresKey)
    }

    private func adjust(category: String, by amount: Int) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = categoryScores[trimmed, default: 0] + amount
        categoryScores[trimmed] = min(max(updated, Self.scoreRange.lowerBound), Self.scoreRange.upperBound)
        save()
    }

    private func save() {
        guard
            let data = try? JSONEncoder().encode(categoryScores),
            data.count <= Self.maxStoredDataSize
        else {
            return
        }
        userDefaults.set(data, forKey: scoresKey)
    }

    private static func loadScores(from userDefaults: UserDefaults, key: String) -> [String: Int] {
        guard
            let data = userDefaults.data(forKey: key),
            data.count <= maxStoredDataSize,
            let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }

        return decoded.reduce(into: [:]) { result, entry in
            let category = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !category.isEmpty else { return }
            result[category] = min(max(entry.value, scoreRange.lowerBound), scoreRange.upperBound)
        }
    }
}

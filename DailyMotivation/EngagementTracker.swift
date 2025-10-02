//
//  EngagementTracker.swift
//  DailyMotivation
//
//  Created by Codex on 4/27/25.
//

import Foundation
import Combine

/// Tracks how often the user engages with the app so we can surface streaks and history.
final class EngagementTracker: ObservableObject {
    /// Represents engagement details for a single calendar day.
    struct DailyEngagement: Identifiable, Hashable {
        let date: Date
        let viewed: Bool
        let favorited: Bool

        var id: Date { date }
    }

    /// Summary of the user's current and best streaks along with recent activity.
    struct StreakSummary: Equatable {
        let currentStreak: Int
        let bestStreak: Int
        let lastViewed: Date?
        let lastFavorited: Date?
        let needsReminderNudge: Bool
        let recentHistory: [DailyEngagement]

        static let empty = StreakSummary(
            currentStreak: 0,
            bestStreak: 0,
            lastViewed: nil,
            lastFavorited: nil,
            needsReminderNudge: true,
            recentHistory: []
        )
    }

    @Published private(set) var summary: StreakSummary

    private let userDefaults: UserDefaults
    private let historyWindow: Int
    private let calendar: Calendar

    private let viewedDatesKey = "engagement.viewedDates"
    private let favoriteDatesKey = "engagement.favoriteDates"
    private let bestStreakKey = "engagement.bestStreak"

    private var viewedDays: Set<Date>
    private var favoritedDays: Set<Date>
    private var bestStreak: Int

    init(
        userDefaults: UserDefaults = .standard,
        historyWindow: Int = 14,
        calendar: Calendar = .current
    ) {
        self.userDefaults = userDefaults
        self.historyWindow = historyWindow
        self.calendar = calendar

        self.viewedDays = EngagementTracker.loadDates(forKey: viewedDatesKey, from: userDefaults, calendar: calendar)
        self.favoritedDays = EngagementTracker.loadDates(forKey: favoriteDatesKey, from: userDefaults, calendar: calendar)
        self.bestStreak = userDefaults.integer(forKey: bestStreakKey)
        self.summary = .empty

        recalculateSummary()
    }

    /// Records that the daily quote was viewed on the supplied date (defaults to today).
    func logQuoteViewed(on date: Date = Date()) {
        let normalized = startOfDay(for: date)
        if viewedDays.insert(normalized).inserted {
            saveDates(viewedDays, key: viewedDatesKey)
        }
        recalculateSummary(reference: date)
    }

    /// Records that at least one quote was favorited on the supplied date (defaults to today).
    func logQuoteFavorited(on date: Date = Date()) {
        let normalized = startOfDay(for: date)
        if favoritedDays.insert(normalized).inserted {
            saveDates(favoritedDays, key: favoriteDatesKey)
        }
        recalculateSummary(reference: date)
    }

    /// Clears all tracked data. Useful for previews or testing.
    func resetAll() {
        viewedDays = []
        favoritedDays = []
        bestStreak = 0
        saveDates(viewedDays, key: viewedDatesKey)
        saveDates(favoritedDays, key: favoriteDatesKey)
        userDefaults.set(bestStreak, forKey: bestStreakKey)
        recalculateSummary()
    }
}

private extension EngagementTracker {
    static func loadDates(forKey key: String, from userDefaults: UserDefaults, calendar: Calendar) -> Set<Date> {
        guard
            let data = userDefaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([Date].self, from: data)
        else {
            return []
        }
        return Set(decoded.map { calendar.startOfDay(for: $0) })
    }

    func saveDates(_ dates: Set<Date>, key: String) {
        let ordered = Array(dates)
        if let data = try? JSONEncoder().encode(ordered) {
            userDefaults.set(data, forKey: key)
        }
    }

    func recalculateSummary(reference date: Date = Date()) {
        let today = startOfDay(for: date)
        let current = calculateCurrentStreak(asOf: today)

        if current > bestStreak {
            bestStreak = current
            userDefaults.set(bestStreak, forKey: bestStreakKey)
        }

        let lastViewed = viewedDays.max()
        let lastFavorited = favoritedDays.max()

        let needsNudge: Bool = {
            guard let lastViewed = lastViewed else { return true }
            let daysSinceLastView = calendar.dateComponents([.day], from: lastViewed, to: today).day ?? 0
            return daysSinceLastView >= 2
        }()

        let history = buildHistory(window: historyWindow, reference: today)

        let newSummary = StreakSummary(
            currentStreak: current,
            bestStreak: max(bestStreak, current),
            lastViewed: lastViewed,
            lastFavorited: lastFavorited,
            needsReminderNudge: needsNudge,
            recentHistory: history
        )

        if summary != newSummary {
            summary = newSummary
        }
    }

    func calculateCurrentStreak(asOf date: Date) -> Int {
        var streak = 0
        var cursor = date
        while viewedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func buildHistory(window: Int, reference date: Date) -> [DailyEngagement] {
        guard window > 0 else { return [] }
        var results: [DailyEngagement] = []
        results.reserveCapacity(window)

        for offset in stride(from: window - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { continue }
            let normalized = startOfDay(for: day)
            let viewed = viewedDays.contains(normalized)
            let favorited = favoritedDays.contains(normalized)
            results.append(DailyEngagement(date: normalized, viewed: viewed, favorited: favorited))
        }
        return results
    }
}

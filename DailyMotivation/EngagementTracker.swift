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
        let shareClickedCount: Int
        let shareCompletedCount: Int

        static let empty = StreakSummary(
            currentStreak: 0,
            bestStreak: 0,
            lastViewed: nil,
            lastFavorited: nil,
            needsReminderNudge: true,
            recentHistory: [],
            shareClickedCount: 0,
            shareCompletedCount: 0
        )
    }

    @Published private(set) var summary: StreakSummary

    private let userDefaults: UserDefaults
    private let historyWindow: Int
    private let calendar: Calendar

    private let viewedDatesKey = "engagement.viewedDates"
    private let favoriteDatesKey = "engagement.favoriteDates"
    private let bestStreakKey = "engagement.bestStreak"
    private let shareClickedCountKey = "engagement.shareClickedCount"
    private let shareCompletedCountKey = "engagement.shareCompletedCount"
    private static let maxTrackedDays = 365
    private static let maxBestStreak = 10_000
    private static let maxShareEventCount = 1_000_000
    private static let maxStoredDataSize = 128 * 1024
    private static let maxHistoryAge: TimeInterval = 60 * 60 * 24 * 365 * 5 // five years

    private var viewedDays: Set<Date>
    private var favoritedDays: Set<Date>
    private var bestStreak: Int
    private var shareClickedCount: Int
    private var shareCompletedCount: Int

    init(
        userDefaults: UserDefaults = .standard,
        historyWindow: Int = 14,
        calendar: Calendar = .current
    ) {
        self.userDefaults = userDefaults
        self.historyWindow = max(0, historyWindow)
        self.calendar = calendar

        let referenceDate = Date()
        self.viewedDays = EngagementTracker.loadDates(
            forKey: viewedDatesKey,
            from: userDefaults,
            calendar: calendar,
            reference: referenceDate
        )
        self.favoritedDays = EngagementTracker.loadDates(
            forKey: favoriteDatesKey,
            from: userDefaults,
            calendar: calendar,
            reference: referenceDate
        )
        self.bestStreak = EngagementTracker.loadBestStreak(
            forKey: bestStreakKey,
            from: userDefaults
        )
        self.shareClickedCount = EngagementTracker.loadCount(
            forKey: shareClickedCountKey,
            from: userDefaults,
            maxValue: Self.maxShareEventCount
        )
        self.shareCompletedCount = EngagementTracker.loadCount(
            forKey: shareCompletedCountKey,
            from: userDefaults,
            maxValue: Self.maxShareEventCount
        )
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

    /// Records a tap on the quote share button.
    func logShareClicked() {
        shareClickedCount = min(shareClickedCount + 1, Self.maxShareEventCount)
        userDefaults.set(shareClickedCount, forKey: shareClickedCountKey)
        recalculateSummary()
    }

    /// Records a successful share completion from the system share sheet.
    func logShareCompleted() {
        shareCompletedCount = min(shareCompletedCount + 1, Self.maxShareEventCount)
        userDefaults.set(shareCompletedCount, forKey: shareCompletedCountKey)
        recalculateSummary()
    }

    /// Clears all tracked data. Useful for previews or testing.
    func resetAll() {
        viewedDays = []
        favoritedDays = []
        bestStreak = 0
        shareClickedCount = 0
        shareCompletedCount = 0
        saveDates(viewedDays, key: viewedDatesKey)
        saveDates(favoritedDays, key: favoriteDatesKey)
        userDefaults.set(bestStreak, forKey: bestStreakKey)
        userDefaults.set(shareClickedCount, forKey: shareClickedCountKey)
        userDefaults.set(shareCompletedCount, forKey: shareCompletedCountKey)
        recalculateSummary()
    }
}

private extension EngagementTracker {
    static func loadDates(forKey key: String, from userDefaults: UserDefaults, calendar: Calendar, reference: Date) -> Set<Date> {
        guard
            let data = userDefaults.data(forKey: key),
            data.count <= maxStoredDataSize,
            let decoded = try? JSONDecoder().decode([Date].self, from: data)
        else {
            return []
        }
        let normalized = decoded.map { calendar.startOfDay(for: $0) }
        let trimmedToRecent = normalized.filter {
            abs($0.timeIntervalSince(reference)) <= maxHistoryAge
        }
        if trimmedToRecent.count > maxTrackedDays {
            let sorted = trimmedToRecent.sorted(by: >)
            return Set(sorted.prefix(maxTrackedDays))
        }
        return Set(trimmedToRecent)
    }

    static func loadBestStreak(forKey key: String, from userDefaults: UserDefaults) -> Int {
        let storedValue = userDefaults.integer(forKey: key)
        if storedValue < 0 { return 0 }
        return min(storedValue, maxBestStreak)
    }

    static func loadCount(forKey key: String, from userDefaults: UserDefaults, maxValue: Int) -> Int {
        let storedValue = userDefaults.integer(forKey: key)
        if storedValue < 0 { return 0 }
        return min(storedValue, maxValue)
    }

    func saveDates(_ dates: Set<Date>, key: String) {
        let sanitized = sanitizeDates(dates, reference: Date())
        let ordered = Array(sanitized)
        if let data = try? JSONEncoder().encode(ordered),
           data.count <= Self.maxStoredDataSize {
            userDefaults.set(data, forKey: key)
        } else if sanitized.isEmpty {
            userDefaults.removeObject(forKey: key)
        } else {
#if DEBUG
            print("Unable to persist engagement dates for \(key); payload too large or encoding failed.")
#endif
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
            recentHistory: history,
            shareClickedCount: shareClickedCount,
            shareCompletedCount: shareCompletedCount
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

    func sanitizeDates(_ dates: Set<Date>, reference: Date) -> Set<Date> {
        let normalized = dates.map { calendar.startOfDay(for: $0) }
        let trimmed = normalized.filter { abs($0.timeIntervalSince(reference)) <= Self.maxHistoryAge }
        if trimmed.count > Self.maxTrackedDays {
            let sorted = trimmed.sorted(by: >)
            return Set(sorted.prefix(Self.maxTrackedDays))
        }
        return Set(trimmed)
    }
}

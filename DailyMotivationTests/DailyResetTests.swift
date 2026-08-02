import Foundation
import Testing
@testable import DailyMotivation

struct DailyResetTests {

    @Test
    func dailyReset_persistsAndRequiresReflectionBeforeCompletion() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = DailyResetManager(userDefaults: defaults)
        let quoteID = UUID()

        let entry = manager.start(
            need: .focus,
            quoteID: quoteID,
            action: DailyNeed.focus.suggestedActions[0]
        )

        #expect(!manager.complete(entryID: entry.id))

        manager.update(entryID: entry.id, reflection: "I will finish the launch checklist.")

        #expect(manager.complete(entryID: entry.id))
        #expect(manager.entry()?.isCompleted == true)

        let reloaded = DailyResetManager(userDefaults: defaults)
        #expect(reloaded.entry()?.quoteID == quoteID)
        #expect(reloaded.entry()?.reflection == "I will finish the launch checklist.")
        #expect(reloaded.entry()?.isCompleted == true)
    }

    @Test
    func meaningfulStreak_advancesOnResetButNotOnQuoteView() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tracker = EngagementTracker(userDefaults: defaults)

        tracker.logQuoteViewed()
        #expect(tracker.summary.currentStreak == 0)

        tracker.logDailyResetCompleted()
        #expect(tracker.summary.currentStreak == 1)
        #expect(tracker.summary.recentHistory.last?.resetCompleted == true)
    }

    @Test
    func legacyVisitStreak_isMigratedOnce() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let today = Calendar.current.startOfDay(for: Date())
        defaults.set(try JSONEncoder().encode([today]), forKey: "engagement.viewedDates")

        let tracker = EngagementTracker(userDefaults: defaults)

        #expect(tracker.summary.currentStreak == 1)
        #expect(defaults.bool(forKey: "engagement.meaningfulStreakMigrationV1"))
    }

    @Test
    func personalization_isLocalPersistentAndRanksPositiveSignalsFirst() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = PersonalizationManager(userDefaults: defaults)
        let focus = Quote(quote: "Focus on the next step.", author: "Daily Motivation", category: "Focus")
        let success = Quote(quote: "Build the result patiently.", author: "Daily Motivation", category: "Success")

        manager.recordSaved(focus)
        manager.recordSkipped(success)

        #expect(manager.rankedCategories(availableCategories: ["Success", "Focus"]).first == "Focus")

        let reloaded = PersonalizationManager(userDefaults: defaults)
        #expect(reloaded.categoryScores["Focus"] == 3)
        #expect(reloaded.categoryScores["Success"] == -1)
    }

    @Test
    func notificationDates_beginAtTheNextFutureDeliveryTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 13,
            hour: 10,
            minute: 30
        )))

        let dates = NotificationManager.upcomingDeliveryDates(
            count: 3,
            hour: 9,
            minute: 0,
            now: now,
            calendar: calendar
        )

        #expect(dates.count == 3)
        #expect(calendar.component(.day, from: dates[0]) == 14)
        #expect(calendar.component(.day, from: dates[2]) == 16)
        #expect(calendar.component(.hour, from: dates[0]) == 9)

        let weekdays = NotificationManager.upcomingDeliveryWeekdays(
            count: NotificationManager.Identifier.quoteSequenceLength,
            hour: 9,
            minute: 0,
            now: now,
            calendar: calendar
        )
        #expect(weekdays.count == 7)
        #expect(Set(weekdays).count == 7)
    }

    @Test
    func plannedQuotes_stayInsidePreferredCategories() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let favorites = FavoritesManager(userDefaults: defaults)
        let engagement = EngagementTracker(userDefaults: defaults)
        let viewModel = QuoteViewModel(
            favoritesManager: favorites,
            engagementTracker: engagement,
            userDefaults: defaults
        )
        viewModel.allQuotes = [
            Quote(quote: "Focused choice one.", author: "Daily Motivation", category: "Focus"),
            Quote(quote: "Focused choice two.", author: "Daily Motivation", category: "Focus"),
            Quote(quote: "Success choice one.", author: "Daily Motivation", category: "Success")
        ]

        let planned = viewModel.plannedQuotes(count: 8, preferredCategories: ["Focus"])

        #expect(planned.count == 8)
        #expect(planned.allSatisfy { $0.category == "Focus" })
    }

    @Test
    func randomQuote_avoidsAnImmediateRepeatAfterTheSeenPoolIsExhausted() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let favorites = FavoritesManager(userDefaults: defaults)
        let engagement = EngagementTracker(userDefaults: defaults)
        let viewModel = QuoteViewModel(
            favoritesManager: favorites,
            engagementTracker: engagement,
            userDefaults: defaults
        )
        let first = Quote(quote: "First focused choice.", author: "Daily Motivation", category: "Focus")
        let second = Quote(quote: "Second focused choice.", author: "Daily Motivation", category: "Focus")
        viewModel.allQuotes = [first, second]
        viewModel.currentQuote = first
        viewModel.currentQuote = second
        viewModel.currentQuote = first

        viewModel.showNewRandomQuote(category: "Focus")

        #expect(viewModel.currentQuote == second)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "DailyResetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

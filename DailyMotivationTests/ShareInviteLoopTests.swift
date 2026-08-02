import Foundation
import Testing
@testable import DailyMotivation

struct ShareInviteLoopTests {

    @Test
    func shareMessage_usesHonestHeadlineAndDirectDownloadCTA() {
        let quote = Quote(
            quote: "Small steps compound.",
            author: "Daily Motivation",
            category: "Focus"
        )

        let message = ShareInviteMessageBuilder.message(for: quote, currentStreak: 4)
        let lines = message.components(separatedBy: .newlines)

        #expect(lines[0] == ShareInviteMessageBuilder.shareCTA)
        #expect(lines.last == ShareInviteMessageBuilder.downloadCTA)
        #expect(ShareInviteMessageBuilder.downloadCTA.contains("id6756123822"))
        #expect(!message.localizedCaseInsensitiveContains("challenge"))
        #expect(message.contains("I'm on a 4-day streak in Daily Motivation."))
        #expect(message.contains("\"Small steps compound.\""))
        #expect(message.contains("- Daily Motivation"))
    }

    @Test
    func shareInviteMessage_includesOneDayStreak() {
        let quote = Quote(quote: "Begin again.", author: "Unknown")

        let message = ShareInviteMessageBuilder.message(for: quote, currentStreak: 1)

        #expect(message.contains("I'm on a 1-day streak in Daily Motivation."))
        #expect(!message.contains("I found this quote in Daily Motivation."))
    }

    @Test
    func shareInviteMessage_usesResetMessageWhenNoStreakExists() {
        let quote = Quote(quote: "Reset with intention.", author: "Unknown")

        let message = ShareInviteMessageBuilder.message(for: quote, currentStreak: 0)

        #expect(message.contains("I found this quote in Daily Motivation."))
        #expect(!message.contains("0-day streak"))
    }

    @Test
    func engagementTracker_shareCountersPersistAndReset() {
        let suiteName = "ShareInviteLoopTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let tracker = EngagementTracker(userDefaults: userDefaults)
        tracker.logShareClicked()
        tracker.logShareClicked()
        tracker.logShareCompleted()

        #expect(tracker.summary.shareClickedCount == 2)
        #expect(tracker.summary.shareCompletedCount == 1)

        let reloadedTracker = EngagementTracker(userDefaults: userDefaults)

        #expect(reloadedTracker.summary.shareClickedCount == 2)
        #expect(reloadedTracker.summary.shareCompletedCount == 1)

        reloadedTracker.resetAll()

        #expect(reloadedTracker.summary.shareClickedCount == 0)
        #expect(reloadedTracker.summary.shareCompletedCount == 0)
    }
}

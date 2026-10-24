import Foundation
import Testing
import UserNotifications
@testable import DailyMotivation

/// Schedules through the real notification center and reads back what iOS has queued.
/// Needs notification permission on the test simulator (`simctl privacy grant notifications`);
/// skips its checks otherwise.
@Suite(.serialized)
struct NotificationSchedulingTests {

    private let center = UNUserNotificationCenter.current()

    private func pending() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    private func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        let ok = status == .authorized || status == .provisional
        if !ok { print("NotificationSchedulingTests: SKIPPED, notifications not authorized (status \(status.rawValue))") }
        return ok
    }

    /// The manager adds requests asynchronously; poll until the expected count appears.
    private func waitForPending(where predicate: @escaping ([UNNotificationRequest]) -> Bool) async -> [UNNotificationRequest] {
        for _ in 0..<40 {
            let requests = await pending()
            if predicate(requests) { return requests }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return await pending()
    }

    private func sampleQuotes(_ count: Int) -> [Quote] {
        let json = (0..<count).map { i in
            #"{"quote":"Quote number \#(i)","author":"Author \#(i)","category":"Motivation"}"#
        }.joined(separator: ",")
        return try! JSONDecoder().decode([Quote].self, from: Data("[\(json)]".utf8))
    }

    @Test
    func dailyQuote_queuesSevenRepeatingWeeklyNotificationsWithDifferentQuotes() async {
        guard await isAuthorized() else { return }
        center.removeAllPendingNotificationRequests()

        NotificationManager.shared.scheduleDailyQuoteNotifications(quotes: sampleQuotes(7), hour: 9, minute: 0)

        let daily = await waitForPending { $0.filter { $0.identifier.hasPrefix(NotificationManager.Identifier.daily) }.count == 7 }
            .filter { $0.identifier.hasPrefix(NotificationManager.Identifier.daily) }

        #expect(daily.count == 7)
        let triggers = daily.compactMap { $0.trigger as? UNCalendarNotificationTrigger }
        #expect(triggers.count == 7)
        // Every request repeats, fires at 9:00, and together they cover all seven weekdays.
        #expect(triggers.allSatisfy { $0.repeats })
        #expect(triggers.allSatisfy { $0.dateComponents.hour == 9 && $0.dateComponents.minute == 0 })
        #expect(Set(triggers.compactMap { $0.dateComponents.weekday }) == Set(1...7))
        // Each day carries its own quote.
        #expect(Set(daily.map { $0.content.body }).count == 7)
        #expect(daily.allSatisfy { $0.content.title == "Daily Motivation" && $0.content.body.contains("Quote number") })
        // Next delivery is at most a day away.
        let next = triggers.compactMap { $0.nextTriggerDate() }.min()
        #expect(next.map { $0.timeIntervalSinceNow <= 24 * 60 * 60 } == true)

        center.removeAllPendingNotificationRequests()
    }

    @Test
    func customReminder_queuesOneRepeatingRequestPerChosenWeekday() async {
        guard await isAuthorized() else { return }
        center.removeAllPendingNotificationRequests()

        let reminder = CustomReminder(title: "Evening read", hour: 20, minute: 30, weekdays: [.monday, .wednesday, .friday])
        let quotes = sampleQuotes(7)
        NotificationManager.shared.updateReminders([
            reminder.asNotification(quotesByWeekday: CustomReminder.weekdayQuotes(quotes), fallback: quotes[0])
        ])

        let custom = await waitForPending { $0.filter { $0.identifier.hasPrefix(NotificationManager.Identifier.flexibleReminderPrefix) }.count == 3 }
            .filter { $0.identifier.hasPrefix(NotificationManager.Identifier.flexibleReminderPrefix) }

        #expect(custom.count == 3)
        let triggers = custom.compactMap { $0.trigger as? UNCalendarNotificationTrigger }
        #expect(triggers.allSatisfy { $0.repeats && $0.dateComponents.hour == 20 && $0.dateComponents.minute == 30 })
        #expect(Set(triggers.compactMap { $0.dateComponents.weekday }) == [2, 4, 6])
        #expect(custom.allSatisfy { $0.content.title == "Evening read" })
        // Each chosen day carries its own quote.
        #expect(Set(custom.map { $0.content.body }).count == 3)

        center.removeAllPendingNotificationRequests()
    }

    @Test
    func weekdayQuotes_giveEachWeekdayADifferentQuoteAndOffsetRotates() {
        let quotes = sampleQuotes(7)
        let first = CustomReminder.weekdayQuotes(quotes)
        let second = CustomReminder.weekdayQuotes(quotes, offset: 1)

        #expect(first.count == 7)
        #expect(Set(first.values.map { $0.id }).count == 7)
        // Two reminders on the same day get different quotes.
        #expect(ReminderWeekday.allCases.allSatisfy { first[$0]?.id != second[$0]?.id })

        let notification = CustomReminder(weekdays: [.monday, .tuesday]).asNotification(quotesByWeekday: first, fallback: quotes[0])
        #expect(notification.body(for: .monday) != notification.body(for: .tuesday))
        #expect(notification.body(for: .monday).contains("Quote number"))
    }

    @Test
    func everythingOn_staysUnderTheSixtyFourPendingLimit() {
        // iOS keeps at most 64 pending requests per app: daily + morning + evening (7 each)
        // plus the maximum number of custom reminders on every weekday must fit.
        let worstCase = 3 * NotificationManager.Identifier.quoteSequenceLength
            + NotificationManager.Identifier.maximumFlexibleReminderCount * 7
        #expect(worstCase <= 64)
    }
}


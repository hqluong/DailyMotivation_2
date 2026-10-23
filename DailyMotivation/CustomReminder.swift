import Foundation

/// User-defined reminder persisted in app storage and translated into notification requests.
struct CustomReminder: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var hour: Int
    var minute: Int
    var weekdays: Set<ReminderWeekday>
    var isEnabled: Bool

    init(
        id: String = UUID().uuidString,
        title: String = "Daily Motivation",
        hour: Int = 9,
        minute: Int = 0,
        weekdays: Set<ReminderWeekday> = Set(ReminderWeekday.allCases),
        isEnabled: Bool = true
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.weekdays = weekdays
        self.isEnabled = isEnabled
    }

    var schedule: ReminderSchedule {
        ReminderSchedule(
            id: id,
            weekdays: weekdays,
            hour: hour,
            minute: minute,
            isEnabled: isEnabled
        )
    }

    /// Builds the notification with a different quote on each weekday.
    func asNotification(quotesByWeekday: [ReminderWeekday: Quote], fallback: Quote) -> ReminderNotification {
        var notification = asNotification(quote: fallback)
        notification.bodiesByWeekday = quotesByWeekday.mapValues(Self.body(for:))
        return notification
    }

    /// Assigns `quotes` to the next seven days starting today, so each weekday gets its own quote.
    /// `offset` rotates the assignment so several reminders on the same day don't repeat each other.
    static func weekdayQuotes(
        _ quotes: [Quote],
        offset: Int = 0,
        startingFrom date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderWeekday: Quote] {
        guard !quotes.isEmpty else { return [:] }
        var result: [ReminderWeekday: Quote] = [:]
        for day in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: date),
                  let weekday = ReminderWeekday(rawValue: calendar.component(.weekday, from: dayDate))
            else { continue }
            result[weekday] = quotes[(day + offset) % quotes.count]
        }
        return result
    }

    private static func body(for quote: Quote) -> String {
        "\"\(quote.quote)\" - \(quote.author)"
    }

    func asNotification(quote: Quote) -> ReminderNotification {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notificationTitle = trimmedTitle.isEmpty ? "Daily Motivation" : trimmedTitle
        return ReminderNotification(
            schedule: schedule,
            title: notificationTitle,
            body: Self.body(for: quote)
        )
    }
}

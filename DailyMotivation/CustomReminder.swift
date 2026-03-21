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

    func asNotification(quote: Quote) -> ReminderNotification {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notificationTitle = trimmedTitle.isEmpty ? "Daily Motivation" : trimmedTitle
        return ReminderNotification(
            schedule: schedule,
            title: notificationTitle,
            body: "\"\(quote.quote)\" - \(quote.author)"
        )
    }
}

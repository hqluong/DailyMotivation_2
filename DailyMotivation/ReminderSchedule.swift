import Foundation

struct ReminderSchedule: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var weekdays: Set<ReminderWeekday>
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    init(
        id: String,
        weekdays: Set<ReminderWeekday> = Set(ReminderWeekday.allCases),
        hour: Int,
        minute: Int,
        isEnabled: Bool = true
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.weekdays = weekdays
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.isEnabled = isEnabled
    }

    var normalizedWeekdays: [ReminderWeekday] {
        weekdays.sorted { $0.rawValue < $1.rawValue }
    }
}

enum ReminderWeekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

struct ReminderNotification: Codable, Hashable, Identifiable, Sendable {
    var schedule: ReminderSchedule
    var title: String
    var body: String
    var playsSound: Bool

    init(
        schedule: ReminderSchedule,
        title: String,
        body: String,
        playsSound: Bool = true
    ) {
        self.schedule = schedule
        self.title = title
        self.body = body
        self.playsSound = playsSound
    }

    var id: String {
        schedule.id
    }
}

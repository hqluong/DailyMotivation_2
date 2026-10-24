import Foundation
import Combine

enum DailyNeed: String, CaseIterable, Codable, Identifiable {
    case focus
    case calm
    case confidence
    case resilience
    case gratitude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .calm: return "Calm"
        case .confidence: return "Confidence"
        case .resilience: return "Resilience"
        case .gratitude: return "Gratitude"
        }
    }

    var iconName: String {
        switch self {
        case .focus: return "scope"
        case .calm: return "wind"
        case .confidence: return "figure.stand"
        case .resilience: return "mountain.2.fill"
        case .gratitude: return "heart.text.square.fill"
        }
    }

    var quoteCategories: [String] {
        switch self {
        case .focus: return ["Focus", "Success"]
        case .calm: return ["Mindfulness", "Happiness"]
        case .confidence: return ["Motivation", "Success"]
        case .resilience: return ["Resilience", "Motivation"]
        case .gratitude: return ["Gratitude", "Happiness", "Mindfulness"]
        }
    }

    var reflectionPrompt: String {
        switch self {
        case .focus: return "What deserves your full attention today?"
        case .calm: return "What can you release for the rest of today?"
        case .confidence: return "What is one ability you can trust in yourself?"
        case .resilience: return "What is the next step you can take despite the setback?"
        case .gratitude: return "What is one specific thing you appreciate right now?"
        }
    }

    var suggestedActions: [String] {
        switch self {
        case .focus:
            return [
                "Protect 15 minutes for your top priority.",
                "Silence one distraction until the task is done.",
                "Write the next three steps before you begin."
            ]
        case .calm:
            return [
                "Take five slow breaths before your next task.",
                "Step away from the screen for two minutes.",
                "Choose one thing that can wait until tomorrow."
            ]
        case .confidence:
            return [
                "Do one small task you have been postponing.",
                "Write down one recent win.",
                "Speak to yourself as you would to a close friend."
            ]
        case .resilience:
            return [
                "Restart with the smallest possible next step.",
                "Name one lesson from the setback.",
                "Ask one person for the support you need."
            ]
        case .gratitude:
            return [
                "Send one sincere thank-you message.",
                "Notice one ordinary thing that made today easier.",
                "Write down three details you do not want to overlook."
            ]
        }
    }
}

struct DailyResetEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var quoteID: UUID
    var need: DailyNeed
    var reflection: String
    var action: String
    var completedAt: Date?
    var updatedAt: Date

    var isCompleted: Bool {
        completedAt != nil
    }
}

final class DailyResetManager: ObservableObject {
    @Published private(set) var entries: [DailyResetEntry]

    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let entriesKey = "dailyReset.entries.v1"
    private static let maxEntries = 730
    private static let maxStoredDataSize = 512 * 1024
    private static let maxReflectionLength = 1_200

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.entries = Self.loadEntries(
            from: userDefaults,
            key: entriesKey,
            calendar: calendar
        )
    }

    func entry(for date: Date = Date()) -> DailyResetEntry? {
        let day = calendar.startOfDay(for: date)
        return entries.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    @discardableResult
    func start(
        need: DailyNeed,
        quoteID: UUID,
        action: String,
        on date: Date = Date()
    ) -> DailyResetEntry {
        if let existing = entry(for: date) {
            return existing
        }

        let entry = DailyResetEntry(
            id: UUID(),
            date: calendar.startOfDay(for: date),
            quoteID: quoteID,
            need: need,
            reflection: "",
            action: action,
            completedAt: nil,
            updatedAt: date
        )
        entries.insert(entry, at: 0)
        trimAndSave()
        return entry
    }

    func update(
        entryID: UUID,
        reflection: String? = nil,
        action: String? = nil,
        now: Date = Date()
    ) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        if let reflection {
            let trimmed = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
            entries[index].reflection = String(trimmed.prefix(Self.maxReflectionLength))
        }
        if let action {
            entries[index].action = action.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        entries[index].updatedAt = now
        trimAndSave()
    }

    @discardableResult
    func complete(entryID: UUID, now: Date = Date()) -> Bool {
        guard
            let index = entries.firstIndex(where: { $0.id == entryID }),
            !entries[index].reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !entries[index].action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        if entries[index].completedAt == nil {
            entries[index].completedAt = now
        }
        entries[index].updatedAt = now
        trimAndSave()
        return true
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        save()
    }

    func resetAll() {
        entries.removeAll()
        userDefaults.removeObject(forKey: entriesKey)
    }

    private func trimAndSave() {
        entries.sort { $0.date > $1.date }
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        save()
    }

    private func save() {
        guard
            let data = try? JSONEncoder().encode(entries),
            data.count <= Self.maxStoredDataSize
        else {
            return
        }
        userDefaults.set(data, forKey: entriesKey)
    }

    private static func loadEntries(
        from userDefaults: UserDefaults,
        key: String,
        calendar: Calendar
    ) -> [DailyResetEntry] {
        guard
            let data = userDefaults.data(forKey: key),
            data.count <= maxStoredDataSize,
            let decoded = try? JSONDecoder().decode([DailyResetEntry].self, from: data)
        else {
            return []
        }

        var seenDays = Set<Date>()
        return decoded
            .sorted { $0.date > $1.date }
            .filter { entry in
                let day = calendar.startOfDay(for: entry.date)
                return seenDays.insert(day).inserted
            }
            .prefix(maxEntries)
            .map { $0 }
    }
}

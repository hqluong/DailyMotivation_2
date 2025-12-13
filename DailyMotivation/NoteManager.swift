// MARK: - NoteManager.swift
// Stores short per-quote notes locally so users can jot takeaways.

import Foundation
import Combine

final class NoteManager: ObservableObject {
    @Published private(set) var notes: [UUID: String]

    private let userDefaults: UserDefaults
    private let notesKey = "quoteNotes"
    private static let maxStoredDataSize = 128 * 1024
    private static let maxNoteLength = 800

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.notes = NoteManager.loadNotes(from: userDefaults, key: notesKey)
    }

    func note(for quote: Quote) -> String? {
        notes[quote.id]
    }

    func setNote(_ text: String, for quote: Quote) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.removeValue(forKey: quote.id)
            saveNotes()
            return
        }
        let limited = String(trimmed.prefix(Self.maxNoteLength))
        notes[quote.id] = limited
        saveNotes()
    }

    private func saveNotes() {
        let codable = notes.reduce(into: [String: String]()) { dict, entry in
            dict[entry.key.uuidString] = entry.value
        }
        if let data = try? JSONEncoder().encode(codable),
           data.count <= Self.maxStoredDataSize {
            userDefaults.set(data, forKey: notesKey)
        }
    }

    private static func loadNotes(from userDefaults: UserDefaults, key: String) -> [UUID: String] {
        guard
            let data = userDefaults.data(forKey: key),
            data.count <= maxStoredDataSize,
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }

        var result: [UUID: String] = [:]
        for (rawID, note) in decoded {
            if let uuid = UUID(uuidString: rawID) {
                result[uuid] = note
            }
        }
        return result
    }
}

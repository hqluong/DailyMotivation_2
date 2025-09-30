// MARK: - Quote.swift

import Foundation

/// Represents a motivational quote with a unique identifier.
struct Quote: Codable, Identifiable, Hashable {
    var id: UUID
    let quote: String
    let author: String
    let category: String

    enum CodingKeys: String, CodingKey {
        case quote, author, category
    }

    /// Decodes a quote from JSON and assigns a new UUID.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.quote = try container.decode(String.self, forKey: .quote)
        self.author = try container.decode(String.self, forKey: .author)
        self.category = (try? container.decode(String.self, forKey: .category)) ?? "General"
        self.id = UUID()
    }

    /// Manual initializer for creating quotes in code or tests.
    init(id: UUID = UUID(), quote: String, author: String, category: String = "General") {
        self.id = id
        self.quote = quote
        self.author = author
        self.category = category
    }
}

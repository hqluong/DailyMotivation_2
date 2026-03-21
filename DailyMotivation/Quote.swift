// MARK: - Quote.swift

import Foundation

/// Represents a motivational quote with a unique identifier.
struct Quote: Codable, Identifiable, Hashable {
    var id: UUID
    let quote: String
    let author: String
    let category: String

    enum CodingKeys: String, CodingKey {
        case id, quote, author, category
    }

    /// Decodes a quote from JSON, preserving an explicit ID when available.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.quote = try container.decode(String.self, forKey: .quote)
        self.author = try container.decode(String.self, forKey: .author)
        self.category = (try? container.decode(String.self, forKey: .category)) ?? "General"
        if let decodedID = try? container.decode(UUID.self, forKey: .id) {
            self.id = decodedID
        } else if
            let decodedIDString = try? container.decode(String.self, forKey: .id),
            let decodedID = UUID(uuidString: decodedIDString)
        {
            self.id = decodedID
        } else {
            self.id = Self.stableID(quote: quote, author: author, category: category)
        }
    }

    /// Manual initializer for creating quotes in code or tests.
    init(id: UUID? = nil, quote: String, author: String, category: String = "General") {
        self.id = id ?? Self.stableID(quote: quote, author: author, category: category)
        self.quote = quote
        self.author = author
        self.category = category
    }

    private static func stableID(quote: String, author: String, category: String) -> UUID {
        let normalized = [quote, author, category]
            .map { $0.precomposedStringWithCanonicalMapping }
            .joined(separator: "\u{1F}")

        let bytes = Array(normalized.utf8)
        let upper = fnv1a64(bytes, seed: 0xcbf29ce484222325)
        let lower = fnv1a64(bytes, seed: 0x9e3779b97f4a7c15)
        let upperBytes = withUnsafeBytes(of: upper.bigEndian, Array.init)
        let lowerBytes = withUnsafeBytes(of: lower.bigEndian, Array.init)
        var uuidBytes = upperBytes + lowerBytes

        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }

    private static func fnv1a64(_ bytes: [UInt8], seed: UInt64) -> UInt64 {
        let prime: UInt64 = 1_099_511_628_211
        return bytes.reduce(seed) { partial, byte in
            (partial ^ UInt64(byte)) &* prime
        }
    }
}

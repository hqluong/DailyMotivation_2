import Foundation
import Testing

struct QuoteContentValidationTests {

    @Test
    func bundledQuotes_passContentValidation() throws {
        let repositoryRoot = repositoryRootURL()
        let data = try Data(contentsOf: repositoryRoot.appending(path: "DailyMotivation/quotes.json"))
        let result = QuoteContentValidator.validate(data: data)

        #expect(
            result.issues.isEmpty,
            "Quote validation issues:\n\(result.issues.map(\.description).joined(separator: "\n"))"
        )
    }

    @Test
    func validator_rejectsMissingCategoryAndDuplicateCollisions() throws {
        let invalidPayload = """
        [
          {
            "quote": "A focused mind is a powerful one.",
            "author": "Unknown"
          },
          {
            "quote": "Repeatable effort wins.",
            "author": "Unknown",
            "category": "Success"
          },
          {
            "quote": "Repeatable effort wins.",
            "author": "Unknown",
            "category": "Resilience"
          }
        ]
        """

        let result = QuoteContentValidator.validate(data: Data(invalidPayload.utf8))
        let messages = result.issues.map(\.description).joined(separator: "\n")

        #expect(!result.issues.isEmpty)
        #expect(messages.contains("missing required field 'category'"))
        #expect(messages.contains("duplicate quote+author collision"))
    }

    private func repositoryRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct QuoteContentValidationIssue: CustomStringConvertible {
    let recordIndex: Int?
    let message: String

    var description: String {
        if let recordIndex {
            return "Record \(recordIndex): \(message)"
        }
        return message
    }
}

private struct QuoteContentValidationResult {
    let issues: [QuoteContentValidationIssue]
    let categoryCounts: [String: Int]
    let recordCount: Int
}

private enum QuoteContentValidator {
    static let allowedCategories: [String] = [
        "Creativity",
        "Focus",
        "General",
        "Gratitude",
        "Happiness",
        "Mindfulness",
        "Motivation",
        "Resilience",
        "Success"
    ]

    private static let allowedCategorySet = Set(allowedCategories)
    private static let quoteLengthRange = 12...280
    private static let authorLengthRange = 2...80

    static func validate(data: Data) -> QuoteContentValidationResult {
        var issues: [QuoteContentValidationIssue] = []
        var categoryCounts: [String: Int] = [:]
        var duplicateMap: [String: Int] = [:]
        var ids: [String: Int] = [:]

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            return QuoteContentValidationResult(
                issues: [QuoteContentValidationIssue(recordIndex: nil, message: "Invalid JSON: \(error.localizedDescription)")],
                categoryCounts: [:],
                recordCount: 0
            )
        }

        guard let records = jsonObject as? [[String: Any]] else {
            return QuoteContentValidationResult(
                issues: [QuoteContentValidationIssue(recordIndex: nil, message: "Top-level payload must be an array of quote objects.")],
                categoryCounts: [:],
                recordCount: 0
            )
        }

        for (offset, record) in records.enumerated() {
            let recordIndex = offset + 1
            let quote = validatedString(
                field: "quote",
                in: record,
                recordIndex: recordIndex,
                lengthRange: quoteLengthRange,
                issues: &issues
            )
            let author = validatedString(
                field: "author",
                in: record,
                recordIndex: recordIndex,
                lengthRange: authorLengthRange,
                issues: &issues
            )
            let category = validatedString(
                field: "category",
                in: record,
                recordIndex: recordIndex,
                lengthRange: nil,
                issues: &issues
            )

            if let category {
                if !allowedCategorySet.contains(category) {
                    issues.append(
                        QuoteContentValidationIssue(
                            recordIndex: recordIndex,
                            message: "category '\(category)' is not in the allowlist: \(allowedCategories.joined(separator: ", "))"
                        )
                    )
                } else {
                    categoryCounts[category, default: 0] += 1
                }
            }

            if let rawID = record["id"] {
                guard let idString = rawID as? String else {
                    issues.append(
                        QuoteContentValidationIssue(recordIndex: recordIndex, message: "id must be a UUID string when present.")
                    )
                    continue
                }

                guard UUID(uuidString: idString) != nil else {
                    issues.append(
                        QuoteContentValidationIssue(recordIndex: recordIndex, message: "id '\(idString)' is not a valid UUID.")
                    )
                    continue
                }

                if let firstSeen = ids.updateValue(recordIndex, forKey: idString) {
                    issues.append(
                        QuoteContentValidationIssue(
                            recordIndex: recordIndex,
                            message: "duplicate id collision with record \(firstSeen)."
                        )
                    )
                }
            }

            if let quote, let author {
                let duplicateKey = normalized(quote) + "|" + normalized(author)
                if let firstSeen = duplicateMap.updateValue(recordIndex, forKey: duplicateKey) {
                    issues.append(
                        QuoteContentValidationIssue(
                            recordIndex: recordIndex,
                            message: "duplicate quote+author collision with record \(firstSeen)."
                        )
                    )
                }
            }
        }

        return QuoteContentValidationResult(
            issues: issues,
            categoryCounts: categoryCounts,
            recordCount: records.count
        )
    }

    private static func validatedString(
        field: String,
        in record: [String: Any],
        recordIndex: Int,
        lengthRange: ClosedRange<Int>?,
        issues: inout [QuoteContentValidationIssue]
    ) -> String? {
        guard let rawValue = record[field] else {
            issues.append(
                QuoteContentValidationIssue(recordIndex: recordIndex, message: "missing required field '\(field)'.")
            )
            return nil
        }

        guard let stringValue = rawValue as? String else {
            issues.append(
                QuoteContentValidationIssue(recordIndex: recordIndex, message: "field '\(field)' must be a string.")
            )
            return nil
        }

        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            issues.append(
                QuoteContentValidationIssue(recordIndex: recordIndex, message: "field '\(field)' must not be empty.")
            )
            return nil
        }

        if trimmed != stringValue {
            issues.append(
                QuoteContentValidationIssue(
                    recordIndex: recordIndex,
                    message: "field '\(field)' must not contain leading or trailing whitespace."
                )
            )
        }

        if let lengthRange, !lengthRange.contains(trimmed.count) {
            issues.append(
                QuoteContentValidationIssue(
                    recordIndex: recordIndex,
                    message: "field '\(field)' length \(trimmed.count) is outside the expected range \(lengthRange.lowerBound)...\(lengthRange.upperBound)."
                )
            )
        }

        return trimmed
    }

    private static func normalized(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

#!/usr/bin/env swift

import Foundation

// Run from the repository root:
//   swift tools/validate_quotes.swift
// Or point at a different file:
//   swift tools/validate_quotes.swift /path/to/quotes.json

struct ValidationIssue: CustomStringConvertible {
    let recordIndex: Int?
    let message: String

    var description: String {
        if let recordIndex {
            return "Record \(recordIndex): \(message)"
        }
        return message
    }
}

enum QuotePayloadValidator {
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

    static func validate(data: Data) -> (issues: [ValidationIssue], categoryCounts: [String: Int], recordCount: Int) {
        var issues: [ValidationIssue] = []
        var categoryCounts: [String: Int] = [:]
        var duplicateMap: [String: Int] = [:]
        var ids: [String: Int] = [:]

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            return (
                [ValidationIssue(recordIndex: nil, message: "Invalid JSON: \(error.localizedDescription)")],
                [:],
                0
            )
        }

        guard let records = jsonObject as? [[String: Any]] else {
            return (
                [ValidationIssue(recordIndex: nil, message: "Top-level payload must be an array of quote objects.")],
                [:],
                0
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
                        ValidationIssue(
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
                        ValidationIssue(recordIndex: recordIndex, message: "id must be a UUID string when present.")
                    )
                    continue
                }

                guard UUID(uuidString: idString) != nil else {
                    issues.append(
                        ValidationIssue(recordIndex: recordIndex, message: "id '\(idString)' is not a valid UUID.")
                    )
                    continue
                }

                if let firstSeen = ids.updateValue(recordIndex, forKey: idString) {
                    issues.append(
                        ValidationIssue(
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
                        ValidationIssue(
                            recordIndex: recordIndex,
                            message: "duplicate quote+author collision with record \(firstSeen)."
                        )
                    )
                }
            }
        }

        return (issues, categoryCounts, records.count)
    }

    private static func validatedString(
        field: String,
        in record: [String: Any],
        recordIndex: Int,
        lengthRange: ClosedRange<Int>?,
        issues: inout [ValidationIssue]
    ) -> String? {
        guard let rawValue = record[field] else {
            issues.append(
                ValidationIssue(recordIndex: recordIndex, message: "missing required field '\(field)'.")
            )
            return nil
        }

        guard let stringValue = rawValue as? String else {
            issues.append(
                ValidationIssue(recordIndex: recordIndex, message: "field '\(field)' must be a string.")
            )
            return nil
        }

        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            issues.append(
                ValidationIssue(recordIndex: recordIndex, message: "field '\(field)' must not be empty.")
            )
            return nil
        }

        if trimmed != stringValue {
            issues.append(
                ValidationIssue(
                    recordIndex: recordIndex,
                    message: "field '\(field)' must not contain leading or trailing whitespace."
                )
            )
        }

        if let lengthRange, !lengthRange.contains(trimmed.count) {
            issues.append(
                ValidationIssue(
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

let arguments = CommandLine.arguments
let quotesPath = arguments.dropFirst().first ?? "DailyMotivation/quotes.json"
let quotesURL = URL(fileURLWithPath: quotesPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

do {
    let data = try Data(contentsOf: quotesURL)
    let result = QuotePayloadValidator.validate(data: data)

    if result.issues.isEmpty {
        print("Validated \(result.recordCount) quotes in \(quotesPath).")
        for category in QuotePayloadValidator.allowedCategories where result.categoryCounts[category] != nil {
            print("  \(category): \(result.categoryCounts[category] ?? 0)")
        }
        exit(EXIT_SUCCESS)
    }

    fputs("Quote validation failed for \(quotesPath):\n", stderr)
    for issue in result.issues {
        fputs("  - \(issue)\n", stderr)
    }
    exit(EXIT_FAILURE)
} catch {
    fputs("Unable to read \(quotesPath): \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}

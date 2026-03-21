import Foundation
import Testing

struct QuoteContentValidationTests {

    @Test
    func bundledQuotes_passContentValidationScript() throws {
        let repositoryRoot = repositoryRootURL()
        let result = try runValidator(
            scriptURL: repositoryRoot.appending(path: "tools/validate_quotes.swift"),
            jsonURL: repositoryRoot.appending(path: "DailyMotivation/quotes.json"),
            repositoryRoot: repositoryRoot
        )

        #expect(
            result.terminationStatus == 0,
            "Validator stderr:\n\(result.standardError)\nValidator stdout:\n\(result.standardOutput)"
        )
    }

    @Test
    func validator_rejectsMissingCategoryAndDuplicateCollisions() throws {
        let repositoryRoot = repositoryRootURL()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyMotivationQuoteValidation-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

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

        let invalidJSONURL = temporaryDirectory.appending(path: "invalid_quotes.json")
        try Data(invalidPayload.utf8).write(to: invalidJSONURL)

        let result = try runValidator(
            scriptURL: repositoryRoot.appending(path: "tools/validate_quotes.swift"),
            jsonURL: invalidJSONURL,
            repositoryRoot: repositoryRoot
        )

        #expect(result.terminationStatus != 0)
        #expect(result.standardError.contains("missing required field 'category'"))
        #expect(result.standardError.contains("duplicate quote+author collision"))
    }

    private func repositoryRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func runValidator(scriptURL: URL, jsonURL: URL, repositoryRoot: URL) throws -> CommandResult {
        let moduleCacheURL = FileManager.default.temporaryDirectory
            .appending(path: "DailyMotivationSwiftModuleCache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: moduleCacheURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swift", scriptURL.path, jsonURL.path]
        process.currentDirectoryURL = repositoryRoot
        var environment = ProcessInfo.processInfo.environment
        environment["SWIFT_MODULECACHE_PATH"] = moduleCacheURL.path
        environment["CLANG_MODULE_CACHE_PATH"] = moduleCacheURL.path
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let standardOutput = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let standardError = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }
}

private struct CommandResult {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

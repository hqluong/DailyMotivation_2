import Foundation
import Testing
@testable import DailyMotivation
#if canImport(DailyMotivationWidgetExtension)
@testable import DailyMotivationWidgetExtension
#endif

/// Unit tests for the DailyMotivation app.
struct DailyMotivationTests {

    @Test
    func quoteID_isDeterministicAcrossRepeatedDecodes() throws {
        let payload = """
        [
          {
            "quote": "Stay curious.",
            "author": "Ada Lovelace",
            "category": "Growth"
          }
        ]
        """

        let firstDecode = try JSONDecoder().decode([Quote].self, from: Data(payload.utf8))
        let secondDecode = try JSONDecoder().decode([Quote].self, from: Data(payload.utf8))

        #expect(firstDecode.count == 1)
        #expect(secondDecode.count == 1)
        #expect(firstDecode[0].id == secondDecode[0].id)
        #expect(firstDecode[0].id == Quote(
            quote: "Stay curious.",
            author: "Ada Lovelace",
            category: "Growth"
        ).id)
    }

    @Test
    func quoteID_defaultsMissingCategoryToGeneralConsistently() throws {
        let payload = """
        [
          {
            "quote": "Consistency compounds.",
            "author": "James Clear"
          }
        ]
        """

        let decoded = try JSONDecoder().decode([Quote].self, from: Data(payload.utf8))
        let expected = Quote(
            quote: "Consistency compounds.",
            author: "James Clear",
            category: "General"
        )

        #expect(decoded.count == 1)
        #expect(decoded[0].category == "General")
        #expect(decoded[0].id == expected.id)
    }

    @Test
    func quoteID_preservesExplicitStoredID() throws {
        let explicitID = UUID()
        let payload = """
        [
          {
            "id": "\(explicitID.uuidString)",
            "quote": "Keep going.",
            "author": "Unknown",
            "category": "Motivation"
          }
        ]
        """

        let decoded = try JSONDecoder().decode([Quote].self, from: Data(payload.utf8))

        #expect(decoded.count == 1)
        #expect(decoded[0].id == explicitID)
    }

    @Test
    func dailyQuoteSelection_matchesTodayIndexingContract() {
        let quotes = [
            Quote(quote: "Quote 0", author: "Author 0", category: "A"),
            Quote(quote: "Quote 1", author: "Author 1", category: "B"),
            Quote(quote: "Quote 2", author: "Author 2", category: "C"),
            Quote(quote: "Quote 3", author: "Author 3", category: "D"),
            Quote(quote: "Quote 4", author: "Author 4", category: "E")
        ]
        let viewModel = makeViewModel()
        let today = Date()
        let expectedIndex = todayIndex(for: today, count: quotes.count, calendar: .current)

        viewModel.allQuotes = quotes
        viewModel.setCurrentQuoteToDaily()

        #expect(viewModel.getDailyQuote()?.id == quotes[expectedIndex].id)
        #expect(viewModel.currentQuote?.id == quotes[expectedIndex].id)
    }

    #if canImport(DailyMotivationWidgetExtension)
    @Test
    func dailyQuoteSelection_matchesWidgetForToday() {
        let viewModel = makeViewModel()
        let today = Date()

        #expect(!viewModel.allQuotes.isEmpty)

        viewModel.setCurrentQuoteToDaily()

        let appQuote = viewModel.getDailyQuote()
        let widgetQuote = QuoteWidgetDataSource.shared.quote(for: today)

        #expect(appQuote?.quote == widgetQuote.text)
        #expect(appQuote?.author == widgetQuote.author)
    }
    #endif

    private func makeViewModel() -> QuoteViewModel {
        let suiteName = "DailyMotivationTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let favoritesManager = FavoritesManager(userDefaults: userDefaults)
        let engagementTracker = EngagementTracker(userDefaults: userDefaults)
        return QuoteViewModel(
            favoritesManager: favoritesManager,
            engagementTracker: engagementTracker,
            userDefaults: userDefaults
        )
    }

    private func todayIndex(for date: Date, count: Int, calendar: Calendar) -> Int {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return (dayOfYear - 1) % count
    }
}

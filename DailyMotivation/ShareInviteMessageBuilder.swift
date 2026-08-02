import Foundation

enum ShareInviteMessageBuilder {
    static let shareCTA = "A quote from Daily Motivation:"
    static let downloadCTA = "https://apps.apple.com/app/id6756123822"

    static func message(for quote: Quote, currentStreak: Int) -> String {
        let normalizedStreak = max(0, currentStreak)
        let streakLine: String
        if normalizedStreak > 0 {
            streakLine = "I'm on a \(normalizedStreak)-day streak in Daily Motivation."
        } else {
            streakLine = "I found this quote in Daily Motivation."
        }

        return """
        \(shareCTA)
        \(streakLine)
        "\(quote.quote)"
        - \(quote.author)

        \(downloadCTA)
        """
    }
}

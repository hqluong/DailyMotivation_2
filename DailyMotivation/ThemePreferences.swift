//
//  ThemePreferences.swift
//  DailyMotivation
//
//  Created by Codex on 4/27/25.
//

import SwiftUI

/// Represents the available color palettes that can be applied to the quote card and UI accents.
enum ThemeColorPack: String, CaseIterable, Identifiable {
    case classic
    case sunrise
    case ocean
    case forest
    case dusk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .sunrise: return "Sunrise"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .dusk: return "Dusk"
        }
    }

    /// Gradient colors used for the card background and accent elements.
    var gradientColors: [Color] {
        switch self {
        case .classic:
            return [Color.blue.opacity(0.9), Color.purple.opacity(0.85)]
        case .sunrise:
            return [Color(red: 0.99, green: 0.68, blue: 0.35), Color(red: 0.85, green: 0.27, blue: 0.45)]
        case .ocean:
            return [Color(red: 0.0, green: 0.62, blue: 0.86), Color(red: 0.0, green: 0.36, blue: 0.58)]
        case .forest:
            return [Color(red: 0.38, green: 0.68, blue: 0.42), Color(red: 0.13, green: 0.42, blue: 0.35)]
        case .dusk:
            return [Color(red: 0.45, green: 0.33, blue: 0.71), Color(red: 0.17, green: 0.18, blue: 0.35)]
        }
    }

    /// Primary accent color derived from the gradient.
    var accentColor: Color {
        gradientColors.last ?? .white
    }

    /// Secondary accent color used for subtle highlights.
    var secondaryAccent: Color {
        gradientColors.first ?? .white
    }

    /// Background style for the quote card.
    var cardBackground: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Represents the typography choices available to the user.
enum QuoteFontStyle: String, CaseIterable, Identifiable {
    case rounded
    case serif
    case minimalist
    case playful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .minimalist: return "Minimalist"
        case .playful: return "Playful"
        }
    }

    func quoteFont(size: CGFloat) -> Font {
        switch self {
        case .rounded:
            return .system(size: size, weight: .bold, design: .rounded)
        case .serif:
            return .system(size: size, weight: .semibold, design: .serif)
        case .minimalist:
            return .system(size: size, weight: .medium, design: .default)
        case .playful:
            return .system(size: size, weight: .semibold, design: .rounded)
        }
    }

    func authorFont(size: CGFloat) -> Font {
        switch self {
        case .rounded:
            return .system(size: size, weight: .semibold, design: .rounded)
        case .serif:
            return .system(size: size, weight: .regular, design: .serif)
        case .minimalist:
            return .system(size: size, weight: .medium, design: .default)
        case .playful:
            return .system(size: size, weight: .medium, design: .rounded)
        }
    }
}

/// Represents the large-format background the quote card sits on (gradient or stylised imagery).
enum QuoteBackgroundStyle: String, CaseIterable, Identifiable {
    case classic
    case sunrise
    case aurora
    case midnight
    case ocean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic Gradient"
        case .sunrise: return "Golden Sunrise"
        case .aurora: return "Aurora"
        case .midnight: return "Midnight"
        case .ocean: return "Tropical Ocean"
        }
    }

    var iconName: String {
        switch self {
        case .classic: return "paintpalette.fill"
        case .sunrise: return "sunrise.fill"
        case .aurora: return "sparkles"
        case .midnight: return "moon.stars.fill"
        case .ocean: return "wave.3.forward"
        }
    }
}

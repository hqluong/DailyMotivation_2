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
    case winterCabin
    case forestStream
    case oceanCliff
    case rainyWindow
    case autumnCabin
    case springCabin
    case cozyWindow
    case snowyRetreat
    case mountainTrail
    case sereneBedroom
    case hiddenWaterfall
    case cozySpices
    case tropicalLagoon
    case readingNook
    case sunlitVineyard
    case cherryBlossoms
    case starlitShore
    case alpineRiver
    case goldenWillow
    case coastalHeadland
    case cabinMug

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic Gradient"
        case .sunrise: return "Golden Sunrise"
        case .aurora: return "Aurora"
        case .midnight: return "Midnight"
        case .ocean: return "Tropical Ocean"
        case .winterCabin: return "Winter Cabin"
        case .forestStream: return "Forest Stream"
        case .oceanCliff: return "Ocean Cliff"
        case .rainyWindow: return "Rainy Window"
        case .autumnCabin: return "Autumn Cabin"
        case .springCabin: return "Spring Cabin"
        case .cozyWindow: return "Cozy Window"
        case .snowyRetreat: return "Snowy Retreat"
        case .mountainTrail: return "Mountain Trail"
        case .sereneBedroom: return "Serene Bedroom"
        case .hiddenWaterfall: return "Hidden Waterfall"
        case .cozySpices: return "Cozy Spices"
        case .tropicalLagoon: return "Tropical Lagoon"
        case .readingNook: return "Reading Nook"
        case .sunlitVineyard: return "Sunlit Vineyard"
        case .cherryBlossoms: return "Cherry Blossoms"
        case .starlitShore: return "Starlit Shore"
        case .alpineRiver: return "Alpine River"
        case .goldenWillow: return "Golden Willow"
        case .coastalHeadland: return "Coastal Headland"
        case .cabinMug: return "Cabin Coffee"
        }
    }

    var iconName: String {
        switch self {
        case .classic: return "paintpalette.fill"
        case .sunrise: return "sunrise.fill"
        case .aurora: return "sparkles"
        case .midnight: return "moon.stars.fill"
        case .ocean: return "wave.3.forward"
        case .winterCabin: return "house.fill"
        case .forestStream: return "leaf.fill"
        case .oceanCliff: return "water.waves"
        case .rainyWindow: return "cloud.rain.fill"
        case .autumnCabin: return "house.lodge.fill"
        case .springCabin: return "sun.max.fill"
        case .cozyWindow: return "cup.and.saucer.fill"
        case .snowyRetreat: return "snowflake"
        case .mountainTrail: return "figure.walk"
        case .sereneBedroom: return "bed.double.fill"
        case .hiddenWaterfall: return "drop.fill"
        case .cozySpices: return "flame.fill"
        case .tropicalLagoon: return "sun.max"
        case .readingNook: return "book.fill"
        case .sunlitVineyard: return "sun.max.circle"
        case .cherryBlossoms: return "leaf.circle"
        case .starlitShore: return "sparkles"
        case .alpineRiver: return "snowflake"
        case .goldenWillow: return "tree"
        case .coastalHeadland: return "water.waves"
        case .cabinMug: return "cup.and.saucer"
        }
    }

    var isPhotoBackground: Bool {
        switch self {
        case .winterCabin,
             .forestStream,
             .oceanCliff,
             .rainyWindow,
             .autumnCabin,
             .springCabin,
             .cozyWindow,
             .snowyRetreat,
             .mountainTrail,
             .sereneBedroom,
             .hiddenWaterfall,
             .cozySpices,
             .tropicalLagoon,
             .readingNook,
             .sunlitVineyard,
             .cherryBlossoms,
             .starlitShore,
             .alpineRiver,
             .goldenWillow,
             .coastalHeadland,
             .cabinMug:
            return true
        default:
            return false
        }
    }

    var navigationBarColorScheme: ColorScheme { .dark }

    var navigationBarBackgroundOpacity: Double {
        switch self {
        case .winterCabin,
             .forestStream,
             .oceanCliff,
             .rainyWindow,
             .autumnCabin,
             .springCabin,
             .cozyWindow,
             .snowyRetreat,
             .mountainTrail,
             .sereneBedroom,
             .hiddenWaterfall,
             .cozySpices,
             .tropicalLagoon,
             .readingNook,
             .sunlitVineyard,
             .cherryBlossoms,
             .starlitShore,
             .alpineRiver,
             .goldenWillow,
             .coastalHeadland,
             .cabinMug:
            return 0.35
        case .midnight:
            return 0.28
        case .classic, .aurora, .ocean:
            return 0.22
        case .sunrise:
            return 0.18
        }
    }
}

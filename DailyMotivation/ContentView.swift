// MARK: - ContentView.swift

import SwiftUI
import UserNotifications // <-- Import UserNotifications

struct ContentView: View {
    // Environment
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // StateObjects for ViewModel and FavoritesManager
    @StateObject private var favoritesManager: FavoritesManager
    @StateObject private var engagementTracker: EngagementTracker
    @StateObject private var viewModel: QuoteViewModel

    // State for navigation, sheets, notification time, and category selection
    @State private var showingFavorites = false
    @State private var isSharePresented = false
    @State private var showingSettings = false
    @State private var showStreakPopup = false
    @State private var hasPresentedStreakPopup = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour: Int = 9
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute: Int = 0
    @AppStorage("selectedQuoteCategory") private var selectedCategory: String = "All"
    @AppStorage("selectedThemeColorPack") private var selectedColorPackRawValue: String = ThemeColorPack.classic.rawValue
    @AppStorage("selectedFontStyle") private var selectedFontStyleRawValue: String = QuoteFontStyle.rounded.rawValue
    @AppStorage("selectedBackgroundStyle") private var selectedBackgroundStyleRawValue: String = QuoteBackgroundStyle.classic.rawValue

    // Example categories - update as needed
    private let categories: [String] = ["All", "Success", "Creativity", "Mindfulness", "Motivation", "Happiness"]

    // Constants for font scaling (adjust these as needed based on testing)
    private let minQuoteFontSize: CGFloat = 18
    private let maxQuoteFontSize: CGFloat = 44
    // Adjust this factor based on testing across screen sizes
    private let fontHeightScaleFactor: CGFloat = 0.09
    private let streakPopupDisplayDuration: TimeInterval = 4.0

    // Initializer to inject dependencies, enabling previews and tests to supply isolated stores.
    init(
        favoritesManager: FavoritesManager = FavoritesManager(),
        engagementTracker: EngagementTracker = EngagementTracker()
    ) {
        let favManager = favoritesManager
        let tracker = engagementTracker
        _favoritesManager = StateObject(wrappedValue: favManager)
        _engagementTracker = StateObject(wrappedValue: tracker)
        _viewModel = StateObject(wrappedValue: QuoteViewModel(favoritesManager: favManager, engagementTracker: tracker))
    }

    var body: some View {
        let colorPack = ThemeColorPack(rawValue: selectedColorPackRawValue) ?? .classic
        let fontStyle = QuoteFontStyle(rawValue: selectedFontStyleRawValue) ?? .rounded
        let backgroundStyle = QuoteBackgroundStyle(rawValue: selectedBackgroundStyleRawValue) ?? .classic
        let isPhotoBackground = backgroundStyle.isPhotoBackground
        let navigationBarColorScheme = backgroundStyle.navigationBarColorScheme

        return NavigationStack {
            ZStack {
                QuoteBackgroundView(style: backgroundStyle, colorPack: colorPack)
                    .edgesIgnoringSafeArea(.all)

                // Use GeometryReader for responsive sizing
                GeometryReader { geometry in
                    QuoteLayoutView(
                        size: geometry.size,
                        safeAreaInsets: geometry.safeAreaInsets,
                        verticalSizeClass: verticalSizeClass,
                        categories: categories,
                        selectedCategory: $selectedCategory,
                        showStreakPopup: $showStreakPopup,
                        isSharePresented: $isSharePresented,
                        viewModel: viewModel,
                        favoritesManager: favoritesManager,
                        fontStyle: fontStyle,
                        colorPack: colorPack,
                        isPhotoBackground: isPhotoBackground,
                        minQuoteFontSize: minQuoteFontSize,
                        maxQuoteFontSize: maxQuoteFontSize,
                        fontHeightScaleFactor: fontHeightScaleFactor
                    )
                } // End GeometryReader

            } // End ZStack
            .navigationTitle("Daily Motivation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                     Button {
                         showingFavorites = true
                     } label: {
                         Image(systemName: "list.star")
                             .accessibilityLabel("Show favorite quotes")
                     }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .navigationDestination(isPresented: $showingFavorites) {
                // Ensure viewModel and favoritesManager are passed correctly
                FavoritesView(viewModel: viewModel, favoritesManager: favoritesManager)
            }
            .toolbarColorScheme(navigationBarColorScheme, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .sheet(isPresented: $isSharePresented) {
                // Use ActivityView defined below
                if let currentQuote = viewModel.currentQuote {
                    ActivityView(activityItems: ["\"\(currentQuote.quote)\" - \(currentQuote.author)"])
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    dailyReminderHour: $dailyReminderHour,
                    dailyReminderMinute: $dailyReminderMinute,
                    selectedThemeColorPack: $selectedColorPackRawValue,
                    selectedFontStyle: $selectedFontStyleRawValue,
                    selectedBackgroundStyle: $selectedBackgroundStyleRawValue
                )
            }
            .overlay(alignment: .top) {
                if showStreakPopup {
                    StreakHeaderView(summary: engagementTracker.summary, colorPack: colorPack) {
                        if let dailyQuote = viewModel.getDailyQuote() {
                            NotificationManager.shared.scheduleDailyQuoteNotification(
                                quote: dailyQuote,
                                hour: dailyReminderHour,
                                minute: dailyReminderMinute
                            )
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showStreakPopup = false
                        }
                        showingSettings = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .shadow(radius: 18)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showStreakPopup = false
                        }
                    }
                    .zIndex(1000)
                }
            }
            // --- MODIFIED .onAppear ---
            .onAppear {
                // Initial quote load if needed
                if viewModel.currentQuote == nil && viewModel.errorMessage == nil {
                    viewModel.setCurrentQuoteToDaily()
                }

                if !hasPresentedStreakPopup {
                    hasPresentedStreakPopup = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.4)) {
                        showStreakPopup = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + streakPopupDisplayDuration) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showStreakPopup = false
                        }
                    }
                }

                // Record that the user viewed today's quote for streak tracking
                viewModel.recordDailyQuoteView()

                // --- Request and Schedule Notifications ---
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    switch settings.authorizationStatus {
                    case .notDetermined:
                        NotificationManager.shared.requestAuthorization { granted in
                            if granted {
                                if let dailyQuote = viewModel.getDailyQuote() {
                                    NotificationManager.shared.scheduleDailyQuoteNotification(
                                        quote: dailyQuote,
                                        hour: dailyReminderHour,
                                        minute: dailyReminderMinute
                                    )
                                }
                            }
                        }
                    case .authorized:
                        if let dailyQuote = viewModel.getDailyQuote() {
                            NotificationManager.shared.scheduleDailyQuoteNotification(
                                quote: dailyQuote,
                                hour: dailyReminderHour,
                                minute: dailyReminderMinute
                            )
                        }
                    case .denied, .provisional, .ephemeral:
                        print("Notification permission not granted or restricted.")
                        break
                    @unknown default:
                        break
                    }
                }
            }
        } // End NavigationStack
    } // End body
} // End ContentView struct

// MARK: - Layout Extraction
private struct QuoteLayoutView: View {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let verticalSizeClass: UserInterfaceSizeClass?
    let categories: [String]
    @Binding var selectedCategory: String
    @Binding var showStreakPopup: Bool
    @Binding var isSharePresented: Bool
    @ObservedObject var viewModel: QuoteViewModel
    let favoritesManager: FavoritesManager
    let fontStyle: QuoteFontStyle
    let colorPack: ThemeColorPack
    let isPhotoBackground: Bool
    let minQuoteFontSize: CGFloat
    let maxQuoteFontSize: CGFloat
    let fontHeightScaleFactor: CGFloat

    var body: some View {
        let isCompactHeight = (verticalSizeClass == .compact) || size.width > size.height
        let containerSpacing: CGFloat = isCompactHeight ? 12 : 20
        let safeTopInset = isCompactHeight ? safeAreaInsets.top : 0
        let baseTopPadding: CGFloat = isCompactHeight ? max(140, size.height * 0.26) : 12
        let effectiveTopPadding = baseTopPadding + safeTopInset
        let bottomPadding: CGFloat = safeAreaInsets.bottom + (isCompactHeight ? 18 : 20)
        let quoteHeightFactor: CGFloat = isCompactHeight ? 0.54 : 0.75
        let quoteAreaMaxHeight = size.height * quoteHeightFactor
        let cardMinHeightMultiplier: CGFloat = isCompactHeight ? 0.66 : 0.9
        let adjustedFontScale = fontHeightScaleFactor * (isCompactHeight ? 0.85 : 1.0)
        let calculatedQuoteFontSize = max(minQuoteFontSize, min(quoteAreaMaxHeight * adjustedFontScale, maxQuoteFontSize))
        let calculatedAuthorFontSize = max(minQuoteFontSize * 0.6, min(calculatedQuoteFontSize * 0.5, maxQuoteFontSize * 0.6))
        let horizontalPadding: CGFloat = isCompactHeight ? 12 : 16
        let filteredQuotes: [Quote] = selectedCategory == "All"
            ? viewModel.allQuotes
            : viewModel.allQuotes.filter { $0.category == selectedCategory }
        let currentQuote = filteredQuotes.first(where: { $0.id == viewModel.currentQuote?.id }) ?? filteredQuotes.first

        Group {
            let layout = contentLayout(
                filteredQuotes: filteredQuotes,
                currentQuote: currentQuote,
                isCompactHeight: isCompactHeight,
                containerSpacing: containerSpacing,
                topPadding: effectiveTopPadding,
                bottomPadding: bottomPadding,
                horizontalPadding: horizontalPadding,
                quoteAreaMaxHeight: quoteAreaMaxHeight,
                cardMinHeightMultiplier: cardMinHeightMultiplier,
                calculatedQuoteFontSize: calculatedQuoteFontSize,
                calculatedAuthorFontSize: calculatedAuthorFontSize
            )

            if isCompactHeight {
                ScrollView(.vertical, showsIndicators: false) {
                    layout
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                layout
                    .frame(width: size.width, height: size.height, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func contentLayout(
        filteredQuotes: [Quote],
        currentQuote: Quote?,
        isCompactHeight: Bool,
        containerSpacing: CGFloat,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        horizontalPadding: CGFloat,
        quoteAreaMaxHeight: CGFloat,
        cardMinHeightMultiplier: CGFloat,
        calculatedQuoteFontSize: CGFloat,
        calculatedAuthorFontSize: CGFloat
    ) -> some View {
        let categoryFilter = selectedCategory == "All" ? nil : selectedCategory

        VStack(spacing: containerSpacing) {
            ZStack(alignment: .top) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, horizontalPadding)
                .opacity(showStreakPopup ? 0 : 1)
                .allowsHitTesting(!showStreakPopup)
                .accessibilityHidden(showStreakPopup)
            }
            .animation(.easeInOut(duration: 0.3), value: showStreakPopup)
            .frame(maxWidth: .infinity, alignment: .top)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .frame(maxHeight: size.height * 0.1)
                    .padding(.horizontal, horizontalPadding)
            }

            if let currentQuote {
                VStack {
                    ScrollView {
                        VStack(spacing: 10) {
                            Spacer(minLength: 10)
                            Text("\"\(currentQuote.quote)\"")
                                .font(fontStyle.quoteFont(size: calculatedQuoteFontSize))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            Text("- \(currentQuote.author)")
                                .font(fontStyle.authorFont(size: calculatedAuthorFontSize))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.bottom, 5)
                            Spacer(minLength: 10)
                        }
                        .frame(minHeight: quoteAreaMaxHeight * cardMinHeightMultiplier)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorPack.cardBackground)
                        .opacity(isPhotoBackground ? 0.0 : 0.92)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(isPhotoBackground ? 0.0 : 0.16), lineWidth: isPhotoBackground ? 0 : 1)
                )
                .shadow(
                    color: isPhotoBackground ? Color.clear : colorPack.accentColor.opacity(0.35),
                    radius: isPhotoBackground ? 0 : 16,
                    x: 0,
                    y: isPhotoBackground ? 0 : 8
                )
                .frame(maxWidth: min(size.width * 0.92, isCompactHeight ? 540 : 640))
                .frame(maxHeight: quoteAreaMaxHeight)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    )
                )
                .animation(.easeInOut(duration: 0.5), value: currentQuote.id)
                .id(currentQuote.id)
                .onTapGesture {
                    viewModel.showNewRandomQuote(category: categoryFilter)
                }
                .padding(.horizontal, horizontalPadding)
            } else if viewModel.errorMessage == nil {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Loading Quote...")
                    .foregroundColor(.white)
                Spacer()
            }

            if let quoteForButtons = filteredQuotes.first(where: { $0.id == viewModel.currentQuote?.id }) ?? filteredQuotes.first {
                let isFavorite = favoritesManager.isFavorite(quote: quoteForButtons)

                HStack(spacing: 20) {
                    Button {
                        viewModel.toggleCurrentQuoteFavorite()
                    } label: {
                        Label("Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill((isFavorite ? Color.red : colorPack.accentColor)
                                        .opacity(isPhotoBackground ? 0.1 : (isFavorite ? 0.8 : 0.45)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(isPhotoBackground ? 0.0 : 0.18), lineWidth: isPhotoBackground ? 0 : 1)
                            )
                    }

                    Button {
                        isSharePresented = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .accessibilityLabel("Share this quote")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorPack.secondaryAccent.opacity(isPhotoBackground ? 0.1 : 0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(isPhotoBackground ? 0.0 : 0.18), lineWidth: isPhotoBackground ? 0 : 1)
                    )
                }
                .padding(.bottom, 10)
                .padding(.horizontal, horizontalPadding)
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}

// MARK: - Streak UI
struct StreakHeaderView: View {
    let summary: EngagementTracker.StreakSummary
    let colorPack: ThemeColorPack
    let onReminderAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(summary.currentStreak)-day streak", systemImage: summary.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.headline)
                    .foregroundStyle(Color.white, colorPack.secondaryAccent.opacity(0.8))
                Spacer()
                Text("Best \(summary.bestStreak)")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.85))
            }

            StreakHistoryRow(history: summary.recentHistory, colorPack: colorPack)

            if let lastViewed = summary.lastViewed {
                Text("Last read \(lastViewed, format: .relative(presentation: .numeric))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Read today's quote to start your streak!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            if summary.needsReminderNudge, summary.lastViewed != nil {
                Button(action: onReminderAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge.fill")
                        Text("Need an extra nudge? Tune your reminder")
                    }
                    .font(.caption.bold())
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(colorPack.secondaryAccent.opacity(0.35))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorPack.cardBackground)
                .opacity(0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: colorPack.accentColor.opacity(0.25), radius: 12, x: 0, y: 8)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You are on a \(summary.currentStreak) day streak. Best streak \(summary.bestStreak).")
    }
}

struct StreakHistoryRow: View {
    let history: [EngagementTracker.DailyEngagement]
    let colorPack: ThemeColorPack

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(history) { day in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(color(for: day))
                                .frame(width: 14, height: 14)

                            if day.favorited && day.viewed {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            }
                        }
                        Text(dayLabel(for: day.date))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(historyAccessibility(for: day))
                }
            }
        }
    }

    private func color(for day: EngagementTracker.DailyEngagement) -> Color {
        if day.viewed && day.favorited {
            return colorPack.accentColor
        } else if day.viewed {
            return colorPack.secondaryAccent.opacity(0.9)
        } else {
            return Color.white.opacity(0.25)
        }
    }

    private func dayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    private func historyAccessibility(for day: EngagementTracker.DailyEngagement) -> String {
        let weekday = StreakHistoryRow.accessibilityFormatter.string(from: day.date)
        switch (day.viewed, day.favorited) {
        case (true, true):
            return "\(weekday): viewed and favorited"
        case (true, false):
            return "\(weekday): viewed"
        case (false, true):
            return "\(weekday): favorited"
        default:
            return "\(weekday): no activity"
        }
    }

    private static let accessibilityFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()
}

// MARK: - Background Helpers
struct QuoteBackgroundView: View {
    let style: QuoteBackgroundStyle
    let colorPack: ThemeColorPack

    var body: some View {
        Group {
            switch style {
            case .classic:
                LinearGradient(
                    colors: [
                        colorPack.secondaryAccent.opacity(0.65),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sunrise:
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.75, blue: 0.45),
                            Color(red: 0.98, green: 0.47, blue: 0.45),
                            Color(red: 0.4, green: 0.22, blue: 0.43)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.35), Color.clear]),
                        center: .topTrailing,
                        startRadius: 40,
                        endRadius: 380
                    )
                    .blendMode(.screen)
                }
            case .aurora:
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.12, blue: 0.28),
                            Color(red: 0.03, green: 0.29, blue: 0.36),
                            Color(red: 0.18, green: 0.51, blue: 0.53)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [colorPack.accentColor.opacity(0.55), Color.clear]),
                        center: .leading,
                        startRadius: 10,
                        endRadius: 420
                    )
                    .blendMode(.screen)
                    RadialGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.4), Color.clear]),
                        center: .bottomTrailing,
                        startRadius: 60,
                        endRadius: 500
                    )
                    .blendMode(.screen)
                }
            case .midnight:
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.06, blue: 0.18),
                            Color(red: 0.12, green: 0.16, blue: 0.31),
                            Color(red: 0.21, green: 0.12, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    StarsOverlay()
                        .opacity(0.35)
                }
            case .ocean:
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.62, blue: 0.86),
                            Color(red: 0.0, green: 0.45, blue: 0.68),
                            Color(red: 0.0, green: 0.24, blue: 0.44)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.25), Color.clear]),
                        center: UnitPoint(x: 0.2, y: 0.2),
                        startRadius: 20,
                        endRadius: 420
                    )
                    .blendMode(.screen)
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            case .winterCabin:
                PhotoBackground(assetName: "WinterCabin", overlayOpacity: 0.35)
            case .forestStream:
                PhotoBackground(assetName: "ForestStream", overlayOpacity: 0.3)
            case .oceanCliff:
                PhotoBackground(assetName: "OceanCliff", overlayOpacity: 0.25)
            case .rainyWindow:
                PhotoBackground(assetName: "RainyWindow", overlayOpacity: 0.4)
            case .autumnCabin:
                PhotoBackground(assetName: "AutumnCabin", overlayOpacity: 0.32)
            case .springCabin:
                PhotoBackground(assetName: "SpringCabin", overlayOpacity: 0.28)
            case .cozyWindow:
                PhotoBackground(assetName: "CozyWindow", overlayOpacity: 0.45)
            case .snowyRetreat:
                PhotoBackground(assetName: "SnowyRetreat", overlayOpacity: 0.36)
            case .mountainTrail:
                PhotoBackground(assetName: "MountainTrail", overlayOpacity: 0.28)
            case .sereneBedroom:
                PhotoBackground(assetName: "SereneBedroom", overlayOpacity: 0.42)
            case .hiddenWaterfall:
                PhotoBackground(assetName: "HiddenWaterfall", overlayOpacity: 0.3)
            case .cozySpices:
                PhotoBackground(assetName: "CozySpices", overlayOpacity: 0.4)
            case .tropicalLagoon:
                PhotoBackground(assetName: "TropicalLagoon", overlayOpacity: 0.25)
            case .readingNook:
                PhotoBackground(assetName: "ReadingNook", overlayOpacity: 0.46)
            case .sunlitVineyard:
                PhotoBackground(assetName: "SunlitVineyard", overlayOpacity: 0.3)
            case .cherryBlossoms:
                PhotoBackground(assetName: "CherryBlossoms", overlayOpacity: 0.25)
            case .starlitShore:
                PhotoBackground(assetName: "StarlitShore", overlayOpacity: 0.42)
            case .alpineRiver:
                PhotoBackground(assetName: "AlpineRiver", overlayOpacity: 0.32)
            case .goldenWillow:
                PhotoBackground(assetName: "GoldenWillow", overlayOpacity: 0.3)
            case .coastalHeadland:
                PhotoBackground(assetName: "CoastalHeadland", overlayOpacity: 0.28)
            case .cabinMug:
                PhotoBackground(assetName: "CabinMug", overlayOpacity: 0.44)
            }
        }
    }
}

// MARK: - Decorative Overlays
private struct StarsOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Canvas { context, _ in
                let starCount = 80
                for _ in 0..<starCount {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let circleSize = CGFloat.random(in: 1.5...2.8)
                    let alpha = Double.random(in: 0.25...0.6)
                    let rect = CGRect(x: x, y: y, width: circleSize, height: circleSize)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(alpha))
                    )
                }
            }
        }
    }
}

// MARK: - Photo Background Wrapper
private struct PhotoBackground: View {
    let assetName: String
    let overlayOpacity: Double

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .overlay(Color.black.opacity(overlayOpacity))
            .clipped()
    }
}

// MARK: - Appearance Preview
struct AppearancePreviewCard: View {
    let colorPack: ThemeColorPack
    let fontStyle: QuoteFontStyle
    let backgroundStyle: QuoteBackgroundStyle

    var body: some View {
        let isPhotoBackground = backgroundStyle.isPhotoBackground
        ZStack {
            QuoteBackgroundView(style: backgroundStyle, colorPack: colorPack)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .center, spacing: 12) {
                Text("Your Daily Quote")
                    .font(fontStyle.quoteFont(size: 18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("- Preview Author")
                    .font(fontStyle.authorFont(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorPack.cardBackground)
                    .opacity(isPhotoBackground ? 0.0 : 0.9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isPhotoBackground ? 0.0 : 0.12), lineWidth: isPhotoBackground ? 0 : 1)
            )
            .shadow(color: isPhotoBackground ? Color.clear : colorPack.accentColor.opacity(0.3), radius: isPhotoBackground ? 0 : 10, x: 0, y: isPhotoBackground ? 0 : 6)
            .padding(12)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(isPhotoBackground ? 0.0 : 0.08), lineWidth: isPhotoBackground ? 0 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Theme preview showing current color pack, font, and background")
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @Binding var dailyReminderHour: Int
    @Binding var dailyReminderMinute: Int
    @Binding var selectedThemeColorPack: String
    @Binding var selectedFontStyle: String
    @Binding var selectedBackgroundStyle: String
    @Environment(\.dismiss) private var dismiss

    // Helper to create a Date from hour/minute
    private var reminderTime: Date {
        var components = DateComponents()
        components.hour = dailyReminderHour
        components.minute = dailyReminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        let colorPack = ThemeColorPack(rawValue: selectedThemeColorPack) ?? .classic
        let fontStyle = QuoteFontStyle(rawValue: selectedFontStyle) ?? .rounded
        let backgroundStyle = QuoteBackgroundStyle(rawValue: selectedBackgroundStyle) ?? .classic

        return NavigationStack {
            Form {
                Section(header: Text("Daily Reminder Time")) {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { reminderTime },
                            set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                dailyReminderHour = comps.hour ?? 9
                                dailyReminderMinute = comps.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section(header: Text("Appearance")) {
                    Picker("Color Pack", selection: $selectedThemeColorPack) {
                        ForEach(ThemeColorPack.allCases) { pack in
                            Label(pack.displayName, systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(pack.secondaryAccent, pack.accentColor)
                                .tag(pack.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Quote Font", selection: $selectedFontStyle) {
                        ForEach(QuoteFontStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Background", selection: $selectedBackgroundStyle) {
                        ForEach(QuoteBackgroundStyle.allCases) { style in
                            Label(style.displayName, systemImage: style.iconName)
                                .tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    AppearancePreviewCard(
                        colorPack: colorPack,
                        fontStyle: fontStyle,
                        backgroundStyle: backgroundStyle
                    )
                    .padding(.top, 6)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


// MARK: - ActivityView (UIViewControllerRepresentable)
// Definition needed for the .sheet modifier
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing needed here for basic sharing.
    }
}


// MARK: - Preview
#Preview {
    guard
        let favoritesStore = UserDefaults(suiteName: "preview.content.favorites"),
        let engagementStore = UserDefaults(suiteName: "preview.content.engagement")
    else {
        fatalError("Unable to create preview user defaults stores.")
    }
    favoritesStore.removePersistentDomain(forName: "preview.content.favorites")
    engagementStore.removePersistentDomain(forName: "preview.content.engagement")

    return ContentView(
        favoritesManager: FavoritesManager(userDefaults: favoritesStore),
        engagementTracker: EngagementTracker(userDefaults: engagementStore)
    )
}

// MARK: - ContentView.swift

import SwiftUI
import UserNotifications // <-- Import UserNotifications

struct ContentView: View {
    // Environment
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    // StateObjects for ViewModel and FavoritesManager
    @StateObject private var favoritesManager: FavoritesManager
    @StateObject private var engagementTracker: EngagementTracker
    @StateObject private var noteManager: NoteManager
    @StateObject private var dailyResetManager: DailyResetManager
    @StateObject private var personalizationManager: PersonalizationManager
    @StateObject private var viewModel: QuoteViewModel

    // State for navigation, sheets, notification time, and category selection
    @State private var showingFavorites = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []
    @State private var showingSettings = false
    @State private var showStreakPopup = false
    @State private var showingOnboarding = false
    @State private var showingNoteEditor = false
    @State private var showingDailyReset = false
    @State private var showShareSuccessToast = false
    @State private var noteDraft: String = ""
    @State private var searchText: String = ""
    @State private var customReminders: [CustomReminder] = []
    @State private var hasLoadedCustomReminders = false
    @State private var lastRefreshedDay: Date?
    @State private var notificationsDenied = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour: Int = 9
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute: Int = 0
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled: Bool = true
    @AppStorage("smartMorningEnabled") private var smartMorningEnabled: Bool = false
    @AppStorage("smartMorningHour") private var smartMorningHour: Int = 7
    @AppStorage("smartMorningMinute") private var smartMorningMinute: Int = 0
    @AppStorage("smartEveningEnabled") private var smartEveningEnabled: Bool = false
    @AppStorage("smartEveningHour") private var smartEveningHour: Int = 22
    @AppStorage("smartEveningMinute") private var smartEveningMinute: Int = 0
    @AppStorage("selectedQuoteCategory") private var selectedCategory: String = "All"
    @AppStorage("preferredQuoteCategoriesData") private var preferredCategoriesData: Data = Data()
    @AppStorage("selectedThemeColorPack") private var selectedColorPackRawValue: String = ThemeColorPack.classic.rawValue
    @AppStorage("selectedFontStyle") private var selectedFontStyleRawValue: String = QuoteFontStyle.rounded.rawValue
    @AppStorage("selectedBackgroundStyle") private var selectedBackgroundStyleRawValue: String = QuoteBackgroundStyle.classic.rawValue
    @AppStorage("customRemindersData") private var customRemindersData: Data = Data()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    private let focusBlurbs: [String: String] = [
        "Success": "Build momentum with one small win today.",
        "Creativity": "Give your brain whitespace—capture one new idea.",
        "Mindfulness": "Pause, breathe, and make space for what matters.",
        "Motivation": "Take the next micro-step toward your goal.",
        "Happiness": "Savor one bright spot; share it with someone else.",
        "Resilience": "Lean in—setbacks are reps for your grit.",
        "Gratitude": "Write one thank you note (even if you never send it).",
        "Focus": "Protect 25 minutes for your most important task."
    ]

    // Constants for font scaling (adjust these as needed based on testing)
    private let minQuoteFontSize: CGFloat = 18
    private let maxQuoteFontSize: CGFloat = 44
    // Adjust this factor based on testing across screen sizes
    private let fontHeightScaleFactor: CGFloat = 0.09
    private let shareSuccessToastDuration: TimeInterval = 2.4
    private let notificationHorizonDays = NotificationManager.Identifier.quoteSequenceLength

    // Initializer to inject dependencies, enabling previews and tests to supply isolated stores.
    init(
        favoritesManager: FavoritesManager = FavoritesManager(),
        engagementTracker: EngagementTracker = EngagementTracker(),
        noteManager: NoteManager = NoteManager(),
        dailyResetManager: DailyResetManager = DailyResetManager(),
        personalizationManager: PersonalizationManager = PersonalizationManager()
    ) {
        let favManager = favoritesManager
        let tracker = engagementTracker
        let noteMgr = noteManager
        let resetManager = dailyResetManager
        let personalization = personalizationManager
        _favoritesManager = StateObject(wrappedValue: favManager)
        _engagementTracker = StateObject(wrappedValue: tracker)
        _noteManager = StateObject(wrappedValue: noteMgr)
        _dailyResetManager = StateObject(wrappedValue: resetManager)
        _personalizationManager = StateObject(wrappedValue: personalization)
        _viewModel = StateObject(wrappedValue: QuoteViewModel(favoritesManager: favManager, engagementTracker: tracker))
    }

    private func preferredNotificationCategories() -> [String] {
        var ordered = storedPreferredCategories()
        if selectedCategory != "All" {
            if !ordered.contains(selectedCategory) {
                ordered.insert(selectedCategory, at: 0)
            }
        }

        let favoriteCategories = favoritesManager
            .getFavoriteQuotes(from: viewModel.allQuotes)
            .map { $0.category }
        for category in favoriteCategories where !ordered.contains(category) {
            ordered.append(category)
        }

        let learnedCategories = personalizationManager.rankedCategories(
            availableCategories: availableCategories().filter { $0 != "All" }
        )
        for category in learnedCategories
        where personalizationManager.categoryScores[category, default: 0] > 0 && !ordered.contains(category) {
            ordered.append(category)
        }

        return ordered
    }

    private func storedPreferredCategories() -> [String] {
        guard
            !preferredCategoriesData.isEmpty,
            let decoded = try? JSONDecoder().decode([String].self, from: preferredCategoriesData)
        else {
            return selectedCategory == "All" ? [] : [selectedCategory]
        }

        let available = Set(availableCategories().filter { $0 != "All" })
        return decoded.filter { available.contains($0) }
    }

    private func persistPreferredCategories(_ categories: [String]) {
        let available = Set(availableCategories().filter { $0 != "All" })
        let sanitized = Array(categories.filter { available.contains($0) }.prefix(3))
        preferredCategoriesData = (try? JSONEncoder().encode(sanitized)) ?? Data()
    }

    private func migratePreferredCategoriesIfNeeded() {
        guard preferredCategoriesData.isEmpty, selectedCategory != "All" else { return }
        persistPreferredCategories([selectedCategory])
    }

    private func buildNotificationQuotes() -> (daily: [Quote], morning: [Quote], evening: [Quote])? {
        let preferredCategories = preferredNotificationCategories()
        let planned = viewModel.plannedQuotes(
            count: notificationHorizonDays * 3,
            preferredCategories: preferredCategories
        )
        guard !planned.isEmpty else { return nil }

        return (
            daily: stride(from: 0, to: planned.count, by: 3).map { planned[$0] },
            morning: stride(from: 1, to: planned.count, by: 3).map { planned[$0] },
            evening: stride(from: 2, to: planned.count, by: 3).map { planned[$0] }
        )
    }

    private func scheduleNotifications(
        dailyQuotes: [Quote],
        morningQuotes: [Quote],
        eveningQuotes: [Quote]
    ) {
        if dailyReminderEnabled {
            NotificationManager.shared.scheduleDailyQuoteNotifications(
                quotes: dailyQuotes,
                hour: dailyReminderHour,
                minute: dailyReminderMinute
            )
        } else {
            NotificationManager.shared.cancelNotifications(identifiers: [NotificationManager.Identifier.daily])
        }

        NotificationManager.shared.scheduleSmartNotifications(
            morningQuotes: morningQuotes,
            morningEnabled: smartMorningEnabled,
            morningHour: smartMorningHour,
            morningMinute: smartMorningMinute,
            eveningQuotes: eveningQuotes,
            eveningEnabled: smartEveningEnabled,
            eveningHour: smartEveningHour,
            eveningMinute: smartEveningMinute
        )

        if let referenceQuote = dailyQuotes.first {
            NotificationManager.shared.updateReminders(
                customReminders.map { $0.asNotification(quote: referenceQuote) }
            )
        }
    }

    private func scheduleNotificationsIfPossible() {
        guard let quotes = buildNotificationQuotes() else {
            NotificationManager.shared.updateReminders([])
            return
        }
        scheduleNotifications(
            dailyQuotes: quotes.daily,
            morningQuotes: quotes.morning,
            eveningQuotes: quotes.evening
        )
    }

    private func updateNotificationSchedule(requestAuthorizationIfNeeded: Bool = false) {
        NotificationManager.shared.getAuthorizationStatus { status in
            notificationsDenied = status == .denied
            switch status {
            case .authorized, .provisional, .ephemeral:
                scheduleNotificationsIfPossible()
            case .notDetermined where requestAuthorizationIfNeeded:
                NotificationManager.shared.requestAuthorization { granted in
                    notificationsDenied = !granted
                    if granted {
                        scheduleNotificationsIfPossible()
                    }
                }
            case .notDetermined, .denied:
                break
            @unknown default:
                break
            }
        }
    }

    /// Re-reads permission so the "notifications are off" notice reflects changes made in iOS Settings.
    private func refreshNotificationPermission() {
        NotificationManager.shared.getAuthorizationStatus { status in
            notificationsDenied = status == .denied
        }
    }

    private func refreshDailyContentIfNeeded(now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        guard lastRefreshedDay.map({ !Calendar.current.isDate($0, inSameDayAs: today) }) ?? true else {
            return
        }

        if lastRefreshedDay != nil {
            viewModel.setCurrentQuoteToDaily()
            syncNoteDraftWithCurrentQuote()
        }
        lastRefreshedDay = today
    }

    private func resetAllLocalData() {
        NotificationManager.shared.cancelAllManagedReminders()
        NotificationManager.shared.cancelNotifications()
        favoritesManager.resetAll()
        noteManager.resetAll()
        dailyResetManager.resetAll()
        personalizationManager.resetAll()
        engagementTracker.resetAll()
        AnalyticsLogger.resetData()

        customReminders = []
        customRemindersData = Data()
        searchText = ""
        dailyReminderEnabled = false
        smartMorningEnabled = false
        smartEveningEnabled = false
        selectedCategory = "All"
        preferredCategoriesData = Data()
        selectedColorPackRawValue = ThemeColorPack.classic.rawValue
        selectedFontStyleRawValue = QuoteFontStyle.rounded.rawValue
        selectedBackgroundStyleRawValue = QuoteBackgroundStyle.classic.rawValue
        hasCompletedOnboarding = false
        lastRefreshedDay = nil
        viewModel.setCurrentQuoteToDaily()
        showingSettings = false

        DispatchQueue.main.async {
            showingOnboarding = true
        }
    }

    private func loadCustomRemindersIfNeeded() {
        guard !hasLoadedCustomReminders else { return }
        defer { hasLoadedCustomReminders = true }

        guard !customRemindersData.isEmpty else {
            customReminders = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([CustomReminder].self, from: customRemindersData)
            customReminders = Array(decoded.prefix(NotificationManager.Identifier.maximumFlexibleReminderCount))
        } catch {
            customReminders = []
        }
    }

    private func persistCustomReminders() {
        do {
            customRemindersData = try JSONEncoder().encode(customReminders)
        } catch {
            #if DEBUG
            print("Unable to persist custom reminders: \(error.localizedDescription)")
            #endif
        }
    }

    private func availableCategories() -> [String] {
        let dynamic = viewModel.availableCategories(includeAll: true)
        if dynamic.count > 1 {
            return dynamic
        } else {
            return ["All", "Focus", "Gratitude", "Resilience", "Success", "Mindfulness", "Creativity", "Motivation", "Happiness"]
        }
    }

    private func categoryCountsDictionary() -> [String: Int] {
        var counts = viewModel.categoryCounts()
        counts["All"] = viewModel.allQuotes.count
        return counts
    }

    private func focusLine(for quote: Quote) -> String {
        focusBlurbs[quote.category] ?? "Lean into today's quote and take one tiny action."
    }

    private func shareInviteMessage(for quote: Quote) -> String {
        ShareInviteMessageBuilder.message(
            for: quote,
            currentStreak: engagementTracker.summary.currentStreak
        )
    }

    private func prepareShare(
        for quote: Quote,
        colorPack: ThemeColorPack,
        fontStyle: QuoteFontStyle,
        backgroundStyle: QuoteBackgroundStyle
    ) {
        var items: [Any] = []
        if let image = QuoteShareCardRenderer.render(
            quote: quote,
            colorPack: colorPack,
            fontStyle: fontStyle,
            backgroundStyle: backgroundStyle
        ) {
            items.append(image)
        }
        items.append(shareInviteMessage(for: quote))
        shareItems = items
        engagementTracker.logShareClicked()
        isSharePresented = true
    }

    private func presentShareSuccessToast() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            showShareSuccessToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + shareSuccessToastDuration) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showShareSuccessToast = false
            }
        }
    }

    private func syncNoteDraftWithCurrentQuote() {
        if let current = viewModel.currentQuote {
            noteDraft = noteManager.note(for: current) ?? ""
        } else {
            noteDraft = ""
        }
    }

    // Extracted to keep body light for type-checker
    @ViewBuilder
    private func makeLayoutView(
        geometry: GeometryProxy,
        categories: [String],
        categoryCounts: [String: Int],
        fontStyle: QuoteFontStyle,
        colorPack: ThemeColorPack,
        isPhotoBackground: Bool
    ) -> some View {
        QuoteLayoutView(
            size: geometry.size,
            safeAreaInsets: geometry.safeAreaInsets,
            verticalSizeClass: verticalSizeClass,
            categories: categories,
            preferredCategories: preferredNotificationCategories(),
            selectedCategory: $selectedCategory,
            searchText: $searchText,
            showStreakPopup: $showStreakPopup,
            focusLine: focusLine(for:),
            onShare: { quote in
                prepareShare(
                    for: quote,
                    colorPack: colorPack,
                    fontStyle: fontStyle,
                    backgroundStyle: QuoteBackgroundStyle(rawValue: selectedBackgroundStyleRawValue) ?? .classic
                )
            },
            engagementTracker: engagementTracker,
            dailyResetManager: dailyResetManager,
            personalizationManager: personalizationManager,
            viewModel: viewModel,
            favoritesManager: favoritesManager,
            noteManager: noteManager,
            showingNoteEditor: $showingNoteEditor,
            showingDailyReset: $showingDailyReset,
            noteDraft: $noteDraft,
            fontStyle: fontStyle,
            colorPack: colorPack,
            isPhotoBackground: isPhotoBackground,
            minQuoteFontSize: minQuoteFontSize,
            maxQuoteFontSize: maxQuoteFontSize,
            fontHeightScaleFactor: fontHeightScaleFactor
        )
    }

    @ViewBuilder
    private func buildMainView(
        backgroundStyle: QuoteBackgroundStyle,
        colorPack: ThemeColorPack,
        categories: [String],
        categoryCounts: [String: Int],
        fontStyle: QuoteFontStyle,
        isPhotoBackground: Bool
    ) -> some View {
        ZStack {
            QuoteBackgroundView(style: backgroundStyle, colorPack: colorPack)
                .edgesIgnoringSafeArea(.all)

            GeometryReader { geometry in
                makeLayoutView(
                    geometry: geometry,
                    categories: categories,
                    categoryCounts: categoryCounts,
                    fontStyle: fontStyle,
                    colorPack: colorPack,
                    isPhotoBackground: isPhotoBackground
                )
            }
            // Keep the quote card from collapsing when the search keyboard appears.
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
             Button {
                 // A push requested while the search bar is dismissing can be dropped, leaving the
                 // flag stuck at true; resetting first makes every tap open the Library.
                 showingFavorites = false
                 DispatchQueue.main.async { showingFavorites = true }
             } label: {
                 Image(systemName: "books.vertical")
                     .accessibilityLabel("Library: favorites and reflections")
             }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            let streak = engagementTracker.summary.currentStreak
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showStreakPopup.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    Text("\(streak)")
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel(streak == 1 ? "Streak: 1 day" : "Streak: \(streak) days")
            .accessibilityHint(showStreakPopup ? "Hides streak details" : "Shows streak details")
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

    @ViewBuilder
    private func onboardingFlow() -> some View {
        let onboardingCategories = availableCategories().filter { $0 != "All" }
        let defaultCategory = onboardingCategories.contains("Motivation")
            ? "Motivation"
            : onboardingCategories.first ?? "Focus"
        OnboardingView(
            categories: onboardingCategories.isEmpty ? ["Focus", "Gratitude", "Resilience"] : onboardingCategories,
            defaultCategory: defaultCategory,
            defaultReminderHour: dailyReminderHour,
            defaultReminderMinute: dailyReminderMinute
        ) { result in
            persistPreferredCategories(result.preferredCategories)
            selectedCategory = "All"
            dailyReminderHour = result.reminderHour
            dailyReminderMinute = result.reminderMinute
            dailyReminderEnabled = result.reminderEnabled
            hasCompletedOnboarding = true
            showingOnboarding = false
            AnalyticsLogger.log(.onboardingCompleted, ["categories": result.preferredCategories.joined(separator: ",")])
            viewModel.showNewPreferredQuote(
                preferredCategories: result.preferredCategories
            )
            // onAppear skipped this while onboarding was pending, so count today's first view now.
            viewModel.recordDailyQuoteView()
            if result.reminderEnabled {
                updateNotificationSchedule(requestAuthorizationIfNeeded: true)
            }
            // Consent/tracking prompts come after onboarding. If the notification alert is
            // showing, returning to .active below starts them instead; this is the fallback.
            DispatchQueue.main.asyncAfter(deadline: .now() + (result.reminderEnabled ? 3 : 0.8)) {
                AdsManager.shared.startIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func streakOverlay(colorPack: ThemeColorPack) -> some View {
        if showStreakPopup {
            StreakHeaderView(summary: engagementTracker.summary, colorPack: colorPack) {
                updateNotificationSchedule(requestAuthorizationIfNeeded: true)
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
            .accessibilityAction(.escape) {
                showStreakPopup = false
            }
            .accessibilityAction(named: "Close streak details") {
                showStreakPopup = false
            }
            .zIndex(1000)
        }
    }

    @ViewBuilder
    private func shareSuccessOverlay(colorPack: ThemeColorPack) -> some View {
        if showShareSuccessToast {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, colorPack.accentColor)
                Text("Invite shared")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(colorPack.cardBackground.opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    var body: some View {
        let colorPack: ThemeColorPack = ThemeColorPack(rawValue: selectedColorPackRawValue) ?? .classic
        let fontStyle: QuoteFontStyle = QuoteFontStyle(rawValue: selectedFontStyleRawValue) ?? .rounded
        let backgroundStyle: QuoteBackgroundStyle = QuoteBackgroundStyle(rawValue: selectedBackgroundStyleRawValue) ?? .classic
        let isPhotoBackground: Bool = backgroundStyle.isPhotoBackground
        let navigationBarColorScheme: ColorScheme? = backgroundStyle.navigationBarColorScheme
        let categories: [String] = availableCategories()
        let categoryCounts: [String: Int] = categoryCountsDictionary()

        let mainContent = buildMainView(
            backgroundStyle: backgroundStyle,
            colorPack: colorPack,
            categories: categories,
            categoryCounts: categoryCounts,
            fontStyle: fontStyle,
            isPhotoBackground: isPhotoBackground
        )

        let contentWithNavigation = mainContent
            .navigationTitle("Daily Motivation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mainToolbar }
            .searchable(text: $searchText, prompt: "Search quotes or authors")
            .navigationDestination(isPresented: $showingFavorites) {
                FavoritesView(
                    viewModel: viewModel,
                    favoritesManager: favoritesManager,
                    engagementTracker: engagementTracker,
                    noteManager: noteManager,
                    dailyResetManager: dailyResetManager,
                    onOpenQuote: { quote in
                        viewModel.currentQuote = quote
                        // Switching to the quote's category keeps it visible (the filter sync leaves
                        // a matching quote alone); "All" already includes it.
                        if selectedCategory != "All" && selectedCategory != quote.category {
                            selectedCategory = quote.category
                        }
                    }
                )
            }
            .toolbarColorScheme(navigationBarColorScheme, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)

        let contentWithSheets = contentWithNavigation
            .sheet(isPresented: $isSharePresented) {
                if !shareItems.isEmpty {
                    ActivityView(
                        activityItems: shareItems,
                        onComplete: { completed in
                            guard completed else { return }
                            DispatchQueue.main.async {
                                engagementTracker.logShareCompleted()
                                presentShareSuccessToast()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingNoteEditor) {
                if let currentQuote = viewModel.currentQuote {
                    NoteEditorView(
                        quote: currentQuote,
                        initialNote: noteDraft,
                        onSave: { text in
                            noteManager.setNote(text, for: currentQuote)
                            AnalyticsLogger.log(.noteSaved)
                            syncNoteDraftWithCurrentQuote()
                            showingNoteEditor = false
                        },
                        onCancel: {
                            showingNoteEditor = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingDailyReset) {
                DailyResetView(
                    manager: dailyResetManager,
                    viewModel: viewModel,
                    engagementTracker: engagementTracker,
                    preferredCategories: storedPreferredCategories()
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    dailyReminderHour: $dailyReminderHour,
                    dailyReminderMinute: $dailyReminderMinute,
                    dailyReminderEnabled: $dailyReminderEnabled,
                    smartMorningEnabled: $smartMorningEnabled,
                    smartMorningHour: $smartMorningHour,
                    smartMorningMinute: $smartMorningMinute,
                    smartEveningEnabled: $smartEveningEnabled,
                    smartEveningHour: $smartEveningHour,
                    smartEveningMinute: $smartEveningMinute,
                    selectedThemeColorPack: $selectedColorPackRawValue,
                    selectedFontStyle: $selectedFontStyleRawValue,
                    selectedBackgroundStyle: $selectedBackgroundStyleRawValue,
                    customReminders: $customReminders,
                    notificationsDenied: notificationsDenied,
                    onResetAllData: resetAllLocalData
                )
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                onboardingFlow()
            }
            .overlay(alignment: .top) {
                streakOverlay(colorPack: colorPack)
            }
            .overlay(alignment: .bottom) {
                shareSuccessOverlay(colorPack: colorPack)
            }

        NavigationStack {
            contentWithSheets
            .onAppear {
                loadCustomRemindersIfNeeded()
                migratePreferredCategoriesIfNeeded()
                refreshDailyContentIfNeeded()
                if viewModel.currentQuote == nil && viewModel.errorMessage == nil {
                    viewModel.setCurrentQuoteToDaily()
                }
                syncNoteDraftWithCurrentQuote()

                if !hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showingOnboarding = true
                    }
                }

                if hasCompletedOnboarding {
                    viewModel.recordDailyQuoteView()
                    AdsManager.shared.startIfNeeded()
                }
                updateNotificationSchedule()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                refreshDailyContentIfNeeded()
                updateNotificationSchedule()
                if hasCompletedOnboarding && !showingOnboarding {
                    AdsManager.shared.startIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshDailyContentIfNeeded()
                updateNotificationSchedule()
            }
            .onChange(of: showingSettings) { isShowing in
                if isShowing { refreshNotificationPermission() }
            }
            .onChange(of: dailyReminderHour) { _ in updateNotificationSchedule() }
            .onChange(of: dailyReminderMinute) { _ in updateNotificationSchedule() }
            .onChange(of: dailyReminderEnabled) { enabled in
                updateNotificationSchedule(requestAuthorizationIfNeeded: enabled)
            }
            .onChange(of: smartMorningEnabled) { enabled in
                updateNotificationSchedule(requestAuthorizationIfNeeded: enabled)
            }
            .onChange(of: smartMorningHour) { _ in updateNotificationSchedule() }
            .onChange(of: smartMorningMinute) { _ in updateNotificationSchedule() }
            .onChange(of: smartEveningEnabled) { enabled in
                updateNotificationSchedule(requestAuthorizationIfNeeded: enabled)
            }
            .onChange(of: smartEveningHour) { _ in updateNotificationSchedule() }
            .onChange(of: smartEveningMinute) { _ in updateNotificationSchedule() }
            .onChange(of: selectedCategory) { _ in updateNotificationSchedule() }
            .onChange(of: preferredCategoriesData) { _ in updateNotificationSchedule() }
            .onChange(of: personalizationManager.categoryScores) { _ in
                updateNotificationSchedule()
            }
            .onChange(of: viewModel.currentQuote?.id) { _ in syncNoteDraftWithCurrentQuote() }
            .onChange(of: customReminders) { _ in
                guard hasLoadedCustomReminders else { return }
                persistCustomReminders()
                updateNotificationSchedule(
                    requestAuthorizationIfNeeded: customReminders.contains(where: { $0.isEnabled })
                )
            }
        }
    } // End body
} // End ContentView struct

// MARK: - Layout Extraction
private struct QuoteLayoutView: View {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let verticalSizeClass: UserInterfaceSizeClass?
    let categories: [String]
    let preferredCategories: [String]
    @Binding var selectedCategory: String
    @Binding var searchText: String
    @Binding var showStreakPopup: Bool
    let focusLine: (Quote) -> String
    let onShare: (Quote) -> Void
    @ObservedObject var engagementTracker: EngagementTracker
    @ObservedObject var dailyResetManager: DailyResetManager
    @ObservedObject var personalizationManager: PersonalizationManager
    @ObservedObject var viewModel: QuoteViewModel
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var noteManager: NoteManager
    @Binding var showingNoteEditor: Bool
    @Binding var showingDailyReset: Bool
    @Binding var noteDraft: String
    let fontStyle: QuoteFontStyle
    let colorPack: ThemeColorPack
    let isPhotoBackground: Bool
    let minQuoteFontSize: CGFloat
    let maxQuoteFontSize: CGFloat
    let fontHeightScaleFactor: CGFloat

    @Environment(\.dismissSearch) private var dismissSearch
    @ObservedObject private var ads = AdsManager.shared
    // Scales the geometry-derived quote size with the user's Dynamic Type setting.
    @ScaledMetric(relativeTo: .title) private var quoteTextScale: CGFloat = 1
    // Set when a search result is picked so clearing the search keeps that quote.
    @State private var keepCurrentQuoteOnNextSync = false

    private func showNextQuote(categoryFilter: String?) {
        AnalyticsLogger.log(.quoteNext)
        AdsManager.shared.registerNextTap()
        if let currentQuote = viewModel.currentQuote {
            personalizationManager.recordSkipped(currentQuote)
        }
        if let categoryFilter {
            viewModel.showNewRandomQuote(category: categoryFilter)
        } else {
            viewModel.showNewPreferredQuote(preferredCategories: preferredCategories)
        }
    }

    var body: some View {
        let isCompactHeight = (verticalSizeClass == .compact) || size.width > size.height
        let containerSpacing: CGFloat = isCompactHeight ? 12 : 20
        // Keep content higher in all cases; ignore large safe-area insets pushing it down
        let safeTopInset: CGFloat = 0
        let baseTopPadding: CGFloat = isCompactHeight ? 28 : 12
        let effectiveTopPadding = baseTopPadding + safeTopInset
        let bottomPadding: CGFloat = safeAreaInsets.bottom + (isCompactHeight ? 18 : 20)
        // The Home banner takes ~80pt in portrait, so size the quote for the shorter card it leaves.
        let reservesBanner = !isCompactHeight && ads.canShowAds && RemoteSettings.bannerEnabled
        let quoteHeightFactor: CGFloat = isCompactHeight ? 0.48 : (reservesBanner ? 0.53 : 0.62)
        let quoteAreaMaxHeight = size.height * quoteHeightFactor
        let cardMinHeightMultiplier: CGFloat = isCompactHeight ? 0.66 : 0.9
        let adjustedFontScale = fontHeightScaleFactor * (isCompactHeight ? 0.85 : 1.0)
        let baseQuoteFontSize = max(minQuoteFontSize, min(quoteAreaMaxHeight * adjustedFontScale, maxQuoteFontSize))
        let calculatedQuoteFontSize = min(baseQuoteFontSize * quoteTextScale, maxQuoteFontSize * 1.5)
        let calculatedAuthorFontSize = max(minQuoteFontSize * 0.6, min(calculatedQuoteFontSize * 0.5, maxQuoteFontSize * 0.6))
        let horizontalPadding: CGFloat = isCompactHeight ? 12 : 16
        let filteredQuotes = visibleQuotes()
        let currentQuote = filteredQuotes.first(where: { $0.id == viewModel.currentQuote?.id }) ?? filteredQuotes.first
        let isSearching = !normalizedSearchText.isEmpty

        Group {
            let layout = contentLayout(
                filteredQuotes: filteredQuotes,
                currentQuote: currentQuote,
                isSearching: isSearching,
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
        .onChange(of: selectedCategory) { _ in
            syncCurrentQuoteWithFilters()
        }
        .onChange(of: searchText) { _ in
            syncCurrentQuoteWithFilters()
        }
    }

    @ViewBuilder
    private func contentLayout(
        filteredQuotes: [Quote],
        currentQuote: Quote?,
        isSearching: Bool,
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

        if isCompactHeight {
            // Landscape: show only quote card and action buttons to avoid cramped UI.
            VStack(spacing: containerSpacing) {
                if filteredQuotes.isEmpty, viewModel.errorMessage == nil {
                    filteredEmptyState(isSearching: isSearching, categoryFilter: categoryFilter)
                } else if isSearching {
                    searchResultsList(filteredQuotes, horizontalPadding: horizontalPadding)
                } else if let currentQuote {
                    quoteCard(
                        quote: currentQuote,
                        quoteAreaMaxHeight: quoteAreaMaxHeight,
                        cardMinHeightMultiplier: cardMinHeightMultiplier,
                        calculatedQuoteFontSize: calculatedQuoteFontSize,
                        calculatedAuthorFontSize: calculatedAuthorFontSize,
                        isCompactHeight: isCompactHeight,
                        horizontalPadding: horizontalPadding
                    )
                } else if viewModel.errorMessage == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                    Text("Loading Quote...")
                        .foregroundColor(.white)
                }

                if !isSearching, let quoteForButtons = currentQuote {
                    dailyResetButton(
                        isPhotoBackground: isPhotoBackground,
                        horizontalPadding: horizontalPadding
                    )
                    actionButtons(
                        quote: quoteForButtons,
                        categoryFilter: categoryFilter,
                        isPhotoBackground: isPhotoBackground,
                        horizontalPadding: horizontalPadding
                    )
                }
            }
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            VStack(spacing: containerSpacing) {
                categoryFilterRow(horizontalPadding: horizontalPadding)
                    .opacity(showStreakPopup ? 0 : 1)
                    .allowsHitTesting(!showStreakPopup)
                    .accessibilityHidden(showStreakPopup)
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

                if filteredQuotes.isEmpty, viewModel.errorMessage == nil {
                    filteredEmptyState(isSearching: isSearching, categoryFilter: categoryFilter)
                    Spacer()
                } else if isSearching {
                    searchResultsList(filteredQuotes, horizontalPadding: horizontalPadding)
                } else if let currentQuote {
                    quoteCard(
                        quote: currentQuote,
                        quoteAreaMaxHeight: quoteAreaMaxHeight,
                        cardMinHeightMultiplier: cardMinHeightMultiplier,
                        calculatedQuoteFontSize: calculatedQuoteFontSize,
                        calculatedAuthorFontSize: calculatedAuthorFontSize,
                        isCompactHeight: isCompactHeight,
                        horizontalPadding: horizontalPadding
                    )
                } else if viewModel.errorMessage == nil {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading Quote...")
                        .foregroundColor(.white)
                    Spacer()
                }

                if !isSearching, let quoteForButtons = currentQuote {
                    dailyResetButton(
                        isPhotoBackground: isPhotoBackground,
                        horizontalPadding: horizontalPadding
                    )
                    actionButtons(
                        quote: quoteForButtons,
                        categoryFilter: categoryFilter,
                        isPhotoBackground: isPhotoBackground,
                        horizontalPadding: horizontalPadding
                    )

                    focusTip(for: quoteForButtons, horizontalPadding: horizontalPadding)

                    AdBannerView()
                        .padding(.horizontal, horizontalPadding)
                }
            }
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
    }

    /// A one-line nudge tied to the quote's category, filling the space under the actions.
    private func focusTip(for quote: Quote, horizontalPadding: CGFloat) -> some View {
        Label {
            Text(focusLine(quote))
        } icon: {
            Image(systemName: "lightbulb.fill")
        }
        .font(.footnote.weight(.medium))
        .foregroundColor(.white.opacity(0.85))
        .multilineTextAlignment(.leading)
        .padding(.horizontal, horizontalPadding + 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel("Today's focus: \(focusLine(quote))")
    }

    @ViewBuilder
    private func categoryFilterRow(horizontalPadding: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundColor(isSelected ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        isSelected
                                        ? Color.white.opacity(0.92)
                                        : Color.white.opacity(isPhotoBackground ? 0.14 : 0.18)
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        Color.white.opacity(isSelected ? 0.0 : 0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(category) category")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter quotes by category")
    }

    @ViewBuilder
    private func searchResultsList(_ results: [Quote], horizontalPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(results.count == 1 ? "1 matching quote" : "\(results.count) matching quotes")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(results) { quote in
                        Button {
                            selectSearchResult(quote)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\"\(quote.quote)\"")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(4)
                                HStack {
                                    Text("- \(quote.author)")
                                    Spacer()
                                    Text(quote.category)
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.28))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Shows this quote on the home screen")
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private func selectSearchResult(_ quote: Quote) {
        AnalyticsLogger.log(.searchResultOpened)
        keepCurrentQuoteOnNextSync = true
        viewModel.currentQuote = quote
        searchText = ""
        dismissSearch()
    }

    @ViewBuilder
    private func filteredEmptyState(isSearching: Bool, categoryFilter: String?) -> some View {
        VStack(spacing: 8) {
            if isSearching {
                Text("No results for \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(categoryFilter == nil
                     ? "Try a different quote snippet or author name."
                     : "Only \(categoryFilter ?? "") quotes are searched. Try All or a different word.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                HStack(spacing: 10) {
                    if categoryFilter != nil {
                        emptyStateButton("Search all categories") { selectedCategory = "All" }
                    }
                    emptyStateButton("Clear search") {
                        searchText = ""
                        dismissSearch()
                    }
                }
                .padding(.top, 6)
            } else if let categoryFilter {
                Text("No quotes in \(categoryFilter) yet")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Switch categories or clear filters to see more quotes.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                emptyStateButton("Show all quotes") { selectedCategory = "All" }
                    .padding(.top, 6)
            } else {
                Text("No quotes available")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private func emptyStateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(Color.white.opacity(0.92)))
        }
        .buttonStyle(.plain)
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func categoryFilteredQuotes() -> [Quote] {
        selectedCategory == "All"
            ? viewModel.allQuotes
            : viewModel.allQuotes.filter { $0.category == selectedCategory }
    }

    private func visibleQuotes() -> [Quote] {
        viewModel.filterQuotes(categoryFilteredQuotes(), matching: searchText)
    }

    /// Keeps the home quote meaningful as filters change: "All" with no search returns to
    /// today's quote, a category keeps the current quote when it fits or picks an unseen one.
    /// While searching, the results list is shown instead, so the current quote is left alone.
    private func syncCurrentQuoteWithFilters() {
        if keepCurrentQuoteOnNextSync {
            keepCurrentQuoteOnNextSync = false
            return
        }
        guard normalizedSearchText.isEmpty else { return }

        if selectedCategory == "All" {
            viewModel.setCurrentQuoteToDaily()
        } else if viewModel.currentQuote?.category != selectedCategory {
            viewModel.showNewRandomQuote(category: selectedCategory)
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func dailyResetButton(
        isPhotoBackground: Bool,
        horizontalPadding: CGFloat
    ) -> some View {
        let isCompleted = dailyResetManager.entry()?.isCompleted == true
        Button {
            showingDailyReset = true
        } label: {
            Label(
                isCompleted ? "Today's reset complete" : "Start today's reset",
                systemImage: isCompleted ? "checkmark.circle.fill" : "sparkles"
            )
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorPack.accentColor.opacity(isPhotoBackground ? 0.72 : 0.9))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, horizontalPadding)
        .accessibilityHint(isCompleted ? "Opens today's reflection" : "Choose a need, reflect, and commit to one small action")
    }

    @ViewBuilder
    private func quoteCard(
        quote: Quote,
        quoteAreaMaxHeight: CGFloat,
        cardMinHeightMultiplier: CGFloat,
        calculatedQuoteFontSize: CGFloat,
        calculatedAuthorFontSize: CGFloat,
        isCompactHeight: Bool,
        horizontalPadding: CGFloat
    ) -> some View {
        VStack {
            // Picks the largest font size at which the whole quote and author fit the card,
            // so long quotes shrink instead of needing to be scrolled.
            ViewThatFits(in: .vertical) {
                ForEach(Self.fittingFontSizes(from: calculatedQuoteFontSize), id: \.self) { size in
                    quoteTextBlock(
                        quote: quote,
                        quoteSize: size,
                        authorSize: min(calculatedAuthorFontSize, max(size * 0.55, 13))
                    )
                }
                // Last resort (e.g. the largest accessibility text sizes): scale down further.
                quoteTextBlock(quote: quote, quoteSize: 16, authorSize: 13, allowsScaling: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorPack.cardBackground)
                    .opacity(isPhotoBackground ? 0.0 : 0.92)
                // Photo backgrounds get a soft scrim so white text stays readable on bright images.
                if isPhotoBackground {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.32))
                }
            }
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
        .animation(.easeInOut(duration: 0.5), value: quote.id)
        .id(quote.id)
        .onTapGesture {
            showNextQuote(categoryFilter: selectedCategory == "All" ? nil : selectedCategory)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap for another quote")
        .accessibilityAction(named: "Next quote") {
            showNextQuote(categoryFilter: selectedCategory == "All" ? nil : selectedCategory)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private func quoteTextBlock(
        quote: Quote,
        quoteSize: CGFloat,
        authorSize: CGFloat,
        allowsScaling: Bool = false
    ) -> some View {
        VStack(spacing: 10) {
            Text("\"\(quote.quote)\"")
                .font(fontStyle.quoteFont(size: quoteSize))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .minimumScaleFactor(allowsScaling ? 0.5 : 1)
                // Report the full wrapped height so ViewThatFits can tell when it doesn't fit.
                .fixedSize(horizontal: false, vertical: !allowsScaling)
                .padding(.horizontal)
            Text("- \(quote.author)")
                .font(fontStyle.authorFont(size: authorSize))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
    }

    /// Font sizes from the layout's preferred size down to a readable floor, ~8% apart.
    private static func fittingFontSizes(from preferred: CGFloat) -> [CGFloat] {
        var sizes: [CGFloat] = []
        var size = preferred
        while size > 17 {
            sizes.append(size.rounded())
            size *= 0.92
        }
        sizes.append(17)
        return sizes
    }

    @ViewBuilder
    private func actionButtons(
        quote: Quote,
        categoryFilter: String?,
        isPhotoBackground: Bool,
        horizontalPadding: CGFloat
    ) -> some View {
        let isFavorite = favoritesManager.isFavorite(quote: quote)
        let favoriteGradient = LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.32, blue: 0.50),
                Color(red: 0.96, green: 0.44, blue: 0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let heartStyle: AnyShapeStyle = isFavorite ? AnyShapeStyle(favoriteGradient) : AnyShapeStyle(.white)

        let hasNote = noteManager.note(for: quote) != nil
        let nextAction = {
            showNextQuote(categoryFilter: categoryFilter)
        }

        // Falls back to icon-only buttons when labels do not fit (small screens, large text).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                actionButtonRow(quote: quote, isFavorite: isFavorite, hasNote: hasNote, heartStyle: heartStyle, showTitles: true, next: nextAction)
            }
            HStack(spacing: 12) {
                actionButtonRow(quote: quote, isFavorite: isFavorite, hasNote: hasNote, heartStyle: heartStyle, showTitles: false, next: nextAction)
            }
        }
        .padding(.bottom, 10)
        .padding(.horizontal, horizontalPadding)
    }

    @ViewBuilder
    private func actionButtonRow(
        quote: Quote,
        isFavorite: Bool,
        hasNote: Bool,
        heartStyle: AnyShapeStyle,
        showTitles: Bool,
        next: @escaping () -> Void
    ) -> some View {
        Button {
            noteDraft = noteManager.note(for: quote) ?? ""
            showingNoteEditor = true
        } label: {
            actionLabel(
                title: "Note",
                icon: Image(systemName: hasNote ? "note.text" : "pencil.and.outline"),
                iconStyle: AnyShapeStyle(.white),
                showTitle: showTitles
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasNote ? "Edit note" : "Add note")

        Button {
            let isNowFavorite = viewModel.toggleFavorite(for: quote)
            if isNowFavorite {
                personalizationManager.recordSaved(quote)
            }
        } label: {
            actionLabel(
                title: "Favorite",
                icon: Image(systemName: isFavorite ? "heart.fill" : "heart"),
                iconStyle: heartStyle,
                showTitle: showTitles
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

        Button {
            onShare(quote)
        } label: {
            actionLabel(
                title: "Share",
                icon: Image(systemName: "square.and.arrow.up"),
                iconStyle: AnyShapeStyle(.white),
                showTitle: showTitles
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share this quote")

        Button(action: next) {
            actionLabel(
                title: "Next",
                icon: Image(systemName: "arrow.forward"),
                iconStyle: AnyShapeStyle(.white),
                showTitle: showTitles
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next quote")
    }

    private func actionLabel(title: String, icon: Image, iconStyle: AnyShapeStyle, showTitle: Bool) -> some View {
        HStack(spacing: 6) {
            icon
                .foregroundStyle(iconStyle)
            if showTitle {
                Text(title)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .font(.subheadline.bold())
        .padding(.horizontal, 12)
        .frame(minWidth: 44, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isPhotoBackground ? Color.black.opacity(0.35) : colorPack.secondaryAccent.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("You are on a \(summary.currentStreak) day streak. Best streak \(summary.bestStreak).")

            StreakHistoryRow(history: summary.recentHistory, colorPack: colorPack)

            if let lastReset = summary.lastResetCompleted {
                // Reset days are stored at midnight, so describe them by day rather than by hours.
                Text("Last reset \(Self.relativeDayText(for: lastReset))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Complete today's reset to start your streak.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            if summary.needsReminderNudge, summary.lastResetCompleted != nil {
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
        .accessibilityElement(children: .contain)
    }

    static func relativeDayText(for day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: day),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }
}

struct StreakHistoryRow: View {
    let history: [EngagementTracker.DailyEngagement]
    let colorPack: ThemeColorPack

    var body: some View {
        // The last 7 days fit without scrolling, so today is always visible at the trailing edge.
        HStack(spacing: 0) {
                ForEach(Array(history.suffix(7))) { day in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(color(for: day))
                                .frame(width: 14, height: 14)

                            if day.resetCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            }
                        }
                        Text(dayLabel(for: day.date))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(historyAccessibility(for: day))
                }
        }
    }

    private func color(for day: EngagementTracker.DailyEngagement) -> Color {
        if day.resetCompleted {
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
        if day.resetCompleted {
            return "\(weekday): daily reset completed"
        }
        if day.viewed && day.favorited {
            return "\(weekday): viewed and favorited"
        }
        if day.viewed {
            return "\(weekday): viewed"
        }
        if day.favorited {
            return "\(weekday): favorited"
        }
        return "\(weekday): no activity"
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

// MARK: - Notification Permission Notice
/// Explains that reminders cannot fire and links to the app's notification settings.
struct NotificationsDeniedNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications are off", systemImage: "bell.slash.fill")
                .font(.headline)
                .foregroundColor(.orange)
            Text("Reminders won't arrive until you allow notifications for Daily Motivation in iOS Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Notification Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @Binding var dailyReminderHour: Int
    @Binding var dailyReminderMinute: Int
    @Binding var dailyReminderEnabled: Bool
    @Binding var smartMorningEnabled: Bool
    @Binding var smartMorningHour: Int
    @Binding var smartMorningMinute: Int
    @Binding var smartEveningEnabled: Bool
    @Binding var smartEveningHour: Int
    @Binding var smartEveningMinute: Int
    @Binding var selectedThemeColorPack: String
    @Binding var selectedFontStyle: String
    @Binding var selectedBackgroundStyle: String
    @Binding var customReminders: [CustomReminder]
    let notificationsDenied: Bool
    let onResetAllData: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false
    @State private var showingSupportEmailCopied = false
    @State private var analyticsEnabled = AnalyticsLogger.isCollectionEnabled
    @ObservedObject private var ads = AdsManager.shared
    private static let supportEmail = "trample_pies_4l@icloud.com"

    // Helper to create a Date from hour/minute
    private var reminderTime: Date {
        var components = DateComponents()
        components.hour = dailyReminderHour
        components.minute = dailyReminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private var morningTime: Date {
        var components = DateComponents()
        components.hour = smartMorningHour
        components.minute = smartMorningMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private var eveningTime: Date {
        var components = DateComponents()
        components.hour = smartEveningHour
        components.minute = smartEveningMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        let colorPack = ThemeColorPack(rawValue: selectedThemeColorPack) ?? .classic
        let fontStyle = QuoteFontStyle(rawValue: selectedFontStyle) ?? .rounded
        let backgroundStyle = QuoteBackgroundStyle(rawValue: selectedBackgroundStyle) ?? .classic

        return NavigationStack {
            Form {
                if notificationsDenied {
                    Section {
                        NotificationsDeniedNotice()
                    }
                }

                Section(header: Text("Daily Reminder Time")) {
                    Toggle("Daily reminder", isOn: $dailyReminderEnabled)
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
                    .disabled(!dailyReminderEnabled)
                }

                Section(header: Text("Smart Notifications")) {
                    Toggle("Morning Boost", isOn: $smartMorningEnabled)
                    DatePicker(
                        "Morning Time",
                        selection: Binding(
                            get: { morningTime },
                            set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                smartMorningHour = comps.hour ?? smartMorningHour
                                smartMorningMinute = comps.minute ?? smartMorningMinute
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!smartMorningEnabled)

                    Toggle("Wind Down", isOn: $smartEveningEnabled)
                    DatePicker(
                        "Wind Down Time",
                        selection: Binding(
                            get: { eveningTime },
                            set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                smartEveningHour = comps.hour ?? smartEveningHour
                                smartEveningMinute = comps.minute ?? smartEveningMinute
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!smartEveningEnabled)

                    Text("Pick moments when you'd like a boost or a gentle wind-down without opening the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                Section(header: Text("Custom Reminders")) {
                    if customReminders.isEmpty {
                        Text("No custom reminders yet. Add one to schedule quote nudges on specific weekdays.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach($customReminders) { $reminder in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Toggle("Enabled", isOn: $reminder.isEnabled)
                                    .accessibilityLabel("\(reminderDisplayTitle(reminder)) enabled")
                                Spacer()
                                Button(role: .destructive) {
                                    removeCustomReminder(id: reminder.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Delete \(reminderDisplayTitle(reminder)) reminder")
                            }

                            TextField("Reminder title", text: $reminder.title)
                                .textInputAutocapitalization(.words)

                            DatePicker(
                                "Time",
                                selection: timeBinding(hour: $reminder.hour, minute: $reminder.minute),
                                displayedComponents: .hourAndMinute
                            )

                            weekdayPicker(weekdays: $reminder.weekdays)

                            if reminder.weekdays.isEmpty {
                                Label("Pick at least one day so this reminder can fire.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if customReminders.count < NotificationManager.Identifier.maximumFlexibleReminderCount {
                        Button {
                            addCustomReminder()
                        } label: {
                            Label("Add reminder", systemImage: "plus.circle.fill")
                        }
                    } else {
                        Text("Up to \(NotificationManager.Identifier.maximumFlexibleReminderCount) custom reminders are supported.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

                Section {
                    Label("Favorites, notes and resets stay on this device", systemImage: "lock.shield.fill")
                        .accessibilityHint("They are never uploaded")
                    Toggle(isOn: Binding(
                        get: { analyticsEnabled },
                        set: { enabled in
                            analyticsEnabled = enabled
                            AnalyticsLogger.setCollectionEnabled(enabled)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share usage and crash data")
                            Text("Anonymous app usage and crash reports help improve Daily Motivation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if ads.privacyOptionsRequired {
                        Button {
                            ads.presentPrivacyOptions()
                        } label: {
                            Label("Ad privacy choices", systemImage: "hand.raised")
                        }
                    }
                    Button {
                        contactSupport()
                    } label: {
                        Label("Contact support", systemImage: "envelope")
                    }
                    Link(
                        destination: URL(string: "https://apps.apple.com/app/id6756123822?action=write-review")!
                    ) {
                        Label("Rate Daily Motivation", systemImage: "star")
                    }
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset all local data", systemImage: "trash")
                    }
                } header: {
                    Text("Privacy and Support")
                } footer: {
                    Text(appVersionText)
                }
            }
            .themedScreen()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset all local data?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset all data", role: .destructive, action: onResetAllData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes favorites, notes, Daily Resets, streaks, preferences, and reminders from this device.")
            }
            .alert("Support email copied", isPresented: $showingSupportEmailCopied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No mail app is set up, so \(Self.supportEmail) was copied. Paste it into any email app.")
            }
        }
    }

    /// Opens a prefilled email; falls back to copying the address when no mail app is available.
    private func contactSupport() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Daily Motivation support"),
            URLQueryItem(name: "body", value: "\n\n---\n\(appVersionText)\niOS \(UIDevice.current.systemVersion)")
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url) { opened in
            guard !opened else { return }
            UIPasteboard.general.string = Self.supportEmail
            showingSupportEmailCopied = true
        }
    }

    private var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Daily Motivation \(version) (\(build))"
    }

    private func reminderDisplayTitle(_ reminder: CustomReminder) -> String {
        let trimmed = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Daily Motivation" : trimmed
    }

    private func addCustomReminder() {
        guard customReminders.count < NotificationManager.Identifier.maximumFlexibleReminderCount else { return }
        customReminders.append(
            CustomReminder(
                title: "Daily Motivation",
                hour: dailyReminderHour,
                minute: dailyReminderMinute,
                weekdays: Set(ReminderWeekday.allCases),
                isEnabled: true
            )
        )
    }

    private func removeCustomReminder(id: String) {
        customReminders.removeAll { $0.id == id }
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = hour.wrappedValue
                components.minute = minute.wrappedValue
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour.wrappedValue = comps.hour ?? hour.wrappedValue
                minute.wrappedValue = comps.minute ?? minute.wrappedValue
            }
        )
    }

    @ViewBuilder
    private func weekdayPicker(weekdays: Binding<Set<ReminderWeekday>>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekdays")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReminderWeekday.allCases, id: \.self) { weekday in
                        let isSelected = weekdays.wrappedValue.contains(weekday)
                        Button {
                            toggleWeekday(weekday, weekdays: weekdays)
                        } label: {
                            Text(shortWeekdayLabel(for: weekday))
                                .font(.caption.weight(.semibold))
                                .frame(minWidth: 36, minHeight: 36)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isSelected ? Color.accentColor.opacity(0.45) : Color.gray.opacity(0.25),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(fullWeekdayLabel(for: weekday))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func toggleWeekday(_ weekday: ReminderWeekday, weekdays: Binding<Set<ReminderWeekday>>) {
        if weekdays.wrappedValue.contains(weekday) {
            weekdays.wrappedValue.remove(weekday)
        } else {
            weekdays.wrappedValue.insert(weekday)
        }
    }

    private func fullWeekdayLabel(for weekday: ReminderWeekday) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday.rawValue - 1))
        return symbols[index]
    }

    private func shortWeekdayLabel(for weekday: ReminderWeekday) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday.rawValue - 1))
        return symbols[index]
    }
}


// MARK: - ActivityView (UIViewControllerRepresentable)
// Definition needed for the .sheet modifier
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: ((Bool) -> Void)?
    let applicationActivities: [UIActivity]?

    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        onComplete: ((Bool) -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.onComplete = onComplete
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing needed here for basic sharing.
    }
}

// MARK: - Note Editor
private struct NoteEditorView: View {
    let quote: Quote
    let initialNote: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool

    private var trimmedNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isClearingExistingNote: Bool {
        !initialNote.isEmpty && trimmedNote.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Jot a quick takeaway for:")
                    .font(.headline)
                Text("“\(quote.quote)”")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                TextEditor(text: $noteText)
                    .padding(8)
                    .frame(minHeight: 180)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .focused($isFocused)

                if !initialNote.isEmpty {
                    Text("Clear the text to delete this note.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .themedScreen()
            .navigationTitle(initialNote.isEmpty ? "Add note" : "Edit note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Saving empty text deletes an existing note; a brand-new empty note has nothing to save.
                    Button(isClearingExistingNote ? "Delete" : "Save") { onSave(noteText) }
                        .disabled(initialNote.isEmpty && trimmedNote.isEmpty)
                }
            }
            .onAppear {
                noteText = initialNote
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
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
        engagementTracker: EngagementTracker(userDefaults: engagementStore),
        noteManager: NoteManager()
    )
}

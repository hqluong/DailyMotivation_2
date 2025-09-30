// MARK: - ContentView.swift

import SwiftUI
import UserNotifications // <-- Import UserNotifications

struct ContentView: View {
    // StateObjects for ViewModel and FavoritesManager
    @StateObject private var favoritesManager: FavoritesManager
    @StateObject private var viewModel: QuoteViewModel

    // State for navigation, sheets, notification time, and category selection
    @State private var showingFavorites = false
    @State private var isSharePresented = false
    @State private var showingSettings = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour: Int = 9
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute: Int = 0
    @AppStorage("selectedQuoteCategory") private var selectedCategory: String = "All"

    // Example categories - update as needed
    private let categories: [String] = ["All", "Success", "Creativity", "Mindfulness", "Motivation", "Happiness"]

    // Constants for font scaling (adjust these as needed based on testing)
    private let minQuoteFontSize: CGFloat = 18
    private let maxQuoteFontSize: CGFloat = 44
    // Adjust this factor based on testing across screen sizes
    private let fontHeightScaleFactor: CGFloat = 0.09

    // Initializer to inject FavoritesManager
    init() {
        let favManager = FavoritesManager()
        _favoritesManager = StateObject(wrappedValue: favManager)
        _viewModel = StateObject(wrappedValue: QuoteViewModel(favoritesManager: favManager))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient (Standard Syntax)
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                // Use GeometryReader for responsive sizing
                GeometryReader { geometry in
                    // --- Calculate Responsive Font Size ---
                    let quoteAreaMaxHeight = geometry.size.height * 0.75 // Max height for the quote card
                    let calculatedQuoteFontSize = max(minQuoteFontSize, min(quoteAreaMaxHeight * fontHeightScaleFactor, maxQuoteFontSize))
                    let calculatedAuthorFontSize = max(minQuoteFontSize * 0.6, min(calculatedQuoteFontSize * 0.5, maxQuoteFontSize * 0.6))

                    // --- Category Picker ---
                    VStack(spacing: 20) {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // --- Error Message Area ---
                        if let errorMessage = viewModel.errorMessage {
                             Text(errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                                .frame(maxHeight: geometry.size.height * 0.1) // Limit error height
                                .padding(.horizontal) // Add padding if needed
                        }

                        // --- Filtered Quote Area ---
                        let filteredQuotes: [Quote] = {
                            if selectedCategory == "All" {
                                return viewModel.allQuotes
                            } else {
                                return viewModel.allQuotes.filter { $0.category == selectedCategory }
                            }
                        }()

                        if let currentQuote = filteredQuotes.first(where: { $0.id == viewModel.currentQuote?.id }) ?? filteredQuotes.first {
                            // Quote Card VStack
                            VStack {
                                ScrollView {
                                    VStack(spacing: 10) {
                                        Spacer(minLength: 10)
                                        Text("\"\(currentQuote.quote)\"")
                                            .font(.system(size: calculatedQuoteFontSize))
                                            .fontWeight(.bold)
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.white)
                                            .padding(.horizontal)
                                        Text("- \(currentQuote.author)")
                                            .font(.system(size: calculatedAuthorFontSize))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.bottom, 5)
                                        Spacer(minLength: 10)
                                    }
                                    .frame(minHeight: quoteAreaMaxHeight * 0.9)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .clipped()
                            .frame(maxHeight: quoteAreaMaxHeight)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.easeInOut(duration: 0.5), value: currentQuote.id)
                            .id(currentQuote.id)
                            .onTapGesture {
                                // Show a new random quote from the filtered list
                                if !filteredQuotes.isEmpty {
                                    let newQuote = filteredQuotes.randomElement()
                                    if let newQuote = newQuote {
                                        viewModel.currentQuote = newQuote
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else if viewModel.errorMessage == nil {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Loading Quote...")
                                 .foregroundColor(.white)
                            Spacer()
                        }

                        // --- Action Buttons Area ---
                        // Only show if a quote is loaded
                        if let quoteForButtonCheck = filteredQuotes.first(where: { $0.id == viewModel.currentQuote?.id }) ?? filteredQuotes.first {
                             HStack(spacing: 20) {
                                Button {
                                    viewModel.toggleCurrentQuoteFavorite()
                                } label: {
                                    Label("Favorite", systemImage: favoritesManager.isFavorite(quote: quoteForButtonCheck) ? "heart.fill" : "heart")
                                        .font(.caption)
                                        .foregroundColor(favoritesManager.isFavorite(quote: quoteForButtonCheck) ? .red : .white)
                                        .accessibilityLabel(favoritesManager.isFavorite(quote: quoteForButtonCheck) ? "Remove from favorites" : "Add to favorites")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    isSharePresented = true
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .accessibilityLabel("Share this quote")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                             }
                             .padding(.bottom, 10)
                        }


                    } // End Main VStack
                    .padding(.vertical, 20) // Overall vertical padding
                    .frame(width: geometry.size.width, height: geometry.size.height) // VStack fills GeometryReader

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
            .sheet(isPresented: $isSharePresented) {
                // Use ActivityView defined below
                if let currentQuote = viewModel.currentQuote {
                    ActivityView(activityItems: ["\"\(currentQuote.quote)\" - \(currentQuote.author)"])
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(dailyReminderHour: $dailyReminderHour, dailyReminderMinute: $dailyReminderMinute)
            }
            // --- MODIFIED .onAppear ---
            .onAppear {
                // Initial quote load if needed
                if viewModel.currentQuote == nil && viewModel.errorMessage == nil {
                    viewModel.setCurrentQuoteToDaily()
                }

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

// MARK: - SettingsView
struct SettingsView: View {
    @Binding var dailyReminderHour: Int
    @Binding var dailyReminderMinute: Int
    @Environment(\.dismiss) private var dismiss

    // Helper to create a Date from hour/minute
    private var reminderTime: Date {
        var components = DateComponents()
        components.hour = dailyReminderHour
        components.minute = dailyReminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
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
     ContentView()
}

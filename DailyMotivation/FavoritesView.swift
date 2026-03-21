//
//  FavoritesView.swift
//  DailyMotivation
//
//  Created by Hung Luong on 4/1/25.
//

// MARK: - FavoritesView.swift

import Foundation
import SwiftUI

struct FavoritesView: View {
    // Observe the ViewModel to get the list of favorite quotes
    @ObservedObject var viewModel: QuoteViewModel
    // Observe the FavoritesManager to allow unfavoriting directly from this view
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var engagementTracker: EngagementTracker

    @State private var sortOption: FavoriteSortOption = .recent
    @State private var selectedCategory: String = "All"
    @State private var searchText: String = ""

    var body: some View {
        let filterCategory = selectedCategory == "All" ? nil : selectedCategory
        let allFavorites = viewModel.getFavoriteQuotes()
        let categoryOptions = ["All"] + Array(Set(allFavorites.map { $0.category })).sorted()
        let favoriteQuotes = viewModel.getFavoriteQuotes(
            sortedBy: sortOption,
            filteredBy: filterCategory,
            matching: searchText
        )
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        List {
            Section {
                winsSummaryView()
            } header: {
                Text("This week's wins")
            }

            Section {
                sortAndFilterControls(categoryOptions: categoryOptions)
            }

            if favoriteQuotes.isEmpty {
                emptyStateView(isSearching: isSearching)
            } else {
                ForEach(favoriteQuotes) { quote in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\"\(quote.quote)\"")
                            .font(.body)
                            .padding(.bottom, 2)
                            .accessibilityLabel("Quote: \(quote.quote)")
                        Text("- \(quote.author)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .accessibilityLabel("Author: \(quote.author)")
                        HStack(spacing: 10) {
                            Label(quote.category, systemImage: "bookmark.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                favoritesManager.removeFavorite(quote: quote)
                            } label: {
                                Label("Unfavorite", systemImage: "heart.slash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            favoritesManager.removeFavorite(quote: quote)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                                .accessibilityLabel("Remove from favorites")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Favorite Quotes")
        .searchable(text: $searchText, prompt: "Search quotes or authors")
    }

    @ViewBuilder
    private func sortAndFilterControls(categoryOptions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Sort", selection: $sortOption) {
                ForEach(FavoriteSortOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Picker("Category", selection: $selectedCategory) {
                ForEach(categoryOptions, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Filter favorites by category")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func winsSummaryView() -> some View {
        let summary = engagementTracker.summary
        let week = Array(summary.recentHistory.suffix(7))
        let viewedCount = week.filter { $0.viewed }.count
        let favoritedCount = week.filter { $0.favorited }.count

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(summary.currentStreak)-day streak", systemImage: "flame.fill")
                    .font(.headline)
                Spacer()
                Text("Best \(summary.bestStreak)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                statPill(icon: "book.pages.fill", text: "\(viewedCount)/7 read")
                statPill(icon: "heart.fill", text: "\(favoritedCount)/7 saved")
                statPill(icon: "square.and.arrow.up.fill", text: "\(summary.shareCompletedCount) shared")
            }

            HStack(spacing: 12) {
                achievementBadge(title: "3-day badge", unlocked: summary.currentStreak >= 3)
                achievementBadge(title: "7-day badge", unlocked: summary.currentStreak >= 7)
                achievementBadge(title: "21-day badge", unlocked: summary.currentStreak >= 21)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func emptyStateView(isSearching: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSearching {
                Text("No matching favorites")
                    .font(.headline)
                Text("Try a different quote snippet or author name, or clear your search to see all saved quotes.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No favorites yet")
                    .font(.headline)
                Text("Tap the heart on any quote to save it, or use \"Surprise me\" to discover a new favorite.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }

    private func achievementBadge(title: String, unlocked: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "seal")
                .foregroundColor(unlocked ? .green : .secondary)
            Text(title)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(unlocked ? Color.green.opacity(0.6) : Color.gray.opacity(0.25), lineWidth: 1)
        )
    }
}

// Preview requires providing mock/sample data
#Preview {
    // Create dummy data for preview
    guard
        let favoritesStore = UserDefaults(suiteName: "preview.favorites"),
        let engagementStore = UserDefaults(suiteName: "preview.engagement")
    else {
        fatalError("Unable to create preview user defaults stores.")
    }
    favoritesStore.removePersistentDomain(forName: "preview.favorites")
    engagementStore.removePersistentDomain(forName: "preview.engagement")

    let previewFavManager = FavoritesManager(userDefaults: favoritesStore)
    let previewQuote1 = Quote(quote: "Preview Favorite Quote 1", author: "Author 1")
    let previewQuote2 = Quote(quote: "Preview Favorite Quote 2", author: "Author 2")
    previewFavManager.addFavorite(quote: previewQuote1)
    previewFavManager.addFavorite(quote: previewQuote2)

    let previewTracker = EngagementTracker(userDefaults: engagementStore)
    previewTracker.resetAll()
    previewTracker.logQuoteViewed()
    previewTracker.logQuoteFavorited()
    let previewViewModel = QuoteViewModel(favoritesManager: previewFavManager, engagementTracker: previewTracker)
    // Manually add the quotes to the ViewModel's list for the preview
    previewViewModel.allQuotes = [previewQuote1, previewQuote2, Quote(quote: "Non-fav", author: "Author 3")]

    // Embed in NavigationView for the title to show
    return NavigationView {
        FavoritesView(viewModel: previewViewModel, favoritesManager: previewFavManager, engagementTracker: previewTracker)
    }
}

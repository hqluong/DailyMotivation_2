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
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var dailyResetManager: DailyResetManager
    /// Shows the tapped favorite on the home screen.
    var onOpenQuote: ((Quote) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var recentlyRemoved: Quote?
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
                NavigationLink {
                    ReflectionLibraryView(
                        resetManager: dailyResetManager,
                        noteManager: noteManager,
                        quotes: viewModel.allQuotes
                    )
                } label: {
                    Label("Reflections and notes", systemImage: "text.book.closed")
                }
            }

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
                    Button {
                        onOpenQuote?(quote)
                        dismiss()
                    } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\"\(quote.quote)\"")
                            .font(.body)
                            .padding(.bottom, 2)
                        Text("- \(quote.author)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            Label(quote.category, systemImage: "bookmark.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    }
                    .accessibilityHint("Shows this quote on the home screen")
                    .swipeActions {
                        Button(role: .destructive) {
                            remove(quote)
                        } label: {
                            Label("Remove", systemImage: "heart.slash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            remove(quote)
                        } label: {
                            Label("Remove from favorites", systemImage: "heart.slash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedScreen()
        .navigationTitle("Library")
        .overlay(alignment: .bottom) {
            if let removed = recentlyRemoved {
                undoBar(for: removed)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .searchable(text: $searchText, prompt: "Search quotes or authors")
    }

    private func remove(_ quote: Quote) {
        favoritesManager.removeFavorite(quote: quote)
        withAnimation { recentlyRemoved = quote }
        UIAccessibility.post(notification: .announcement, argument: "Removed from favorites. Undo is available.")
        let undoWindow: TimeInterval = UIAccessibility.isVoiceOverRunning ? 20 : 8
        DispatchQueue.main.asyncAfter(deadline: .now() + undoWindow) {
            if recentlyRemoved?.id == quote.id {
                withAnimation { recentlyRemoved = nil }
            }
        }
    }

    private func undoBar(for quote: Quote) -> some View {
        HStack {
            Text("Removed from favorites")
                .font(.subheadline)
            Spacer()
            Button("Undo") {
                favoritesManager.addFavorite(quote: quote)
                withAnimation { recentlyRemoved = nil }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
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
        let resetCount = week.filter { $0.resetCompleted }.count

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(summary.currentStreak)-day streak", systemImage: "flame.fill")
                    .font(.headline)
                Spacer()
                Text("Best \(summary.bestStreak)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statPill(icon: "checkmark.circle.fill", text: "\(resetCount)/7 resets")
                    statPill(icon: "book.pages.fill", text: "\(viewedCount)/7 read")
                    statPill(icon: "heart.fill", text: "\(favoritedCount)/7 saved")
                }
                VStack(alignment: .leading, spacing: 8) {
                    statPill(icon: "checkmark.circle.fill", text: "\(resetCount)/7 resets")
                    statPill(icon: "book.pages.fill", text: "\(viewedCount)/7 read")
                    statPill(icon: "heart.fill", text: "\(favoritedCount)/7 saved")
                }
            }

            Label("\(summary.shareCompletedCount) total shares", systemImage: "square.and.arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    achievementBadge(title: "3 days", unlocked: summary.bestStreak >= 3)
                    achievementBadge(title: "7 days", unlocked: summary.bestStreak >= 7)
                    achievementBadge(title: "21 days", unlocked: summary.bestStreak >= 21)
                }
                VStack(alignment: .leading, spacing: 8) {
                    achievementBadge(title: "3 days", unlocked: summary.bestStreak >= 3)
                    achievementBadge(title: "7 days", unlocked: summary.bestStreak >= 7)
                    achievementBadge(title: "21 days", unlocked: summary.bestStreak >= 21)
                }
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
                Text("Tap Favorite on any quote to save it, or tap Next on the home screen to discover more.")
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
        .background(.tint.opacity(0.14))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func achievementBadge(title: String, unlocked: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "seal")
                .foregroundColor(unlocked ? .green : .secondary)
            Text(title)
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) streak badge, \(unlocked ? "unlocked" : "locked")")
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(unlocked ? Color.green.opacity(0.6) : Color.gray.opacity(0.25), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
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
    let previewNotes = NoteManager(userDefaults: engagementStore)
    let previewResets = DailyResetManager(userDefaults: engagementStore)
    previewTracker.resetAll()
    previewTracker.logQuoteViewed()
    previewTracker.logQuoteFavorited()
    let previewViewModel = QuoteViewModel(favoritesManager: previewFavManager, engagementTracker: previewTracker)
    // Manually add the quotes to the ViewModel's list for the preview
    previewViewModel.allQuotes = [previewQuote1, previewQuote2, Quote(quote: "Non-fav", author: "Author 3")]

    // Embed in NavigationView for the title to show
    return NavigationView {
        FavoritesView(
            viewModel: previewViewModel,
            favoritesManager: previewFavManager,
            engagementTracker: previewTracker,
            noteManager: previewNotes,
            dailyResetManager: previewResets
        )
    }
}

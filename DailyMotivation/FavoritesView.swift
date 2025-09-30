//
//  FavoritesView.swift
//  DailyMotivation
//
//  Created by Hung Luong on 4/1/25.
//

// MARK: - FavoritesView.swift

import SwiftUI

struct FavoritesView: View {
    // Observe the ViewModel to get the list of favorite quotes
    @ObservedObject var viewModel: QuoteViewModel
    // Observe the FavoritesManager to allow unfavoriting directly from this view
    @ObservedObject var favoritesManager: FavoritesManager

    var body: some View {
        // Get the current list of favorite quotes from the ViewModel
        let favoriteQuotes = viewModel.getFavoriteQuotes()

        List {
            if favoriteQuotes.isEmpty {
                Text("You haven't favorited any quotes yet.")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No favorite quotes")
            } else {
                ForEach(favoriteQuotes) { quote in
                    VStack(alignment: .leading) {
                        Text("\"\(quote.quote)\"")
                            .font(.body)
                            .padding(.bottom, 2)
                            .accessibilityLabel("Quote: \(quote.quote)")
                        Text("- \(quote.author)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .accessibilityLabel("Author: \(quote.author)")
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
        .navigationTitle("Favorite Quotes")
    }
}

// Preview requires providing mock/sample data
#Preview {
    // Create dummy data for preview
    let previewFavManager = FavoritesManager()
    let previewQuote1 = Quote(quote: "Preview Favorite Quote 1", author: "Author 1")
    let previewQuote2 = Quote(quote: "Preview Favorite Quote 2", author: "Author 2")
    previewFavManager.addFavorite(quote: previewQuote1)
    previewFavManager.addFavorite(quote: previewQuote2)

    let previewViewModel = QuoteViewModel(favoritesManager: previewFavManager)
    // Manually add the quotes to the ViewModel's list for the preview
    previewViewModel.allQuotes = [previewQuote1, previewQuote2, Quote(quote: "Non-fav", author: "Author 3")]

    // Embed in NavigationView for the title to show
    return NavigationView {
        FavoritesView(viewModel: previewViewModel, favoritesManager: previewFavManager)
    }
}

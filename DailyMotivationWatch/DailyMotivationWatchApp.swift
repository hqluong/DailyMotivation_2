// MARK: - DailyMotivationWatchApp.swift

import SwiftUI

@main
struct DailyMotivationWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchQuoteView()
        }
    }
}

/// Today's quote, with Next to browse more. Returns to today's quote each time the app opens.
struct WatchQuoteView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var offset = 0

    private var quote: WatchQuote { WatchQuoteStore.quote(offset: offset) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label(offset == 0 ? "Today" : "More", systemImage: offset == 0 ? "sun.max.fill" : "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)

                Text("“\(quote.text)”")
                    .font(.system(.headline, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    offset += 1
                } label: {
                    Label("Next", systemImage: "arrow.forward")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)

                if offset != 0 {
                    Button("Back to today") { offset = 0 }
                        .font(.footnote)
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.54, blue: 0.16).opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { offset = 0 }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    WatchQuoteView()
}

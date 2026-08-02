import SwiftUI
import UIKit

struct QuoteShareCard: View {
    let quote: Quote
    let colorPack: ThemeColorPack
    let fontStyle: QuoteFontStyle
    let backgroundStyle: QuoteBackgroundStyle

    var body: some View {
        ZStack {
            QuoteBackgroundView(style: backgroundStyle, colorPack: colorPack)

            Color.black.opacity(backgroundStyle.isPhotoBackground ? 0.2 : 0.08)

            VStack(alignment: .leading, spacing: 24) {
                Label("Daily Motivation", systemImage: "quote.opening")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text("\"\(quote.quote)\"")
                    .font(fontStyle.quoteFont(size: 38))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(9)
                    .minimumScaleFactor(0.62)

                Text("- \(quote.author)")
                    .font(fontStyle.authorFont(size: 20))
                    .foregroundStyle(.white.opacity(0.86))

                Spacer()

                Text("Daily Motivation: Quotes")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(42)
        }
        .frame(width: 540, height: 675)
        .clipped()
    }
}

@MainActor
enum QuoteShareCardRenderer {
    static func render(
        quote: Quote,
        colorPack: ThemeColorPack,
        fontStyle: QuoteFontStyle,
        backgroundStyle: QuoteBackgroundStyle
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: QuoteShareCard(
                quote: quote,
                colorPack: colorPack,
                fontStyle: fontStyle,
                backgroundStyle: backgroundStyle
            )
        )
        renderer.scale = 2
        return renderer.uiImage
    }
}

import SwiftUI

// MARK: - AppIconView
/// A modern, layered app icon that matches the app's blue→purple brand gradient
/// and features a prominent SF Symbol. Export from the previews at 1024×1024.
struct AppIconView: View {
    enum Symbol: String, CaseIterable {
        case quote = "quote.bubble.fill"
        case flame = "flame.fill"
        case star = "star.fill"
    }

    var symbol: Symbol = .quote

    // Brand gradient (aligns with ContentView)
    var gradientColors: [Color] = [
        Color.blue, Color.purple
    ]

    // Corner radius factor closely approximates iOS icon mask
    private let cornerRadiusFactor: CGFloat = 0.223

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let cornerRadius = size * cornerRadiusFactor

            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle radial highlight for depth
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.25), .clear]),
                            center: .topLeading,
                            startRadius: size * 0.05,
                            endRadius: size * 0.7
                        )
                    )
                    .blendMode(.screen)

                // Soft vignette for focus
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: max(1, size * 0.01))
                    .shadow(color: .black.opacity(0.18), radius: size * 0.06, x: 0, y: size * 0.03)

                // Symbol backdrop (subtle orb)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.58, height: size * 0.58)
                    .shadow(color: .black.opacity(0.25), radius: size * 0.06, x: 0, y: size * 0.03)

                // Primary symbol
                Image(systemName: symbol.rawValue)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .shadow(color: .black.opacity(0.35), radius: size * 0.05, x: 0, y: size * 0.025)
            }
            .compositingGroup()
            .drawingGroup()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Variants Helper
struct AppIconVariant: Identifiable {
    let id = UUID()
    let name: String
    let view: AnyView
}

// MARK: - Previews
#Preview("App Icon 1024 (Quote)") {
    AppIconView(symbol: .quote)
        .frame(width: 1024, height: 1024)
        .padding(0)
        .background(Color.black.opacity(0.1))
}

#Preview("App Icon 1024 (Flame)") {
    AppIconView(symbol: .flame)
        .frame(width: 1024, height: 1024)
        .padding(0)
        .background(Color.black.opacity(0.1))
}

#Preview("Sizes: 180 • 120 • 60") {
    VStack(spacing: 24) {
        AppIconView(symbol: .quote)
            .frame(width: 180, height: 180)
        AppIconView(symbol: .flame)
            .frame(width: 120, height: 120)
        AppIconView(symbol: .star)
            .frame(width: 60, height: 60)
    }
    .padding()
    .background(Color(white: 0.1))
}

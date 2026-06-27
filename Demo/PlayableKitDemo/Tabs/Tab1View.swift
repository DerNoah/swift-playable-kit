import PlayableKit
import SwiftUI

// MARK: - Tab 1: Cards + Buttons

struct Tab1View: View {
    // Stable IDs — must be constants, not generated inline
    private let card1ID = "tab1-card-1"
    private let card2ID = "tab1-card-2"
    private let buttonID = "tab1-buy-button"

    @State private var purchased = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Navigation bar area
                Text("Discover")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .playable(kind: .navigationBar, id: "tab1-navbar")

                // Card 1
                ProductCard(
                    title: "Summer Collection",
                    subtitle: "New arrivals",
                    color: .indigo
                )
                .playable(kind: .card, id: card1ID, options: InteractionOptions(priority: 1))

                // Card 2
                ProductCard(
                    title: "Bestsellers",
                    subtitle: "Most loved items",
                    color: .pink
                )
                .playable(kind: .card, id: card2ID)

                // Button
                Button(action: { purchased.toggle() }) {
                    Label(
                        purchased ? "Added to Cart ✓" : "Add to Cart",
                        systemImage: purchased ? "checkmark.circle.fill" : "cart.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(purchased ? Color.green : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .playable(kind: .button, id: buttonID, options: InteractionOptions(canJump: true, priority: 3))

                Spacer(minLength: 80)
            }
            .padding(.top)
        }
    }
}

// MARK: - ProductCard

private struct ProductCard: View {
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.3))
                .frame(height: 140)
                .overlay(
                    Image(systemName: "tshirt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .foregroundStyle(color)
                )

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}

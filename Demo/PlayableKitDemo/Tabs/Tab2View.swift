import PlayableKit
import SwiftUI

// MARK: - Tab 2: Navigation Stack + Custom Views

struct Tab2View: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Featured") {
                    ForEach(Item.samples) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRow(item: item)
                        }
                    }
                }

                Section("Custom View") {
                    CustomInteractableView()
                        .frame(height: 100)
                        .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Catalog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "bell")
                    }
                    .playable(kind: .button, id: "tab2-bell-button")
                }
            }
        }
    }
}

// MARK: - Item model

private struct Item: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color

    static let samples: [Item] = [
        Item(id: "item-1", name: "Hoodie", icon: "tshirt", color: .blue),
        Item(id: "item-2", name: "Sneakers", icon: "shoe", color: .orange),
        Item(id: "item-3", name: "Cap", icon: "purchased.circle", color: .purple),
    ]
}

// MARK: - ItemRow

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(item.color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: item.icon)
                        .foregroundStyle(item.color)
                )
            Text(item.name)
                .font(.body)
        }
        .playable(kind: .card, id: "row-\(item.id)")
    }
}

// MARK: - ItemDetailView

private struct ItemDetailView: View {
    let item: Item

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 20)
                .fill(item.color.opacity(0.25))
                .frame(height: 260)
                .overlay(
                    Image(systemName: item.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundStyle(item.color)
                )
                .padding(.horizontal)
                .playable(kind: .card, id: "detail-card-\(item.id)", options: InteractionOptions(priority: 2))

            Button("Buy Now") {}
                .buttonStyle(.borderedProminent)
                .playable(kind: .button, id: "detail-buy-\(item.id)")
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - CustomInteractableView

private struct CustomInteractableView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.teal, .mint],
                startPoint: .leading,
                endPoint: .trailing
            )
            Text("Custom Playable View")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .playable(kind: .custom("banner"), id: "tab2-custom-banner")
    }
}

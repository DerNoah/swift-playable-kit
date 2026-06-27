import PlayableKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab1View()
                .tabItem { Label("Cards", systemImage: "square.stack") }

            Tab2View()
                .tabItem { Label("Nav", systemImage: "list.bullet") }

            UIKitTabWrapper()
                .tabItem { Label("UIKit", systemImage: "square.and.pencil") }
        }
        // Register the tab bar — character will walk along it
        .playable(kind: .tabBar, id: "main-tabbar", options: InteractionOptions(canSit: true, priority: 2))
    }
}

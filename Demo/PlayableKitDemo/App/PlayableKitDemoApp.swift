import PlayableKit
import SwiftUI

@main
struct PlayableKitDemoApp: App {
    init() {
        // Start the engine with the bundled example chameleon — character appears immediately.
        // Supply your own art instead with: SpriteSet(directory: mySpritesURL)
        PlayableEngine.shared.start(spriteSet: .exampleChameleon)

        // Trigger an interaction every 6 seconds (default)
        PlayableEngine.shared.interactionInterval = 6
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

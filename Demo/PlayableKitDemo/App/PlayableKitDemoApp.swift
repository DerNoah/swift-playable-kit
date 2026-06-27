import PlayableKit
import SwiftUI

@main
struct PlayableKitDemoApp: App {
    init() {
        // Optional: supply a custom sprite set (a directory of PNG frames)
        // PlayableEngine.shared.start(spriteSet: SpriteSet(directory: mySpritesURL))

        // Start the engine — character appears immediately
        PlayableEngine.shared.start()

        // Trigger an interaction every 6 seconds (default)
        PlayableEngine.shared.interactionInterval = 6
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

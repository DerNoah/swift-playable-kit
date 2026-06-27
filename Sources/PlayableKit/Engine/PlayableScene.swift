import SpriteKit
import UIKit

// MARK: - PlayableScene

/// The `SKScene` that hosts the character.
///
/// - Clear background so the app UI shows through.
/// - `scaleMode = .resizeFill` so the scene always matches the SKView bounds.
/// - Exposes `characterController` after `didMove(to:)`.
@MainActor
final class PlayableScene: SKScene {
    public private(set) var characterController: CharacterController?

    private let characterNode = PlayableCharacterNode()

    // MARK: - Init

    public override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func didMove(to view: SKView) {
        super.didMove(to: view)

        // Start off-screen (left border) — engine schedules the first entry with a random delay
        characterNode.position = CGPoint(x: -100, y: 60)
        addChild(characterNode)

        characterController = CharacterController(node: characterNode, scene: self)
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Keep character within the new bounds after rotation
        characterNode.position = CGPoint(
            x: characterNode.position.x.clamped(to: 20...(size.width - 20)),
            y: characterNode.position.y.clamped(to: 20...(size.height - 20))
        )
    }
}

// MARK: - Comparable clamp

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

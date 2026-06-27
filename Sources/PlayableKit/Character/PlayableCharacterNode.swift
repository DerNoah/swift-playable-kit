import SpriteKit
import UIKit

// MARK: - PlayableCharacterNode

/// An `SKSpriteNode` that renders the interactive character.
///
/// Textures are loaded from a ``SpriteSet`` directory when one is applied;
/// otherwise a programmatically drawn placeholder is used so the system works
/// without any asset files.
///
/// Texture naming convention in the sprite-set directory:
///   `idle_00`, `idle_01`, …
///   `walk_00`, `walk_01`, …
///   `rolling_00`, …      (walkingOnTop)
///   `attention_00`, …    (sitting)
///   `fainting_00`, …     (jumping)
///   `attacking_00`, …    (interacting)
///   `wave_00`, `wave_01`, …
@MainActor
final class PlayableCharacterNode: SKSpriteNode {
    // MARK: - Configuration

    /// Display scale applied on top of the texture's native pixel size.
    /// 2.5 gives crisp pixel-art scaling; increase for larger screens.
    public static var displayScale: CGFloat = 2.5

    // MARK: - Private state

    private var idleTextures: [SKTexture] = [] // idle_
    private var walkTextures: [SKTexture] = [] // walk_
    private var rollingTextures: [SKTexture] = [] // rolling_  (walkingOnTop)
    private var attentionTextures: [SKTexture] = [] // attention_ (sitting)
    private var faintingTextures: [SKTexture] = [] // fainting_  (jumping)
    private var attackingTextures: [SKTexture] = [] // attacking_ (interacting)
    private var waveTextures: [SKTexture] = [] // wave_

    private static let fallbackSize = CGSize(width: 32, height: 40)
    private static let animationKey = "character_anim"

    // MARK: - Init

    public init() {
        let placeholder = Self.makePlaceholderTexture()
        super.init(texture: placeholder, color: .clear, size: Self.fallbackSize)
        zPosition = 1000
        playIdle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - State Machine

    /// Forces the walk animation and direction flip regardless of current state.
    /// Called by `CharacterController` at the start of every move so the animation
    /// is always fresh even when the direction hasn't changed.
    func beginWalk(direction: CGFloat) {
        xScale = direction >= 0 ? abs(xScale) : -abs(xScale)
        removeAction(forKey: Self.animationKey)
        playWalk()
    }

    /// Transitions the node to a new animation state. Call from `CharacterController` only.
    func transition(to state: AnimationState) {
        removeAction(forKey: Self.animationKey)

        switch state {
            case .idle:
                playIdle()
            case let .walking(direction):
                xScale = direction >= 0 ? abs(xScale) : -abs(xScale)
                playWalk()
            case .jumping:
                playJump()
            case .sitting:
                playSit()
            case .interacting:
                playInteract()
            case .waving:
                playWave()
            case .walkingOnTop:
                playWalkOnTop()
        }
    }

    // MARK: - Animations

    private func playIdle() {
        if idleTextures.isEmpty {
            run(proceduralIdle(), withKey: Self.animationKey)
        } else {
            loop(textures: idleTextures, fps: 3)
        }
    }

    private func playWalk() {
        if walkTextures.isEmpty {
            run(proceduralWalk(), withKey: Self.animationKey)
        } else {
            loop(textures: walkTextures, fps: 10)
        }
    }

    private func playJump() {
        if faintingTextures.isEmpty { return }
        let anim = SKAction.animate(with: faintingTextures, timePerFrame: 0.15, resize: true, restore: true)
        run(SKAction.repeatForever(anim), withKey: Self.animationKey)
    }

    private func playSit() {
        if attentionTextures.isEmpty { return }
        loop(textures: attentionTextures, fps: 3)
    }

    private func playWalkOnTop() {
        if rollingTextures.isEmpty {
            playWalk()
        } else {
            loop(textures: rollingTextures, fps: 10)
        }
    }

    private func playInteract() {
        if attackingTextures.isEmpty {
            run(proceduralWave(), withKey: Self.animationKey)
        } else {
            let anim = SKAction.animate(with: attackingTextures, timePerFrame: 0.1, resize: true, restore: true)
            run(SKAction.repeatForever(anim), withKey: Self.animationKey)
        }
    }

    private func playWave() {
        if waveTextures.isEmpty {
            run(proceduralWave(), withKey: Self.animationKey)
        } else {
            let anim = SKAction.animate(with: waveTextures, timePerFrame: 1 / 8, resize: true, restore: false)
            run(anim, withKey: Self.animationKey)
        }
    }

    private func loop(textures: [SKTexture], fps: TimeInterval) {
        let anim = SKAction.animate(with: textures, timePerFrame: 1 / fps, resize: true, restore: false)
        run(SKAction.repeatForever(anim), withKey: Self.animationKey)
    }

    // MARK: - Procedural fallback animations (no atlas required)

    private func proceduralIdle() -> SKAction {
        let up = SKAction.moveBy(x: 0, y: 2, duration: 0.5)
        up.timingMode = .easeInEaseOut
        return SKAction.repeatForever(SKAction.sequence([up, up.reversed()]))
    }

    private func proceduralWalk() -> SKAction {
        let up = SKAction.moveBy(x: 0, y: 2, duration: 0.12)
        up.timingMode = .linear
        return SKAction.repeatForever(SKAction.sequence([up, up.reversed()]))
    }

    private func proceduralWave() -> SKAction {
        let right = SKAction.rotate(byAngle: 0.25, duration: 0.15)
        let left = SKAction.rotate(byAngle: -0.25, duration: 0.15)
        return SKAction.repeatForever(SKAction.sequence([right, left, left, right]))
    }

    // MARK: - Sprite set

    /// Loads textures from the given sprite set directory and restarts the idle animation.
    func apply(spriteSet: SpriteSet) {
        idleTextures = textures(prefix: "idle_", in: spriteSet.directory)
        walkTextures = textures(prefix: "walk_", in: spriteSet.directory)
        rollingTextures = textures(prefix: "rolling_", in: spriteSet.directory)
        attentionTextures = textures(prefix: "attention_", in: spriteSet.directory)
        faintingTextures = textures(prefix: "fainting_", in: spriteSet.directory)
        attackingTextures = textures(prefix: "attacking_", in: spriteSet.directory)
        waveTextures = textures(prefix: "wave_", in: spriteSet.directory)

        if let first = idleTextures.first {
            texture = first
            size = CGSize(
                width: first.size().width * Self.displayScale,
                height: first.size().height * Self.displayScale
            )
        }

        removeAction(forKey: Self.animationKey)
        playIdle()
    }

    /// Loads sequentially numbered frames (`prefix00.png`, `prefix01.png`, …) from a directory URL.
    /// Stops at the first missing frame. Nearest-neighbor filtering for crisp pixel art.
    private func textures(prefix: String, in directory: URL) -> [SKTexture] {
        var result: [SKTexture] = []
        var index = 0
        while true {
            let name = "\(prefix)\(String(format: "%02d", index))"
            let url = directory.appendingPathComponent("\(name).png")
            guard let image = UIImage(contentsOfFile: url.path) else { break }
            let texture = SKTexture(image: image)
            texture.filteringMode = .nearest
            result.append(texture)
            index += 1
        }
        return result
    }

    // MARK: - Placeholder texture

    /// Draws a tiny pixel-art person programmatically.
    static func makePlaceholderTexture() -> SKTexture {
        let size = Self.fallbackSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            // Head
            UIColor.systemIndigo.setFill()
            UIBezierPath(ovalIn: CGRect(x: 8, y: 0, width: 16, height: 16)).fill()

            // Torso
            UIBezierPath(rect: CGRect(x: 10, y: 15, width: 12, height: 14)).fill()

            // Arms
            UIBezierPath(rect: CGRect(x: 4, y: 16, width: 6, height: 3)).fill()
            UIBezierPath(rect: CGRect(x: 22, y: 16, width: 6, height: 3)).fill()

            // Legs
            UIColor.systemBlue.setFill()
            UIBezierPath(rect: CGRect(x: 10, y: 29, width: 5, height: 11)).fill()
            UIBezierPath(rect: CGRect(x: 17, y: 29, width: 5, height: 11)).fill()

            // Eyes
            UIColor.black.setFill()
            UIBezierPath(ovalIn: CGRect(x: 12, y: 5, width: 2, height: 2)).fill()
            UIBezierPath(ovalIn: CGRect(x: 18, y: 5, width: 2, height: 2)).fill()

            // Smile
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 12, y: 12))
            smile.addQuadCurve(to: CGPoint(x: 20, y: 12), controlPoint: CGPoint(x: 16, y: 15))
            UIColor.black.setStroke()
            smile.lineWidth = 1
            smile.stroke()
        }
        return SKTexture(image: image)
    }
}

import SpriteKit
import UIKit

// MARK: - AnimationState

/// All possible states for the character animation state machine.
enum AnimationState: Equatable {
    case idle
    case walking(direction: CGFloat) // +1 = right, -1 = left
    case jumping
    case sitting
    case interacting
    case waving
    case walkingOnTop
}

// MARK: - CharacterMachineState

private enum CharacterMachineState: Equatable {
    case offScreen
    case exitingForEntry(targetInfo: PlayableViewInfo) // walking to exit border before re-entry
    case exitingToLeave // walking to exit border to leave entirely
    case teleporting(targetInfo: PlayableViewInfo) // off-screen position reset (synchronous, transient)
    case entering(targetInfo: PlayableViewInfo) // walking on-screen toward target
    case movingTo(targetInfo: PlayableViewInfo) // already on-screen, walking to target
    case walkingOnTop // walking along top edge of a view
    case wandering // random on-screen movement
    case idle
    case sitting
    case jumping
    case interacting // playing the interact animation on a view
    case waving(restoreTo: RestorationTarget) // carries restore target for handleTap

    enum RestorationTarget: Equatable {
        case idle, sitting, jumping
    }
}

// MARK: - CharacterController

/// Drives the `PlayableCharacterNode` — translating high-level commands
/// ("move to this view", "perform this interaction") into `SKAction` sequences
/// and `AnimationState` transitions.
@MainActor
final class CharacterController {
    public let node: PlayableCharacterNode

    private weak var scene: SKScene?

    // Walk speed in scene points per second
    private let walkSpeed: CGFloat = 120

    private var machineState: CharacterMachineState = .offScreen

    private static let moveActionKey = "character_move"
    private static let directionActionKey = "character_direction"

    /// ID of the registered view the character is currently walking toward.
    /// `nil` when not targeting a specific element.
    var currentTargetID: String? {
        switch machineState {
            case let .exitingForEntry(info), let .teleporting(info),
                 let .entering(info), let .movingTo(info):
                return info.id
            default: return nil
        }
    }

    /// `true` once the character has fully walked off-screen via `exitToNearestBorder`.
    /// Reset to `false` when re-entering via `enterFromBorderAndMove`.
    /// Starts `true` because the character begins off-screen.
    var isOffScreen: Bool {
        if case .offScreen = machineState { return true }
        return false
    }

    /// Creates a controller wired to the given node and scene.
    ///
    /// Called by ``PlayableScene`` in `didMove(to:)`. You should not create this directly.
    public init(node: PlayableCharacterNode, scene: SKScene) {
        self.node = node
        self.scene = scene
    }

    // MARK: - Public Commands

    /// Walks the character to a UI element and performs its preferred interaction.
    /// If the direct path crosses the screen centre the character exits through the
    /// nearest border, teleports to the border nearest the target, then walks in.
    public func moveToView(_ info: PlayableViewInfo, completion: (() -> Void)? = nil) {
        guard let scene else { return }

        let sceneRect = uiRectToScene(info.frame, scene: scene)
        let targetPoint = standingPoint(above: sceneRect)

        let arrive: () -> Void = { [weak self] in
            guard let self else { return }
            self.performInteraction(info.kind.preferredInteraction, on: info)
            completion?()
        }

        // Border-teleport when the straight-line path crosses the screen centre
        // horizontally OR vertically.
        let crossesCenter =
            (node.position.x - scene.size.width / 2) * (targetPoint.x - scene.size.width / 2) < 0 ||
            (node.position.y - scene.size.height / 2) * (targetPoint.y - scene.size.height / 2) < 0
        if crossesCenter {
            exitThenEnter(to: targetPoint, targetInfo: info, scene: scene, completion: arrive)
        } else {
            let direction: CGFloat = targetPoint.x >= node.position.x ? 1 : -1
            startMove(
                to: targetPoint,
                direction: direction,
                duration: walkDuration(from: node.position, to: targetPoint),
                entering: .movingTo(targetInfo: info),
                completion: arrive
            )
        }
    }

    /// Walks from the current position to the nearest exit border, then teleports (off-screen)
    /// to the border nearest `info`, then walks on-screen to `info`.
    /// The teleport is invisible because it only happens after the character has exited.
    /// `completion` fires once the character arrives and begins its interaction.
    public func enterFromBorderAndMove(to info: PlayableViewInfo, completion: (() -> Void)? = nil) {
        guard let scene else { return }
        let sceneRect = uiRectToScene(info.frame, scene: scene)
        let target = standingPoint(above: sceneRect)
        let entryPoint = nearestBorderPoint(to: target, in: scene)

        let exitPoint = nearestBorderPoint(to: node.position, in: scene)
        let exitDirection = borderDirection(from: node.position, to: exitPoint)

        startMove(
            to: exitPoint,
            direction: exitDirection,
            duration: walkDuration(from: node.position, to: exitPoint),
            entering: .exitingForEntry(targetInfo: info)
        ) { [weak self] in
            guard let self else { return }
            // Now off-screen — teleport to the border nearest the target
            enter(.teleporting(targetInfo: info))
            node.position = entryPoint
            let entryDirection = borderDirection(from: entryPoint, to: target)
            startMove(
                to: target,
                direction: entryDirection,
                duration: walkDuration(from: entryPoint, to: target),
                entering: .entering(targetInfo: info)
            ) { [weak self] in
                guard let self else { return }
                performInteraction(info.kind.preferredInteraction, on: info)
                completion?()
            }
        }
    }

    /// Walks the character off-screen through the nearest border.
    /// Sets `isOffScreen = true` once fully exited.
    /// `completion` fires once the character is fully off-screen.
    public func exitToNearestBorder(completion: (() -> Void)? = nil) {
        guard let scene else { return }
        let exitPoint = nearestBorderPoint(to: node.position, in: scene)
        let direction = borderDirection(from: node.position, to: exitPoint)

        startMove(
            to: exitPoint,
            direction: direction,
            duration: walkDuration(from: node.position, to: exitPoint),
            entering: .exitingToLeave
        ) { [weak self] in
            guard let self else { return }
            enter(.offScreen)
            completion?()
        }
    }

    /// Walks the character along the top edge of a UI element.
    /// The character is already positioned at the correct y by `moveToView`, so this
    /// only moves horizontally to the far end — no snapping or teleporting.
    public func walkAlongTopEdge(of info: PlayableViewInfo) {
        guard let scene else { return }
        let sceneRect = uiRectToScene(info.frame, scene: scene)

        let y = sceneRect.maxY + node.size.height / 2
        let endX = sceneRect.maxX - node.size.width / 2
        guard endX > sceneRect.minX else { return }

        let target = CGPoint(x: endX, y: y)
        let direction: CGFloat = endX >= node.position.x ? 1 : -1
        let duration = walkDuration(from: node.position, to: target)

        startMove(to: target, direction: direction, duration: duration, entering: .walkingOnTop) { [weak self] in
            self?.enter(.idle)
        }
    }

    /// Executes an interaction without moving (character is already positioned).
    /// Always fires the view's `onInteract` callback before dispatching.
    public func performInteraction(_ interaction: CharacterInteraction, on info: PlayableViewInfo) {
        PlayableRegistry.shared.fireInteractCallback(id: info.id)
        switch interaction {
            case .jump: doJump()
            case .sit: doSit()
            case .walk: walkAlongTopEdge(of: info)
            case .walkOnTop: walkAlongTopEdge(of: info)
            case .wave: doWave()
            case .interact: doInteract()
            case .idle: enter(.idle)
        }
    }

    /// Interrupts current animation, plays wave, then restores the prior non-walking state.
    /// Ignored if a wave is already in progress.
    public func handleTap() {
        if case .waving = machineState { return }

        let restoreTo: CharacterMachineState.RestorationTarget
        switch machineState {
            case .sitting: restoreTo = .sitting
            case .jumping: restoreTo = .jumping
            default: restoreTo = .idle
        }

        node.removeAction(forKey: Self.moveActionKey)
        node.removeAction(forKey: Self.directionActionKey)
        node.zRotation = 0

        enter(.waving(restoreTo: restoreTo))
        let snapshot = machineState
        node.run(.wait(forDuration: 2)) { [weak self] in
            guard let self, self.machineState == snapshot else { return }
            switch restoreTo {
                case .idle: self.enter(.idle)
                case .sitting: self.enter(.sitting)
                case .jumping: self.enter(.jumping)
            }
        }
    }

    /// Immediately cancels movement and returns to idle.
    public func returnToIdle() {
        node.removeAllActions()
        enter(.idle)
    }

    /// Walks to a random position on screen, then performs a random idle action.
    /// Used as fallback when no views are registered in `PlayableRegistry`.
    public func wander() {
        guard let scene else { return }

        let margin = node.size.width
        let minX = margin
        let maxX = scene.size.width - margin
        guard maxX > minX else { return }

        // Bias strongly toward the edges: 75% chance to pick a target in the
        // leftmost or rightmost 20% of the screen, 25% chance for anywhere.
        let edgeZone = (maxX - minX) * 0.2
        let targetX: CGFloat
        if Float.random(in: 0..<1) < 0.75 {
            if Bool.random() {
                targetX = CGFloat.random(in: minX...(minX + edgeZone))
            } else {
                targetX = CGFloat.random(in: (maxX - edgeZone)...maxX)
            }
        } else {
            targetX = CGFloat.random(in: minX...maxX)
        }

        let groundY = node.size.height / 2 + 4
        let target = CGPoint(x: targetX, y: groundY)
        let direction: CGFloat = target.x >= node.position.x ? 1 : -1
        let duration = walkDuration(from: node.position, to: target)

        startMove(to: target, direction: direction, duration: duration, entering: .wandering) { [weak self] in
            guard let self else { return }
            let roll = Int.random(in: 0...2)
            switch roll {
                case 0: self.doSit()
                case 1: self.doWave()
                default: self.enter(.idle)
            }
        }
    }

    // MARK: - Border teleport

    /// Exits through the border nearest the character, teleports to the border
    /// nearest `target`, then walks to `target`.
    private func exitThenEnter(to target: CGPoint, targetInfo: PlayableViewInfo, scene: SKScene, completion: @escaping () -> Void) {
        let exitPoint = nearestBorderPoint(to: node.position, in: scene)
        let exitDir = borderDirection(from: node.position, to: exitPoint)

        startMove(
            to: exitPoint,
            direction: exitDir,
            duration: walkDuration(from: node.position, to: exitPoint),
            entering: .exitingForEntry(targetInfo: targetInfo)
        ) { [weak self] in
            guard let self else { return }
            let entryPoint = self.nearestBorderPoint(to: target, in: scene)
            enter(.teleporting(targetInfo: targetInfo))
            self.node.position = entryPoint
            let entryDir = self.borderDirection(from: entryPoint, to: target)
            self.startMove(
                to: target,
                direction: entryDir,
                duration: self.walkDuration(from: entryPoint, to: target),
                entering: .entering(targetInfo: targetInfo),
                completion: completion
            )
        }
    }

    /// Returns the off-screen point just outside the border of `scene` that is
    /// closest to `position` (any of the four edges).
    private func nearestBorderPoint(to position: CGPoint, in scene: SKScene) -> CGPoint {
        let w = scene.size.width, h = scene.size.height
        let mw = node.size.width, mh = node.size.height
        let dLeft = position.x
        let dRight = w - position.x
        let dBottom = position.y
        let dTop = h - position.y
        let minDist = min(dLeft, dRight, dBottom, dTop)
        if minDist == dLeft { return CGPoint(x: -mw, y: position.y) }
        if minDist == dRight { return CGPoint(x: w + mw, y: position.y) }
        if minDist == dBottom { return CGPoint(x: position.x, y: -mh) }
        return CGPoint(x: position.x, y: h + mh)
    }

    /// Returns the xScale direction for a move from `from` to `to`.
    /// Falls back to the node's current facing when movement is purely vertical.
    private func borderDirection(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        if dx != 0 { return dx > 0 ? 1 : -1 }
        return node.xScale >= 0 ? 1 : -1
    }

    // MARK: - Private Interactions

    private func doJump() {
        enter(.jumping)
        let snapshot = machineState
        let up = SKAction.moveBy(x: 0, y: 32, duration: 0.22)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -32, duration: 0.22)
        down.timingMode = .easeIn
        node.run(SKAction.sequence([up, down])) { [weak self] in
            guard let self, self.machineState == snapshot else { return }
            self.enter(.idle)
        }
    }

    private func doSit() {
        enter(.sitting)
        let snapshot = machineState
        node.run(.wait(forDuration: 4)) { [weak self] in
            guard let self, self.machineState == snapshot else { return }
            self.enter(.idle)
        }
    }

    private func doWave() {
        enter(.waving(restoreTo: .idle))
        let snapshot = machineState
        node.run(.wait(forDuration: 2)) { [weak self] in
            guard let self, self.machineState == snapshot else { return }
            self.enter(.idle)
        }
    }

    private func doInteract() {
        enter(.interacting)
        let snapshot = machineState
        node.run(.wait(forDuration: 1.5)) { [weak self] in
            guard let self, self.machineState == snapshot else { return }
            self.enter(.idle)
        }
    }

    // MARK: - State Machine

    private func enter(_ newState: CharacterMachineState) {
        machineState = newState
        syncNodeAnimation(for: newState)
    }

    private func syncNodeAnimation(for state: CharacterMachineState) {
        switch state {
            case .offScreen, .idle:
                node.removeAction(forKey: Self.directionActionKey)
                node.zRotation = 0
                node.transition(to: .idle)
            case .sitting:
                node.removeAction(forKey: Self.directionActionKey)
                node.zRotation = 0
                node.transition(to: .sitting)
            case .jumping:
                node.removeAction(forKey: Self.directionActionKey)
                node.zRotation = 0
                node.transition(to: .jumping)
            case .interacting:
                node.removeAction(forKey: Self.directionActionKey)
                node.zRotation = 0
                node.transition(to: .interacting)
            case .waving:
                node.removeAction(forKey: Self.directionActionKey)
                node.zRotation = 0
                node.transition(to: .waving)
            case .walkingOnTop:
                node.transition(to: .walkingOnTop)
            case .movingTo, .entering, .exitingForEntry,
                 .exitingToLeave, .wandering, .teleporting:
                break // beginWalk() is called explicitly by startMove
        }
    }

    // MARK: - Helpers

    /// Starts a keyed move action, replacing any in-progress movement.
    /// Always forces the walk animation and applies a forward lean tilt.
    /// The completion runs only if the machine state hasn't changed by the time it fires.
    private func startMove(
        to target: CGPoint,
        direction: CGFloat,
        duration: TimeInterval,
        entering newState: CharacterMachineState,
        completion: @escaping () -> Void = {}
    ) {
        enter(newState)
        let snapshot = newState

        node.beginWalk(direction: direction)

        // Rotate to face the movement direction while keeping the head pointing up.
        // atan2(dy, abs(dx)) stays in [−π/2, π/2] so the sprite never goes upside down.
        // Horizontal facing (left/right) is handled by xScale in beginWalk.
        let dx = target.x - node.position.x
        let dy = target.y - node.position.y
        let dist = hypot(dx, dy)
        if dist > 1 {
            // atan2(dy, abs(dx)) stays in [−π/2, π/2] — head always points up.
            // Negate for left-facing (xScale < 0) because the horizontal mirror
            // inverts the visual effect of zRotation.
            let angle = atan2(dy, abs(dx))
            let signedAngle = direction >= 0 ? angle : -angle
            node.removeAction(forKey: Self.directionActionKey)
            node.zRotation = signedAngle
        }

        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .linear
        node.run(SKAction.sequence([move, SKAction.run { [weak self] in
            guard let self, self.machineState == snapshot else { return }
            completion()
        }]), withKey: Self.moveActionKey)
    }

    private func walkDuration(from: CGPoint, to: CGPoint) -> TimeInterval {
        let dx = abs(to.x - from.x)
        let dy = abs(to.y - from.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        return max(0.3, Double(distance / walkSpeed))
    }

    /// The scene-space point where the character stands on top of a rect.
    private func standingPoint(above rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.maxY + node.size.height / 2)
    }

    /// Converts a UIKit screen-space CGRect (origin top-left) to SpriteKit
    /// scene-space (origin bottom-left) assuming the SKView fills the screen.
    private func uiRectToScene(_ rect: CGRect, scene: SKScene) -> CGRect {
        guard let view = scene.view else { return rect }
        let h = view.bounds.height
        // UIKit minY = top edge; SpriteKit bottom = h - UIKit.maxY
        return CGRect(x: rect.minX, y: h - rect.maxY, width: rect.width, height: rect.height)
    }
}

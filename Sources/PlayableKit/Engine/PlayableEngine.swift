import Combine
import SpriteKit
import UIKit

// MARK: - PlayableEngine

/// Central coordinator of the PlayableKit system.
///
/// Responsibilities:
/// - Creating and owning the `PlayableScene` embedded in the main app window.
/// - Observing `PlayableRegistry` for element changes.
/// - Scheduling periodic random character interactions.
/// - Providing pause / resume / stop lifecycle management.
///
/// Usage:
/// ```swift
/// // In your App entry point or AppDelegate:
/// PlayableEngine.shared.start()
/// ```
@MainActor
public final class PlayableEngine: NSObject {
    // MARK: - Singleton

    public static let shared = PlayableEngine()

    // MARK: - Private state

    private var overlayView: SKView?
    private var overlayScene: PlayableScene?
    private var characterTapRecognizer: UITapGestureRecognizer?
    private var interactionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false
    private var currentSpriteSet: SpriteSet?

    /// How often (seconds) the engine picks a random element and moves the character to it
    /// while the character is already on screen.
    public var interactionInterval: TimeInterval = 8

    /// Range (seconds) from which the delay before the character's next entrance is drawn at random.
    public var interactionIntervalRange: ClosedRange<TimeInterval> = 5...30

    private var characterController: CharacterController? {
        overlayScene?.characterController
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Starts the system with an optional sprite set.
    /// Safe to call multiple times — a running engine ignores repeated calls.
    public func start(spriteSet: SpriteSet? = nil) {
        if let spriteSet { configure(spriteSet: spriteSet) }
        guard !isRunning else { return }
        isRunning = true
        createOverlay()
        observeRegistry()
        observeOrientation()
        scheduleNextEntrance()
    }

    /// Applies a new sprite set to the running character. Can be called before or after `start()`.
    public func configure(spriteSet: SpriteSet) {
        currentSpriteSet = spriteSet
        overlayScene?.characterController?.node.apply(spriteSet: spriteSet)
    }

    /// Permanently stops the system and removes the overlay view.
    public func stop() {
        isRunning = false
        interactionTimer?.invalidate()
        interactionTimer = nil
        cancellables.removeAll()
        if let recognizer = characterTapRecognizer {
            overlayView?.superview?.removeGestureRecognizer(recognizer)
        }
        characterTapRecognizer = nil
        overlayView?.removeFromSuperview()
        overlayView = nil
        overlayScene = nil
    }

    /// Pauses SpriteKit rendering and stops the interaction timer.
    public func pause() {
        overlayScene?.isPaused = true
        interactionTimer?.invalidate()
        interactionTimer = nil
    }

    /// Resumes SpriteKit rendering and restarts the appropriate timer.
    public func resume() {
        overlayScene?.isPaused = false
        if characterController?.isOffScreen ?? true {
            scheduleNextEntrance()
        } else {
            scheduleRepeatingInteractions()
        }
    }

    // MARK: - Interactions

    /// Moves the character to a random registered view.
    /// If off-screen, enters from the current off-screen position and switches to the
    /// repeating interaction timer. If already on-screen, moves to the new target directly.
    /// If no targets are registered and the character is on-screen, exits to the nearest border.
    public func triggerRandomInteraction() {
        guard let controller = characterController else { return }
        if let info = PlayableRegistry.shared.randomPlayableView() {
            if controller.isOffScreen {
                controller.enterFromBorderAndMove(to: info)
                scheduleRepeatingInteractions()
            } else {
                controller.moveToView(info)
            }
        } else if !controller.isOffScreen {
            controller.exitToNearestBorder { [weak self] in
                self?.scheduleNextEntrance()
            }
        } else {
            // No targets and already off-screen — reschedule so the character tries again later.
            scheduleNextEntrance()
        }
    }

    // MARK: - Private setup

    /// Adds a non-interactive `SKView` directly to the main app window so the character renders
    /// above app content but below any system-presented UI (sheets, pickers, alerts), which UIKit
    /// inserts into the same window after this view — naturally on top in z-order.
    private func createOverlay() {
        guard let windowScene = activeWindowScene(),
              let mainWindow = windowScene.windows.first(where: { $0.rootViewController != nil }) else {
            // No active scene yet — defer until one becomes available.
            NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // `queue: .main` guarantees this fires on the main thread.
                MainActor.assumeIsolated {
                    guard let self, self.overlayView == nil else { return }
                    self.createOverlay()
                }
            }
            return
        }

        let skView = SKView()
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.isUserInteractionEnabled = false
        skView.frame = mainWindow.bounds
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        mainWindow.addSubview(skView)
        overlayView = skView

        let scene = PlayableScene(size: mainWindow.bounds.size)
        overlayScene = scene
        skView.presentScene(scene)

        if let spriteSet = currentSpriteSet {
            scene.characterController?.node.apply(spriteSet: spriteSet)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleWindowTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        mainWindow.addGestureRecognizer(tap)
        characterTapRecognizer = tap
    }

    @objc private func handleWindowTap(_ recognizer: UITapGestureRecognizer) {
        guard let overlayView, let scene = overlayScene else { return }
        let point = recognizer.location(in: overlayView)
        let scenePoint = scene.convertPoint(fromView: point)
        if scene.nodes(at: scenePoint).contains(where: { $0 is PlayableCharacterNode }) {
            characterController?.handleTap()
        }
    }

    private func observeRegistry() {
        PlayableRegistry.shared.$infos
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] infos in
                guard let self, let controller = self.characterController else { return }

                if infos.isEmpty {
                    // Nothing to interact with — walk off screen if not already there
                    if !controller.isOffScreen {
                        controller.exitToNearestBorder { [weak self] in
                            self?.scheduleNextEntrance()
                        }
                    }
                } else if controller.isOffScreen {
                    // Targets reappeared while off-screen — enter immediately.
                    triggerRandomInteraction()
                } else if let id = controller.currentTargetID, infos[id] == nil {
                    // The target the character is walking toward disappeared — pick a new one
                    triggerRandomInteraction()
                }
            }
            .store(in: &cancellables)
    }

    private func observeOrientation() {
        NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleOrientationChange() }
            .store(in: &cancellables)
    }

    private func handleOrientationChange() {
        guard let scene = overlayScene,
              let windowScene = activeWindowScene() else { return }
        scene.size = windowScene.screen.bounds.size
    }

    /// One-shot timer with a random delay — used when the character is off-screen and waiting to enter.
    private func scheduleNextEntrance() {
        interactionTimer?.invalidate()
        let delay = TimeInterval.random(in: interactionIntervalRange)
        interactionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerRandomInteraction()
            }
        }
    }

    /// Repeating timer — used while the character is on-screen to keep it moving between targets.
    private func scheduleRepeatingInteractions() {
        interactionTimer?.invalidate()
        interactionTimer = Timer.scheduledTimer(withTimeInterval: interactionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerRandomInteraction()
            }
        }
    }

    // MARK: - Helpers

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
}

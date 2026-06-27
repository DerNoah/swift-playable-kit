import SpriteKit
import UIKit

// MARK: - PlayableWindow

/// A transparent `UIWindow` that floats above every other window.
///
/// - `windowLevel` is set above `.statusBar` so the character renders on top
///   of alerts, sheets, and the status bar itself.
/// - `hitTest` always returns `nil` so all touches fall through to the app.
/// - Contains a single `SKView` that presents the `PlayableScene`.
@MainActor
final class PlayableWindow: UIWindow {
    public private(set) var skView: SKView = .init()
    public private(set) var playableScene: PlayableScene?

    // MARK: - Init

    public override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func configure() {
        windowLevel = .statusBar + 100
        backgroundColor = .clear
        isUserInteractionEnabled = false // Fully bypass UIKit touch dispatch; taps handled via gesture recognizer on main window.

        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let passthrough = PassthroughViewController()
        passthrough.view.backgroundColor = .clear
        passthrough.view.isUserInteractionEnabled = false
        passthrough.view.addSubview(skView)
        rootViewController = passthrough

        isHidden = false
    }

    // MARK: - Scene

    /// Creates a ``PlayableScene`` of the given size and presents it in the embedded `SKView`.
    /// - Parameter size: The initial scene size; typically the window bounds.
    public func presentScene(size: CGSize) {
        let scene = PlayableScene(size: size)
        playableScene = scene
        skView.presentScene(scene)
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        skView.frame = bounds
    }
}

// MARK: - Passthrough helpers

/// A view controller whose view always returns `nil` from `hitTest`,
/// preventing the overlay from intercepting any gestures.
private final class PassthroughViewController: UIViewController {
    override func loadView() {
        view = PassthroughView()
    }
}

private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

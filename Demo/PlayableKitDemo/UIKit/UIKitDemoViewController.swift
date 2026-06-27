import PlayableKit
import UIKit

// MARK: - UIKitDemoViewController

/// Demonstrates UIKit integration. Views are registered via `makePlayable(kind:)`.
final class UIKitDemoViewController: UIViewController {
    // MARK: - Subviews

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "UIKit Demo"
        l.font = .preferredFont(forTextStyle: .largeTitle)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.15)
        v.layer.cornerRadius = 20
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardLabel: UILabel = {
        let l = UILabel()
        l.text = "UIKit Card View"
        l.textAlignment = .center
        l.font = .preferredFont(forTextStyle: .headline)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let actionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Interact"
        config.image = UIImage(systemName: "hand.tap")
        config.imagePadding = 8
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let navBarPlaceholder: UIView = {
        // Simulates a custom navigation bar element
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.shadowOpacity = 0.08
        v.layer.shadowRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        registerPlayableViews()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unregisterPlayableViews()
    }

    // MARK: - Layout

    private func buildLayout() {
        cardView.addSubview(cardLabel)
        view.addSubview(navBarPlaceholder)
        view.addSubview(titleLabel)
        view.addSubview(cardView)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            navBarPlaceholder.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBarPlaceholder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBarPlaceholder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBarPlaceholder.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.topAnchor.constraint(equalTo: navBarPlaceholder.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            cardView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.heightAnchor.constraint(equalToConstant: 160),

            cardLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cardLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            actionButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 32),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 180),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // MARK: - PlayableKit registration

    private func registerPlayableViews() {
        cardView.makePlayable(
            kind: .card,
            id: "uikit-card",
            options: InteractionOptions(canSit: true, canWalk: true, priority: 2)
        )
        actionButton.makePlayable(
            kind: .button,
            id: "uikit-action-button",
            options: InteractionOptions(canJump: true, priority: 3)
        )
        navBarPlaceholder.makePlayable(
            kind: .navigationBar,
            id: "uikit-navbar",
            options: InteractionOptions(canWalk: true)
        )
    }

    private func unregisterPlayableViews() {
        cardView.removePlayable()
        actionButton.removePlayable()
        navBarPlaceholder.removePlayable()
    }
}

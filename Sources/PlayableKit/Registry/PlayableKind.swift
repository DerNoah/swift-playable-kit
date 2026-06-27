import Foundation

// MARK: - PlayableKind

/// Describes the semantic role of a registered UI element.
/// The kind drives which character interaction is triggered.
public enum PlayableKind: Hashable, Sendable {
    /// A tappable button. The character plays the `interact` animation.
    case button
    /// A `UITabBar` or equivalent tab strip. The character sits on it.
    case tabBar
    /// A card or list item the character can walk across the top of.
    case card
    /// A navigation bar. The character walks along it.
    case navigationBar
    /// The Dynamic Island. The character waves at it.
    case dynamicIsland
    /// Any element not covered by the built-in cases. The character idles beside it.
    case custom(String)

    /// The default interaction the character performs when targeting this kind.
    var preferredInteraction: CharacterInteraction {
        switch self {
            case .button: return .interact
            case .tabBar: return .sit
            case .card: return .walkOnTop
            case .navigationBar: return .walk
            case .dynamicIsland: return .wave
            case .custom: return .idle
        }
    }
}

// MARK: - CharacterInteraction

/// The action the character performs when visiting a ``PlayableViewInfo``.
enum CharacterInteraction: Sendable {
    /// The character jumps on the element.
    case jump
    /// The character sits on the element.
    case sit
    /// The character walks toward the element and stops beside it.
    case walk
    /// The character walks along the top edge of the element.
    case walkOnTop
    /// The character waves at the element.
    case wave
    /// The character plays the interact animation and fires the view's `onInteract` callback.
    case interact
    /// The character idles at its current position.
    case idle
}

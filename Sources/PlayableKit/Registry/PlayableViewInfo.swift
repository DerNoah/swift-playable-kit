import CoreGraphics
import Foundation

// MARK: - InteractionOptions

/// Configures which interactions a registered view supports.
public struct InteractionOptions: Hashable, Sendable {
    /// The character may sit on this element.
    public var canSit: Bool
    /// The character may jump on this element.
    public var canJump: Bool
    /// The character may walk along the top edge of this element.
    public var canWalk: Bool
    /// Higher priority elements are preferred by the engine's random selector.
    public var priority: Int

    public init(
        canSit: Bool = true,
        canJump: Bool = true,
        canWalk: Bool = true,
        priority: Int = 0
    ) {
        self.canSit = canSit
        self.canJump = canJump
        self.canWalk = canWalk
        self.priority = priority
    }

    public static let `default` = InteractionOptions()
}

// MARK: - PlayableViewInfo

/// A snapshot of a registered interactable UI element.
/// All coordinates are in global screen space (UIKit, origin top-left).
struct PlayableViewInfo: Identifiable, Hashable, Sendable {
    public let id: String
    /// Current global frame in screen coordinates (UIKit origin = top-left).
    public var frame: CGRect
    /// Corner radius of the underlying view.
    public var cornerRadius: CGFloat
    /// Semantic role of the element.
    public var kind: PlayableKind
    /// Rendering order; higher = more on top.
    public var zIndex: Int
    public var interactionOptions: InteractionOptions

    public init(
        id: String = UUID().uuidString,
        frame: CGRect,
        cornerRadius: CGFloat = 0,
        kind: PlayableKind,
        zIndex: Int = 0,
        interactionOptions: InteractionOptions = .default
    ) {
        self.id = id
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.kind = kind
        self.zIndex = zIndex
        self.interactionOptions = interactionOptions
    }
}

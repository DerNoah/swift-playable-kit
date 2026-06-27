import SwiftUI

public extension View {
    /// Registers this view with PlayableKit so the character can interact with it.
    ///
    /// - Parameters:
    ///   - kind:    The semantic role — drives which animation the character plays.
    ///   - id:      A stable ID unique within the registry. Generate one once and
    ///              store it; do **not** pass `UUID().uuidString` directly here
    ///              (SwiftUI re-evaluates the call-site on every render).
    ///   - options: Fine-grained control over allowed interactions and priority.
    ///
    /// Example — stable ID via a `@State` or `let` constant:
    /// ```swift
    /// private let cardID = UUID().uuidString
    ///
    /// var body: some View {
    ///     CardView()
    ///         .playable(kind: .card, id: cardID)
    /// }
    /// ```
    /// - Parameter onInteract: Called when the character arrives and begins any interaction
    ///   with this view. Use it to apply visual feedback (highlight, scale, etc.)
    ///   without triggering the view's real action.
    func playable(
        kind: PlayableKind,
        id: String,
        options: InteractionOptions = .default,
        onInteract: (() -> Void)? = nil
    ) -> some View {
        modifier(PlayableModifier(kind: kind, id: id, options: options, onInteract: onInteract))
    }
}

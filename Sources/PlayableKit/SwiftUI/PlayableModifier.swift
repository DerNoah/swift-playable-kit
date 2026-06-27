import SwiftUI

// MARK: - GlobalFramePreferenceKey

/// Propagates a view's global frame up the SwiftUI preference system.
private struct GlobalFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - PlayableModifier

/// Registers a SwiftUI view with `PlayableRegistry`, tracking its global
/// frame automatically via `GeometryReader` and `PreferenceKey`.
///
/// Unregisters on `onDisappear`.
///
/// Usage:
/// ```swift
/// CardView()
///     .playable(kind: .card)
///
/// Button("Buy") { }
///     .playable(kind: .button, options: InteractionOptions(priority: 3))
/// ```
public struct PlayableModifier: ViewModifier {
    private let kind: PlayableKind
    private let id: String
    private let options: InteractionOptions
    private let onInteract: (() -> Void)?

    /// Creates a modifier that registers the view with ``PlayableRegistry``.
    /// - Parameters:
    ///   - kind: The semantic role of the view.
    ///   - id: A stable ID unique within the registry.
    ///   - options: Fine-grained interaction configuration.
    ///   - onInteract: Optional callback fired when the character begins an interaction.
    public init(kind: PlayableKind, id: String, options: InteractionOptions, onInteract: (() -> Void)? = nil) {
        self.kind = kind
        self.id = id
        self.options = options
        self.onInteract = onInteract
    }

    public func body(content: Content) -> some View {
        content
            .background(frameReader)
            .onPreferenceChange(GlobalFramePreferenceKey.self, perform: handleFrameChange)
            .onAppear {
                if let onInteract {
                    PlayableRegistry.shared.setInteractCallback(id: id, onInteract)
                }
            }
            .onDisappear {
                PlayableRegistry.shared.unregister(id: id)
            }
    }

    // MARK: - Frame reader

    private var frameReader: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: GlobalFramePreferenceKey.self,
                    value: geo.frame(in: .global)
                )
        }
    }

    // MARK: - Frame handling

    private func handleFrameChange(_ frame: CGRect) {
        guard !frame.isEmpty else {
            PlayableRegistry.shared.unregister(id: id)
            return
        }
        let info = PlayableViewInfo(
            id: id,
            frame: frame,
            cornerRadius: 0,
            kind: kind,
            zIndex: 0,
            interactionOptions: options
        )
        PlayableRegistry.shared.register(info)
    }
}

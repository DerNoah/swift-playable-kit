import Combine
import Foundation

// MARK: - PlayableRegistry

/// Central, thread-safe registry of all interactable UI elements.
///
/// Views register themselves by calling `register(_:)` and are automatically
/// removed via `unregister(id:)` when they disappear or are deallocated.
/// `PlayableEngine` observes `$infos` to react to changes.
@MainActor
final class PlayableRegistry: ObservableObject {
    /// Shared singleton — the entire system operates on a single registry.
    public static let shared = PlayableRegistry()

    /// All currently registered views, keyed by their stable IDs.
    /// Observe via `$infos` (Combine) or `objectWillChange` (SwiftUI).
    @Published private(set) var infos: [String: PlayableViewInfo] = [:]

    /// Per-view interact callbacks. Keyed by the same stable ID used in `infos`.
    private var interactCallbacks: [String: () -> Void] = [:]

    private init() {}

    // MARK: - Mutation

    /// Adds or updates a registered view.
    public func register(_ info: PlayableViewInfo) {
        infos[info.id] = info
    }

    /// Removes a registered view by ID. No-op if not present.
    public func unregister(id: String) {
        infos.removeValue(forKey: id)
        interactCallbacks.removeValue(forKey: id)
    }

    /// Stores a callback that fires when the character begins any interaction with this view.
    func setInteractCallback(id: String, _ callback: @escaping () -> Void) {
        interactCallbacks[id] = callback
    }

    /// Fires the interact callback for the given ID, if one is registered.
    func fireInteractCallback(id: String) {
        interactCallbacks[id]?()
    }

    /// Updates only the frame of an already-registered view.
    /// More efficient than a full `register` when nothing else changed.
    public func update(id: String, frame: CGRect) {
        infos[id]?.frame = frame
    }

    // MARK: - Querying

    /// All registered views ordered by descending zIndex.
    public func visiblePlayableViews() -> [PlayableViewInfo] {
        infos.values.sorted { $0.zIndex > $1.zIndex }
    }

    /// A random registered view, weighted by `interactionOptions.priority`.
    /// Returns `nil` when the registry is empty.
    public func randomPlayableView() -> PlayableViewInfo? {
        let views = infos.values
        guard !views.isEmpty else { return nil }

        // Weighted random: add each view (priority + 1) times to the pool
        var pool: [PlayableViewInfo] = []
        for info in views {
            let weight = max(1, info.interactionOptions.priority + 1)
            pool.append(contentsOf: repeatElement(info, count: weight))
        }
        return pool.randomElement()
    }
}

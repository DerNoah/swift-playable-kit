import ObjectiveC
import UIKit

// MARK: - Associated object keys

private nonisolated(unsafe) var playableIDKey: UInt8 = 0
private nonisolated(unsafe) var playableLifecycleKey: UInt8 = 0
private nonisolated(unsafe) var playableInteractCallbackKey: UInt8 = 0

// MARK: - UIView+Playable

public extension UIView {
    /// Registers this view with `PlayableRegistry` and begins tracking its global frame.
    ///
    /// Tracking starts automatically when the view enters a window and stops when
    /// it leaves — no manual cleanup required.
    ///
    /// - Parameters:
    ///   - kind:       The semantic role of this view (drives character interactions).
    ///   - id:         A stable string ID. Defaults to the view's `ObjectIdentifier` hash.
    ///   - options:    Interaction options forwarded to the registry.
    ///   - onInteract: Called when the character arrives and begins any interaction with
    ///                 this view. Use it for visual feedback (highlight, scale, etc.)
    ///                 without triggering the view's real action.
    func makePlayable(
        kind: PlayableKind,
        id: String? = nil,
        options: InteractionOptions = .default,
        onInteract: (() -> Void)? = nil
    ) {
        let stableID = id ?? "\(ObjectIdentifier(self).hashValue)"
        objc_setAssociatedObject(self, &playableIDKey, stableID, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if let onInteract {
            objc_setAssociatedObject(self, &playableInteractCallbackKey, onInteract as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            PlayableRegistry.shared.setInteractCallback(id: stableID, onInteract)
        }

        let lifecycle = PlayableLifecycleObserver(view: self, id: stableID, kind: kind, options: options)
        objc_setAssociatedObject(self, &playableLifecycleKey, lifecycle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Manually removes this view from `PlayableRegistry` and stops frame tracking.
    /// This is not required — cleanup happens automatically when the view leaves the
    /// window hierarchy or is deallocated.
    func removePlayable() {
        // Nil-ing the associated object triggers PlayableLifecycleObserver.deinit,
        // which invalidates the display link and unregisters from the registry.
        objc_setAssociatedObject(self, &playableLifecycleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - PlayableLifecycleObserver

/// Observes `view.window` via KVO to automatically start and stop frame tracking.
/// Stored as an associated object on the view — its lifetime matches the view's.
@MainActor
private final class PlayableLifecycleObserver: NSObject {
    private weak var view: UIView?
    private let id: String
    private let kind: PlayableKind
    private let options: InteractionOptions
    // Touched only on the main actor; `nonisolated(unsafe)` lets the nonisolated `deinit` invalidate them.
    private nonisolated(unsafe) var windowObservation: NSKeyValueObservation?
    private nonisolated(unsafe) var displayLink: CADisplayLink?

    init(view: UIView, id: String, kind: PlayableKind, options: InteractionOptions) {
        self.view = view
        self.id = id
        self.kind = kind
        self.options = options
        super.init()

        // .initial fires immediately so tracking starts if the view is already in a window.
        // `window` KVO notifications are delivered on the main thread.
        self.windowObservation = view.observe(\.window, options: [.initial, .new]) { [weak self] view, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if view.window != nil {
                    self.startTracking()
                } else {
                    self.stopTracking()
                }
            }
        }
    }

    private func startTracking() {
        guard let view, displayLink == nil else { return }
        let observer = PlayableFrameObserver(view: view, id: id, kind: kind, options: options)
        let link = CADisplayLink(target: observer, selector: #selector(PlayableFrameObserver.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 15)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTracking() {
        displayLink?.invalidate()
        displayLink = nil
        PlayableRegistry.shared.unregister(id: id)
    }

    deinit {
        // Runs when the view (and thus this associated object) is released, or on `removePlayable()`.
        windowObservation?.invalidate()
        displayLink?.invalidate()
        let id = self.id
        MainActor.assumeIsolated {
            PlayableRegistry.shared.unregister(id: id)
        }
    }
}

// MARK: - PlayableFrameObserver

/// CADisplayLink target that tracks the view's frame and visibility.
/// Holds a weak reference to the view so it self-cleans if the view is deallocated.
@MainActor
private final class PlayableFrameObserver: NSObject {
    private weak var view: UIView?
    private let id: String
    private let kind: PlayableKind
    private let options: InteractionOptions
    private var lastFrame: CGRect = .zero
    private var lastVisible: Bool = false

    init(view: UIView, id: String, kind: PlayableKind, options: InteractionOptions) {
        self.view = view
        self.id = id
        self.kind = kind
        self.options = options
    }

    // Invoked by `CADisplayLink` on the main run loop, so main-actor isolation holds.
    @objc func tick(_ link: CADisplayLink) {
        guard let view else {
            link.invalidate()
            PlayableRegistry.shared.unregister(id: id)
            return
        }

        let newFrame = view.globalFrame
        let nowVisible = view.isPlayableVisible

        guard newFrame != lastFrame || nowVisible != lastVisible else { return }
        lastFrame = newFrame
        lastVisible = nowVisible

        if nowVisible {
            let info = PlayableViewInfo(
                id: id,
                frame: newFrame,
                cornerRadius: view.layer.cornerRadius,
                kind: kind,
                zIndex: Int(view.layer.zPosition),
                interactionOptions: options
            )
            PlayableRegistry.shared.register(info)
        } else {
            PlayableRegistry.shared.unregister(id: id)
        }
    }
}

import UIKit

// MARK: - UIView global frame

extension UIView {
    /// The view's frame converted to the coordinate space of its `UIWindow`.
    /// Returns `.zero` when the view is not attached to a window.
    var globalFrame: CGRect {
        guard let window else { return .zero }
        return convert(bounds, to: window)
    }
}

// MARK: - UIView visibility

extension UIView {
    /// `true` when the view is visible in its window hierarchy and occupies
    /// a non-empty area. Checks `isHidden`, `alpha`, window attachment,
    /// bounds size, and every ancestor up the view hierarchy.
    var isPlayableVisible: Bool {
        guard
            !isHidden,
            alpha > 0.01,
            window != nil,
            !bounds.isEmpty else { return false }

        var ancestor: UIView? = superview
        while let v = ancestor {
            if v.isHidden || v.alpha < 0.01 { return false }
            ancestor = v.superview
        }
        return true
    }
}

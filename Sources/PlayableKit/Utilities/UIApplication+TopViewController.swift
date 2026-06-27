import UIKit

extension UIApplication {
    /// Resolves the topmost visible `UIViewController` in the currently active
    /// `UIWindowScene`. Traverses navigation stacks, tab bar controllers, and
    /// any chain of modally presented view controllers.
    @MainActor
    var topViewController: UIViewController? {
        guard
            let scene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows
            .first(where: { $0.isKeyWindow })?.rootViewController else { return nil }

        return Self.top(from: root)
    }

    @MainActor
    private static func top(from base: UIViewController) -> UIViewController {
        // Unwrap navigation stacks
        if let nav = base as? UINavigationController,
           let visible = nav.visibleViewController {
            return top(from: visible)
        }
        // Unwrap tab bar controllers
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return top(from: selected)
        }
        // Unwrap any modal presentation (sheet, fullscreen, etc.)
        if let presented = base.presentedViewController {
            return top(from: presented)
        }
        return base
    }
}

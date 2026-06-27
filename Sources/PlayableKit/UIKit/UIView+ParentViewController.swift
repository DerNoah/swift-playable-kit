import UIKit

extension UIView {
    /// Walks up the responder chain to find the nearest enclosing
    /// `UIViewController`. Returns `nil` if none is found (e.g. the view is
    /// not yet in the hierarchy).
    var parentViewController: UIViewController? {
        var responder: UIResponder? = next
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

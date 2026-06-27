import CoreGraphics

extension CGRect {
    /// The geometric center of the rect.
    var center: CGPoint { CGPoint(x: midX, y: midY) }

    /// The midpoint of the top edge.
    var topCenter: CGPoint { CGPoint(x: midX, y: minY) }

    /// The midpoint of the bottom edge.
    var bottomCenter: CGPoint { CGPoint(x: midX, y: maxY) }

    /// Insets all edges by the same amount.
    func inset(by amount: CGFloat) -> CGRect {
        insetBy(dx: amount, dy: amount)
    }

    /// Converts a UIKit screen-space rect (origin top-left) to SpriteKit
    /// scene-space (origin bottom-left) given the total view/screen height.
    func toSKCoordinates(viewHeight: CGFloat) -> CGRect {
        CGRect(x: minX, y: viewHeight - maxY, width: width, height: height)
    }
}

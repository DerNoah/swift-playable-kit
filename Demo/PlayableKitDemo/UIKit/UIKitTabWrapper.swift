import SwiftUI

/// Wraps `UIKitDemoViewController` in a SwiftUI view using `UIViewControllerRepresentable`.
struct UIKitTabWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitDemoViewController {
        UIKitDemoViewController()
    }

    func updateUIViewController(_ uiViewController: UIKitDemoViewController, context: Context) {}
}

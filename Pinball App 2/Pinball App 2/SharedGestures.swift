import SwiftUI
import UIKit

private struct AppInteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> EnablerViewController {
        EnablerViewController()
    }

    func updateUIViewController(_ uiViewController: EnablerViewController, context: Context) {
        uiViewController.configureInteractivePopIfNeeded()
    }

    final class EnablerViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureInteractivePopIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            configureInteractivePopIfNeeded()
        }

        func configureInteractivePopIfNeeded() {
            guard let nav = navigationController,
                  let gesture = nav.interactivePopGestureRecognizer else {
                return
            }
            gesture.isEnabled = nav.viewControllers.count > 1
            gesture.delegate = nil
        }
    }
}

extension View {
    func appEdgeBackGesture(dismiss _: DismissAction) -> some View {
        background(AppInteractivePopEnabler().allowsHitTesting(false))
    }
}

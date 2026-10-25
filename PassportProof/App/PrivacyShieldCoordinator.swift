//
//  PrivacyShieldCoordinator.swift
//  PassportProof
//
//  A root SwiftUI overlay sits behind presented camera and crop controllers.
//  Use a separate window in each scene to cover those presentations as well.
//

import SwiftUI
import UIKit

@MainActor
final class PrivacyShieldCoordinator: NSObject {
    static let shared = PrivacyShieldCoordinator()

    private var isObserving = false
    private var covers: [String: UIWindow] = [:]

    func start() {
        guard !isObserving else { return }
        isObserving = true
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(willDeactivate(_:)),
                           name: UIScene.willDeactivateNotification, object: nil)
        center.addObserver(self, selector: #selector(didEnterBackground(_:)),
                           name: UIScene.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(removeCover(_:)),
                           name: UIScene.didActivateNotification, object: nil)
        center.addObserver(self, selector: #selector(removeCover(_:)),
                           name: UIScene.didDisconnectNotification, object: nil)
    }

    @objc private func willDeactivate(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene else { return }
        // A share extension can temporarily deactivate its host. Keep the
        // user's chosen sharing interface visible; a real background transition
        // is still covered by didEnterBackground before UIKit's scene snapshot.
        guard !scene.windows.contains(where: { window in
            window.rootViewController.map(containsShareController) ?? false
        }) else { return }
        showCover(in: scene)
    }

    @objc private func didEnterBackground(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene else { return }
        showCover(in: scene)
    }

    @objc private func removeCover(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene,
              let window = covers.removeValue(forKey: scene.session.persistentIdentifier)
        else { return }
        // No fade: neither background snapshots nor the returning foreground
        // interface should depend on an animation finishing.
        UIView.performWithoutAnimation {
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private func showCover(in scene: UIWindowScene) {
        let identifier = scene.session.persistentIdentifier
        guard covers[identifier] == nil else { return }

        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        // Above ordinary app windows and their full-screen presentations, but
        // below system alerts. This window must never take keyboard focus.
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.isUserInteractionEnabled = false
        window.backgroundColor = UIColor(Theme.paper)
        window.isOpaque = true
        window.rootViewController = PrivacyShieldViewController()
        covers[identifier] = window

        UIView.performWithoutAnimation {
            window.isHidden = false // Deliberately not makeKeyAndVisible().
            window.layoutIfNeeded()
            window.rootViewController?.view.layoutIfNeeded()
        }
    }

    private func containsShareController(_ controller: UIViewController) -> Bool {
        if controller is UIActivityViewController { return true }
        if let presented = controller.presentedViewController,
           containsShareController(presented) { return true }
        return controller.children.contains(where: containsShareController)
    }
}

@MainActor
private final class PrivacyShieldViewController: UIViewController {
    override func loadView() {
        let cover = UIView()
        cover.backgroundColor = UIColor(Theme.paper)
        cover.isOpaque = true
        cover.isAccessibilityElement = true
        cover.accessibilityIdentifier = "privacy.shield"
        cover.accessibilityLabel = "PassportProof. Your photo is hidden while the app is in the background."

        let title = UILabel()
        title.text = "PassportProof"
        title.textColor = UIColor(Theme.ink)
        title.font = .preferredFont(forTextStyle: .title2)
        title.adjustsFontForContentSizeCategory = true
        title.textAlignment = .center
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "Your photo stays private."
        subtitle.textColor = UIColor(Theme.inkSecondary)
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: cover.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: cover.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
        ])
        view = cover
    }
}

//
//  ShareSheet.swift
//  PassportProof
//
//  System sharing with one completion callback per presented activity. The
//  owner also handles sheet dismissal, including an interactive cancellation.
//

import SwiftUI
import UIKit

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: () -> Void = {}

    @MainActor
    final class Coordinator {
        var onComplete: () -> Void
        private var didComplete = false

        init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

        func complete() {
            guard !didComplete else { return }
            didComplete = true
            onComplete()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let coordinator = context.coordinator
        controller.completionWithItemsHandler = { [weak coordinator] _, _, _, _ in
            DispatchQueue.main.async { coordinator?.complete() }
        }
        anchorPopover(controller)
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        context.coordinator.onComplete = onComplete
        anchorPopover(controller)
    }

    private func anchorPopover(_ controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(
            x: controller.view.bounds.midX,
            y: controller.view.bounds.midY,
            width: 1,
            height: 1
        )
        popover.permittedArrowDirections = []
    }
}

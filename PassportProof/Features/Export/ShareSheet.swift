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
    /// Reports whether the customer actually completed an activity. Dismissing
    /// the sheet without saving is not a successful export, so the caller can
    /// avoid celebrating (or asking for a rating) when nothing happened.
    var onComplete: (Bool) -> Void = { _ in }

    @MainActor
    final class Coordinator {
        var onComplete: (Bool) -> Void
        private var didComplete = false

        init(onComplete: @escaping (Bool) -> Void) { self.onComplete = onComplete }

        func complete(completed: Bool) {
            guard !didComplete else { return }
            didComplete = true
            onComplete(completed)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let coordinator = context.coordinator
        controller.completionWithItemsHandler = { [weak coordinator] _, completed, _, _ in
            DispatchQueue.main.async { coordinator?.complete(completed: completed) }
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

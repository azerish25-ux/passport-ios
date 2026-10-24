//
//  ShareSheet.swift
//  PassportProof
//
//  UIActivityViewController wrapper. On iPad an unconfigured popover
//  presentation controller crashes on presentation, so the source view is set
//  defensively — the controller is presented as a sheet, but a sheet on iPad is
//  not a guarantee that a popover is not created.
//

import SwiftUI
import UIKit

/// A file staged for sharing. Identity is per-share so the sheet re-presents
/// even when the same layout is exported twice.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        guard let popover = controller.popoverPresentationController else { return }

        popover.sourceView = controller.view
        popover.sourceRect = CGRect(
            x: controller.view.bounds.midX,
            y: controller.view.bounds.midY,
            width: 0,
            height: 0
        )
        popover.permittedArrowDirections = []
    }
}

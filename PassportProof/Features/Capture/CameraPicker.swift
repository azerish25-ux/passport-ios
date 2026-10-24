//
//  CameraPicker.swift
//  PassportProof
//
//  UIImagePickerController wrapped for SwiftUI.
//
//  Why this and not AVCaptureSession: the brief fixes the wrapper, and the
//  system camera keeps the permission prompt and the shutter inside Apple's
//  code. The consequence is that the live feed is not sampled — `CaptureGate`
//  therefore runs on the captured still, and the accept control stays disabled
//  until the still passes. See CaptureView.
//
//  The overlay is a UIHostingController held by the coordinator. Holding it only
//  through `picker.cameraOverlayView` would leave a dangling view: the picker
//  keeps the view, not the controller that owns it.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {

    let spec: DocumentSpec
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator

        let host = UIHostingController(
            rootView: FramingOverlay(spec: spec, drawsGround: false)
        )
        host.view.backgroundColor = .clear
        host.view.frame = UIScreen.main.bounds
        host.view.isUserInteractionEnabled = false

        context.coordinator.overlayHost = host
        picker.cameraOverlayView = host.view

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // The guide is fixed for the life of the sheet: the document cannot
        // change while the camera is open.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let onCapture: (UIImage) -> Void
        private let onCancel: () -> Void

        /// Strong reference. See the note at the top of the file.
        var overlayHost: UIViewController?

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

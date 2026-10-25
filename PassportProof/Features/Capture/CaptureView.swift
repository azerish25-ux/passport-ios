//
//  CaptureView.swift
//  PassportProof
//
//  Camera or library → one aspect-locked crop → diagnosis. The custom camera
//  enforces its gate before capture; imported photos go through the same crop
//  and complete rule engine without pretending a shutter existed.
//

import AVFoundation
import SwiftUI
import UIKit

@MainActor
struct CaptureView: View {
    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showCamera = false
    @State private var showCrop = false
    @State private var shouldOpenAnalysis = false
    @State private var goToAnalysis = false
    @State private var pendingImage: UIImage?
    @State private var pendingCaptureDate: Date?
    @State private var cameraDenied = false

    private var cameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle(
                    title: "Capture",
                    subtitle: "\(spec.displayName) · \(spec.workflow.title)"
                )

                Theme.SectionHeader(title: "Your setup")
                    .padding(.horizontal, Theme.Spacing.margin)
                setupGuide

                Theme.SectionHeader(title: "Choose a source")
                    .padding(.horizontal, Theme.Spacing.margin)
                sourceCard

                if cameraDenied {
                    cameraDeniedCard
                }

                privacyNote

                if session.hasPhoto {
                    currentPhoto
                }
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera, onDismiss: presentCropIfReady) {
            CameraPicker(
                spec: spec,
                onCapture: { image in
                    pendingImage = image
                    pendingCaptureDate = Date()
                    showCamera = false
                },
                onCancel: {
                    pendingImage = nil
                    pendingCaptureDate = nil
                    showCamera = false
                }
            )
        }
        .fullScreenCover(isPresented: $showCrop, onDismiss: openAnalysisIfRequested) {
            if let pendingImage {
                CropEditorView(
                    sourceImage: pendingImage,
                    spec: spec,
                    onComplete: acceptCrop,
                    onCancel: discardPending
                )
            }
        }
        .navigationDestination(isPresented: $goToAnalysis) {
            AnalysisView(spec: spec)
        }
    }

    private var setupGuide: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            FramingOverlay(spec: spec)
                .aspectRatio(CGFloat(spec.aspectRatio), contentMode: .fit)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("Example framing guide")
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    SetupItem(icon: "square.on.square", title: "Plain background", detail: spec.backgroundDescription)
                    SetupItem(icon: "sun.max", title: "Even light", detail: "Face one light source; avoid shadows")
                    SetupItem(icon: "person.crop.rectangle", title: "Head & shoulders", detail: "Look directly at the camera")
                    SetupItem(icon: "hand.raised", title: "Hold still", detail: "Live guidance helps with framing")
                }
            } else {
                HStack(spacing: Theme.Spacing.m) {
                    SetupItem(icon: "square.on.square", title: "Plain background", detail: spec.backgroundDescription)
                    SetupItem(icon: "sun.max", title: "Even light", detail: "Face one light source; avoid shadows")
                }
                HStack(spacing: Theme.Spacing.m) {
                    SetupItem(icon: "person.crop.rectangle", title: "Head & shoulders", detail: "Look directly at the camera")
                    SetupItem(icon: "hand.raised", title: "Hold still", detail: "Live guidance helps with framing")
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private var sourceCard: some View {
        VStack(spacing: 0) {
            Button(action: openCamera) {
                SourceRow(
                    icon: "camera.fill",
                    title: "Use live camera",
                    subtitle: cameraAvailable
                        ? "Real-time framing and background guidance"
                        : "No camera available on this device",
                    isEnabled: cameraAvailable
                )
            }
            .buttonStyle(.plain)
            .disabled(!cameraAvailable)
            .accessibilityIdentifier("capture.camera")

            Theme.Rule()
                .padding(.leading, 64)

            PhotoImporter(title: "Choose from library") { image, captureDate in
                pendingImage = image
                pendingCaptureDate = captureDate
                showCrop = true
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
        .background(Theme.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.rule, lineWidth: 0.5)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private var cameraDeniedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Camera access is off", systemImage: "camera.metering.partial")
                .font(.headline)
                .foregroundStyle(Theme.signalFail)
            Text("Enable camera access in Settings, or continue with a photo from your library. Your choice does not prevent the rest of the app from working.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryAction(title: "Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.failWash)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private var privacyNote: some View {
        Label("Your photo is processed on this device and never uploaded.", systemImage: "lock.shield")
            .typeStyle(Typography.meta)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)
    }

    private var currentPhoto: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Theme.SectionHeader(title: "Current session")
            if let image = session.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 180, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Current prepared photo")
            }
            SecondaryAction(title: "Review current diagnosis") { goToAnalysis = true }
            SecondaryAction(title: "Start over") { session.clear() }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private func openCamera() {
        guard cameraAvailable else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraDenied = !granted
                    if granted { showCamera = true }
                }
            }
        default:
            cameraDenied = true
        }
    }

    private func acceptCrop(_ image: UIImage) {
        session.adopt(image, captureDate: pendingCaptureDate)
        pendingImage = nil
        pendingCaptureDate = nil
        shouldOpenAnalysis = true
        showCrop = false
    }

    private func discardPending() {
        pendingImage = nil
        pendingCaptureDate = nil
        showCrop = false
    }

    private func presentCropIfReady() {
        if pendingImage != nil {
            showCrop = true
        }
    }

    private func openAnalysisIfRequested() {
        if shouldOpenAnalysis {
            shouldOpenAnalysis = false
            goToAnalysis = true
        }
    }
}

private struct SetupItem: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SourceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isEnabled = true

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isEnabled ? Theme.accent : Theme.inkTertiary)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(isEnabled ? 0.12 : 0.04), in: Circle())
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isEnabled ? Theme.ink : Theme.inkTertiary)
                Text(subtitle)
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(Theme.Spacing.m)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

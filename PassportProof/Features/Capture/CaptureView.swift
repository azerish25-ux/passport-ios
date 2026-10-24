//
//  CaptureView.swift
//  PassportProof
//
//  Two entry points: camera and library. Both funnel into the same review: the
//  still is shown, `CaptureGate` is evaluated on it, and the accept control is
//  disabled until the gate returns `canCapture == true`. The gate's own message
//  is printed beneath the control — it is the gate talking, not a paraphrase.
//
//  Honest limitation, stated on screen: `UIImagePickerController` does not
//  expose frames, so the gate cannot run on the live feed in this build. It runs
//  on the captured still, and the shutter that matters — the one that lets a
//  photo into the diagnosis — is the one this screen disables.
//

import AVFoundation
import SwiftUI
import UIKit

@MainActor
struct CaptureView: View {
    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession

    @State private var showCamera = false
    @State private var goToAnalysis = false

    @State private var pendingImage: UIImage?
    @State private var gate: CaptureGateResult?
    @State private var isEvaluating = false
    @State private var pendingSource: FrameSource = .library

    /// The camera cannot open: permission denied, or the device restricts it.
    /// Stated on screen with a way out, never a black screen.
    @State private var cameraDenied = false

    /// The frame was adopted but could not be measured. The old build left the
    /// gate at "Not evaluated" with no way forward; this states the failure.
    @State private var gateFailure: String?

    /// The capture date belonging to the pending frame: "now" for the camera
    /// path, the EXIF date for a library import. Held outside the session until
    /// the frame is accepted, so a discard leaves no trace.
    @State private var pendingCaptureDate: Date?

    /// Where the pending frame came from. The gate governs the shutter, and a
    /// library import has no shutter: it is a frame that already exists. So the
    /// gate blocks the camera path outright and is reported as information on
    /// the import path — otherwise a photo with a busy background could never
    /// reach the diagnosis at all, which is the only path the simulator has.
    enum FrameSource {
        case camera
        case library
    }

    private var canProceed: Bool {
        guard let gate else { return false }
        return gate.canCapture || pendingSource == .library
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var guideAspect: CGFloat {
        CGFloat(spec.widthMM / spec.heightMM)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ScreenTitle(
                    title: "Capture",
                    subtitle: spec.displayName
                )

                Theme.SectionHeader(
                    title: "Framing",
                    trailing: Format.sizeMM(width: spec.widthMM, height: spec.heightMM)
                )

                FramingOverlay(spec: spec)
                    .aspectRatio(guideAspect, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                framingNote

                Theme.SectionHeader(title: "Target")
                targets

                Theme.SectionHeader(title: "Source")
                cameraRow
                if cameraDenied {
                    cameraDeniedRow
                }
                Theme.Rule()
                PhotoImporter(title: "Choose from library") { image, captureDate in
                    adopt(image, from: .library, captureDate: captureDate)
                }
                Theme.Rule()

                if let pendingImage {
                    Theme.SectionHeader(
                        title: "Captured frame",
                        trailing: isEvaluating ? "checking" : nil
                    )
                    reviewBlock(image: pendingImage)
                }

                Spacer(minLength: Theme.Spacing.xxxl)
            }
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                spec: spec,
                onCapture: { image in
                    showCamera = false
                    adopt(image, from: .camera, captureDate: Date())
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .navigationDestination(isPresented: $goToAnalysis) {
            AnalysisView(spec: spec)
        }
    }

    // MARK: Notes

    private var framingNote: some View {
        Text("The band is this document's head-height clause, drawn on its photo geometry. The gate is evaluated on the frame you take, not on the live feed — this build does not sample video.")
            .typeStyle(Typography.meta)
            .foregroundStyle(Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
    }

    // MARK: Targets

    private var targets: some View {
        ReadoutStrip(columns: [
            ReadoutStrip.Column(
                id: "head",
                value: Typography.inlineValue(
                    "\(Format.decimal(spec.headHeightMM.lowerBound))–\(Format.decimal(spec.headHeightMM.upperBound))",
                    unit: "mm"
                ),
                caption: "required head"
            ),
            ReadoutStrip.Column(
                id: "cell",
                value: Typography.inlineValue(
                    "\(Format.compact(spec.widthMM)) × \(Format.compact(spec.heightMM))",
                    unit: "mm"
                ),
                caption: "cell"
            ),
            ReadoutStrip.Column(
                id: "source",
                value: Typography.inlineValue("1200 × 1200", unit: "px"),
                caption: "min source"
            )
        ])
    }

    // MARK: Camera

    private var cameraRow: some View {
        Button {
            openCamera()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Typography.button.text("Open camera")
                        .foregroundStyle(cameraAvailable ? Theme.ink : Theme.inkTertiary)

                    Text(cameraAvailable
                         ? "The shutter is released only when the frame passes the gate."
                         : "No camera on this device. The simulator has none — use a photo from the library below.")
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.m)

                Typography.unit.text(cameraAvailable ? "ready" : "none")
                    .foregroundStyle(Theme.inkTertiary)
            }
            .frame(minHeight: Theme.Metrics.tapTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!cameraAvailable)
    }

    /// Shown only when the camera was denied or restricted. The permission
    /// string lives in Info.plist; this is the recovery path.
    private var cameraDeniedRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Camera access is turned off for PassportProof. Turn it on in Settings to capture a frame; the library path below works without it.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.signalFail)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryAction(title: "Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.m)
    }

    // MARK: Camera permission

    private func openCamera() {
        guard cameraAvailable else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCamera = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        cameraDenied = false
                        showCamera = true
                    } else {
                        cameraDenied = true
                    }
                }
            }

        default:
            cameraDenied = true
        }
    }

    // MARK: Review

    private func reviewBlock(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("The captured frame, awaiting review")
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.m)

            gateBlock
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.m)

            PrimaryButton(
                title: "Use this photo",
                isEnabled: canProceed
            ) {
                accept(image)
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.l)

            if pendingSource == .library, gate?.canCapture == false {
                Text("The shutter gate was not applied to this imported frame. Background and lighting are measured on the image exactly as imported, so a busy background will read as a FAIL on those rules.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.margin)
                    .padding(.top, Theme.Spacing.s)
            }

            SecondaryAction(title: "Discard") {
                discard()
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var gateBlock: some View {
        let failed = gateFailure != nil
        let passed = !failed && gate?.canCapture == true
        let tint = failed ? Theme.signalFail : (passed ? Theme.signalPass : Theme.signalFail)
        let wash = passed ? Theme.paper : Theme.failWash
        let headline: String = {
            if let gateFailure { return "Frame could not be measured" }
            if isEvaluating { return "Evaluating the frame" }
            guard let gate else { return "Not evaluated" }
            if gate.canCapture { return "Gate passed" }
            return pendingSource == .camera ? "Gate failed — retake required" : "Gate failed"
        }()
        let message: String = {
            if let gateFailure { return gateFailure }
            if isEvaluating {
                return "Background uniformity and crown contrast are being measured on the captured frame."
            }
            return gate?.message ?? "No gate result."
        }()

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Typography.findingLabel.text(headline)
                .foregroundStyle(tint)

            Text(message)
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Theme.Stroke.statusRail + Theme.Spacing.m)
        .padding(.trailing, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.m)
        .background(wash)
        // The rail is an overlay, not an HStack child: a flexible Rectangle in a
        // vertical ScrollView takes its ideal height, not the row's.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: Theme.Stroke.statusRail)
        }
    }

    // MARK: Actions

    private func adopt(_ image: UIImage, from source: FrameSource, captureDate: Date?) {
        pendingImage = image
        pendingSource = source
        pendingCaptureDate = captureDate
        gate = nil
        gateFailure = nil
        isEvaluating = true

        guard let cgImage = ImageBridge.cgImage(from: image) else {
            isEvaluating = false
            gateFailure = "The frame could not be read as measurable pixels. Try a different photo."
            return
        }

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                CaptureGate.evaluate(frame: cgImage, spec: spec)
            }.value

            await MainActor.run {
                self.gate = result
                self.isEvaluating = false
            }
        }
    }

    private func accept(_ image: UIImage) {
        guard canProceed else { return }

        session.adopt(image, captureDate: pendingCaptureDate)
        session.gate = gate
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        goToAnalysis = true
    }

    private func discard() {
        pendingImage = nil
        gate = nil
        gateFailure = nil
        isEvaluating = false
        pendingCaptureDate = nil
    }
}

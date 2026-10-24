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
                Theme.Rule()
                PhotoImporter(title: "Choose from library") { image in
                    adopt(image)
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
                    adopt(image)
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
            guard cameraAvailable else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCamera = true
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

    // MARK: Review

    private func reviewBlock(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.m)

            gateBlock
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.m)

            PrimaryButton(
                title: "Use this photo",
                isEnabled: gate?.canCapture == true
            ) {
                accept(image)
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.l)

            SecondaryAction(title: "Discard") {
                discard()
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var gateBlock: some View {
        let passed = gate?.canCapture == true
        let tint = passed ? Theme.signalPass : Theme.signalFail
        let wash = passed ? Theme.paper : Theme.failWash
        let headline: String = {
            if isEvaluating { return "Evaluating the frame" }
            guard let gate else { return "Not evaluated" }
            return gate.canCapture ? "Gate passed" : "Gate failed — retake required"
        }()
        let message: String = {
            if isEvaluating {
                return "Background uniformity and crown contrast are being measured on the captured frame."
            }
            return gate?.message ?? "No gate result."
        }()

        return HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(tint)
                .frame(width: Theme.Stroke.statusRail)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Typography.findingLabel.text(headline)
                    .foregroundStyle(tint)

                Text(message)
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(wash)
    }

    // MARK: Actions

    private func adopt(_ image: UIImage) {
        pendingImage = image
        gate = nil
        isEvaluating = true

        guard let cgImage = ImageBridge.cgImage(from: image) else {
            isEvaluating = false
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
        guard gate?.canCapture == true else { return }

        session.adopt(image)
        session.gate = gate
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        goToAnalysis = true
    }

    private func discard() {
        pendingImage = nil
        gate = nil
        isEvaluating = false
    }
}

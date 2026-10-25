//
//  CameraPicker.swift
//  PassportProof
//
//  Custom AVCaptureSession camera with a real pre-shutter gate. Video frames
//  are analysed at a bounded rate; the full-resolution still is captured only
//  after the same background/framing checks pass on the live preview.
//

import AVFoundation
import CoreImage
import SwiftUI
import UIKit

struct CameraPicker: View {
    let spec: DocumentSpec
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var model: CameraModel

    init(
        spec: DocumentSpec,
        onCapture: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.spec = spec
        self.onCapture = onCapture
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: CameraModel(onCapture: onCapture))
    }

    var body: some View {
        ZStack {
            CameraPreview(session: model.controller.session)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.64), .clear, Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            FramingOverlay(spec: spec, drawsGround: false)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 92)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                topBar
                Spacer()
                gateStatus
                shutterBar
            }
        }
        .background(Color.black)
        .statusBarHidden(true)
        .task { model.start(spec: spec) }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.36), in: Circle())
            }
            .accessibilityLabel("Close camera")

            Spacer()

            Label("ON DEVICE", systemImage: "lock.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.36), in: Capsule())
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private var gateStatus: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Image(systemName: model.gate?.canCapture == true ? "checkmark.circle.fill" : "viewfinder")
                .font(.title3)
                .foregroundStyle(model.gate?.canCapture == true ? Color.green : Color.white)
                .symbolEffect(.pulse, isActive: model.gate?.canCapture != true)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.gate?.canCapture == true ? "Ready to capture" : "Setting up your shot")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(model.error ?? model.gate?.message ?? "Starting the camera and looking for a face…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.bottom, Theme.Spacing.l)
        .accessibilityElement(children: .combine)
        .accessibilityLiveRegion(.polite)
    }

    private var shutterBar: some View {
        HStack {
            Label("Grid", systemImage: "grid")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Button {
                model.capture()
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(model.canCapture ? Color.white : Color.white.opacity(0.28))
                        .frame(width: 62, height: 62)
                    if model.isCapturing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .disabled(!model.canCapture)
            .accessibilityLabel("Take photo")
            .accessibilityHint(model.canCapture ? "Captures the reviewed frame" : "Unavailable until the framing guide is ready")
            .accessibilityIdentifier("camera.shutter")

            Label("300 DPI", systemImage: "ruler")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.xxl)
    }
}

@MainActor
private final class CameraModel: ObservableObject {
    let controller = CameraSessionController()

    @Published var gate: CaptureGateResult?
    @Published var error: String?
    @Published var isCapturing = false
    @Published var isRunning = false

    private let onCapture: (UIImage) -> Void

    init(onCapture: @escaping (UIImage) -> Void) {
        self.onCapture = onCapture
        controller.onGate = { [weak self] result in
            self?.gate = result
        }
        controller.onPhoto = { [weak self] image in
            guard let self else { return }
            self.isCapturing = false
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.onCapture(image)
        }
        controller.onError = { [weak self] message in
            self?.error = message
            self?.isCapturing = false
        }
        controller.onRunning = { [weak self] running in
            self?.isRunning = running
        }
    }

    var canCapture: Bool {
        isRunning && !isCapturing && error == nil && gate?.canCapture == true
    }

    func start(spec: DocumentSpec) {
        error = nil
        controller.start(spec: spec)
    }

    func stop() {
        controller.stop()
    }

    func capture() {
        guard canCapture else { return }
        isCapturing = true
        controller.capturePhoto()
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ view: CameraPreviewUIView, context: Context) {
        view.previewLayer.connection?.videoOrientation = .portrait
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private final class CameraSessionController: NSObject {
    let session = AVCaptureSession()

    var onGate: ((CaptureGateResult) -> Void)?
    var onPhoto: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?
    var onRunning: ((Bool) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.passportproof.camera.session")
    private let videoQueue = DispatchQueue(label: "com.passportproof.camera.analysis", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let imageContext = CIContext(options: [.cacheIntermediates: false])

    private var spec: DocumentSpec?
    private var configured = false
    private var isAnalysing = false
    private var lastAnalysis: TimeInterval = 0

    func start(spec: DocumentSpec) {
        self.spec = spec
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configure() }
            guard self.configured else { return }
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            DispatchQueue.main.async { self.onRunning?(running) }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.onRunning?(false) }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.configured, self.session.isRunning else {
                DispatchQueue.main.async { self?.onError?("The camera is not ready. Wait a moment and try again.") }
                return
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            report("No rear camera is available. Choose a photo from your library instead.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                report("The camera input could not be configured.")
                return
            }
            session.addInput(input)

            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(videoOutput) else {
                report("Live framing could not be configured on this device.")
                return
            }
            session.addOutput(videoOutput)
            videoOutput.connection(with: .video)?.videoOrientation = .portrait

            guard session.canAddOutput(photoOutput) else {
                report("Photo capture could not be configured on this device.")
                return
            }
            session.addOutput(photoOutput)
            configured = true
        } catch {
            report("The camera could not be opened. Check access in Settings or choose a library photo.")
        }
    }

    private func report(_ message: String) {
        DispatchQueue.main.async { self.onError?(message) }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let spec,
              !isAnalysing,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastAnalysis >= 0.75 else { return }
        lastAnalysis = now
        isAnalysing = true
        defer { isAnalysing = false }

        // Rear-camera buffers arrive landscape while the preview is portrait.
        // Rotate before measurement so live and still geometry use one axis.
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let extent = oriented.extent
        let longestSide = max(extent.width, extent.height)
        guard longestSide > 0 else { return }
        let scale = min(1, 720 / longestSide)
        let scaled = oriented.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let frame = imageContext.createCGImage(scaled, from: scaled.extent) else { return }

        let result = CaptureGate.evaluate(frame: frame, spec: spec)
        DispatchQueue.main.async { self.onGate?(result) }
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if error != nil {
            report("The photo could not be captured. Keep the camera steady and try again.")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            report("The captured photo could not be read. Try again or choose a library photo.")
            return
        }
        DispatchQueue.main.async { self.onPhoto?(image) }
    }
}

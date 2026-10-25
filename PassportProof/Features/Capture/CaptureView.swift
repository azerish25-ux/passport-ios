import AVFoundation
import SwiftUI
import UIKit

@MainActor
struct CaptureView: View {
    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @State private var showCamera = false
    @State private var cropContext: PhotoEditContext?
    @State private var pendingCameraImage: UIImage?
    @State private var pendingCameraDate: Date?
    @State private var openAnalysisAfterCrop = false
    @State private var goToAnalysis = false
    @State private var cameraDenied = false
    @State private var showEraseConfirmation = false
    @State private var failure: String?

    private var cameraAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                StudioStepProgress(current: 1)
                VStack(alignment: .leading, spacing: 7) {
                    StudioEyebrow(title: "\(spec.documentName) · \(spec.workflow.title)")
                    Text(session.hasPhoto(for: spec) ? "Your photo, ready to refine." : "Start with a good original.")
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if session.hasPhoto(for: spec), let image = session.image {
                    currentPhoto(image)
                } else {
                    introductoryPreview
                }
                sourceCard
                if cameraDenied { cameraDeniedCard }
                if let failure {
                    NoticeCard(icon: "exclamationmark.triangle", title: "Photo not updated",
                               message: failure, tint: Theme.signalFail)
                }
                setupGuide
                Label("Your photo stays on this device. No account or upload.",
                      systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.margin)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera, onDismiss: presentCameraCrop) {
            CameraPicker(spec: spec, onCapture: { image in
                pendingCameraImage = image
                pendingCameraDate = Date()
                showCamera = false
            }, onCancel: {
                pendingCameraImage = nil
                pendingCameraDate = nil
                showCamera = false
            })
        }
        .fullScreenCover(item: $cropContext, onDismiss: openAnalysisIfRequested) { context in
            CropEditorView(context: context, spec: spec, onAccept: { result in
                accept(result, captureDate: context.captureDate)
            }, onCancel: {
                cropContext = nil
            })
        }
        .navigationDestination(isPresented: $goToAnalysis) {
            AnalysisView(spec: spec)
        }
        .alert("Erase this photo?", isPresented: $showEraseConfirmation) {
            Button("Erase photo", role: .destructive) {
                session.clear()
                failure = nil
            }
            .accessibilityIdentifier("capture.erase.confirm")
            Button("Keep photo", role: .cancel) {}
        } message: {
            Text("This removes the original, crop and checks from the current session. Photos in your library are unchanged.")
        }
    }

    private var introductoryPreview: some View {
        StudioCard(padding: 0) {
            VStack(spacing: 0) {
                StudioPortraitArt(style: .portrait, compact: true)
                    .frame(height: 190)
                    .accessibilityHidden(true)
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Image(systemName: "sun.max")
                        .font(.headline).foregroundStyle(Theme.accent)
                    Text("A plain wall and soft, even light make the best starting point.")
                        .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.l)
            }
        }
    }

    private var sourceCard: some View {
        StudioCard(padding: 0) {
            VStack(spacing: 0) {
                Button(action: openCamera) {
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "camera")
                            .font(.title2)
                            .foregroundStyle(cameraAvailable ? Theme.accent : Theme.inkTertiary)
                            .frame(width: 48, height: 48)
                            .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take a photo").font(.headline).foregroundStyle(Theme.ink)
                            Text(cameraAvailable ? "Guidance while someone takes your photo" : "Camera unavailable here. Import a photo below.")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!cameraAvailable)
                .accessibilityIdentifier("capture.camera")
                Theme.Rule().padding(.leading, 84)
                PhotoImporter(title: "Import a photo") { image, captureDate in
                    beginCrop(image: image, captureDate: captureDate)
                }
                .padding(Theme.Spacing.l)
            }
        }
    }

    private func currentPhoto(_ image: UIImage) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack {
                    StudioEyebrow(title: "CURRENT PHOTO")
                    Spacer()
                    if let pixels = session.cgImage {
                        Text("\(pixels.width) × \(pixels.height)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .background(Theme.sageWash)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Current prepared photo")
                PrimaryButton(title: "Review this photo") { goToAnalysis = true }
                    .accessibilityIdentifier("capture.review")
                HStack(spacing: Theme.Spacing.l) {
                    Button {
                        openAnalysisAfterCrop = false
                        cropContext = session.cropEditingContext(for: spec)
                    } label: {
                        Label("Adjust crop", systemImage: "crop")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("capture.edit")
                    Spacer(minLength: 0)
                    Button {
                        showEraseConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityLabel("Erase session photo")
                    .accessibilityIdentifier("capture.erase")
                }
                Text("Adjust from the original, or choose a replacement below. Your current photo stays until you accept a new crop.")
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var setupGuide: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Three things to get right").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            setupRow("1", title: "Use a plain wall", detail: "White or off-white, with no objects or shadows.")
            setupRow("2", title: "Face the light", detail: "Keep both sides of your face evenly lit.")
            setupRow("3", title: "Leave room to frame", detail: "Include the whole head and shoulders. You can crop next.")
        }
    }

    private func setupRow(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Text(number).font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28).background(Theme.sageWash, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.footnote).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cameraDeniedCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("Camera access is off", systemImage: "camera")
                    .font(.headline).foregroundStyle(Theme.ink)
                Text("Enable access in Settings, or import an original photo above.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryAction(title: "Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        }
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

    private func beginCrop(image: UIImage, captureDate: Date?) {
        failure = nil
        openAnalysisAfterCrop = false
        cropContext = PhotoEditContext(originalImage: image, captureDate: captureDate, documentID: spec.id)
    }

    private func presentCameraCrop() {
        guard let image = pendingCameraImage else { return }
        let captureDate = pendingCameraDate
        pendingCameraImage = nil
        pendingCameraDate = nil
        beginCrop(image: image, captureDate: captureDate)
    }

    private func accept(_ result: PreparedPhotoCrop, captureDate: Date?) {
        guard session.acceptCrop(result, for: spec, captureDate: captureDate) else {
            failure = "The crop could not be read. Your previous photo is still available."
            cropContext = nil
            return
        }
        openAnalysisAfterCrop = true
        cropContext = nil
    }

    private func openAnalysisIfRequested() {
        guard openAnalysisAfterCrop else { return }
        openAnalysisAfterCrop = false
        goToAnalysis = true
    }
}

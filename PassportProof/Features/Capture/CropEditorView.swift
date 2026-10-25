import SwiftUI
import UIKit

/// A reversible framing workspace. The session changes only after acceptance.
@MainActor
struct CropEditorView: View {
    let sourceImage: UIImage
    let spec: DocumentSpec
    let onAccept: (PreparedPhotoCrop) -> Void
    let onCancel: () -> Void

    private let originalCGImage: CGImage?
    private let initialTransform: CropTransform?
    private let initialRotationQuarterTurns: Int

    @State private var workingImage: UIImage?
    @State private var workingCGImage: CGImage?
    @State private var transform: CropTransform
    @State private var rotationQuarterTurns: Int
    @State private var dragStart: CGPoint?
    @State private var magnificationStart: CGFloat?
    @State private var showGuides = true
    @State private var hasPrepared = false
    @State private var isPreparing = true
    @State private var isCompleting = false
    @State private var preparationID = UUID()
    @State private var preparationTask: Task<Void, Never>?
    @State private var completionTask: Task<Void, Never>?
    @State private var failure: String?

    init(sourceImage: UIImage, spec: DocumentSpec, initialTransform: CropTransform? = nil,
         initialRotationQuarterTurns: Int = 0, onAccept: @escaping (PreparedPhotoCrop) -> Void,
         onCancel: @escaping () -> Void) {
        self.sourceImage = sourceImage
        self.spec = spec
        self.initialTransform = initialTransform
        self.initialRotationQuarterTurns = initialRotationQuarterTurns
        self.onAccept = onAccept
        self.onCancel = onCancel
        self.originalCGImage = ImageBridge.cgImage(from: sourceImage)
        _transform = State(initialValue: initialTransform ?? .identity)
        _rotationQuarterTurns = State(initialValue: initialRotationQuarterTurns)
    }

    init(context: PhotoEditContext, spec: DocumentSpec, onAccept: @escaping (PreparedPhotoCrop) -> Void,
         onCancel: @escaping () -> Void) {
        self.init(sourceImage: context.originalImage, spec: spec, initialTransform: context.transform,
                  initialRotationQuarterTurns: context.rotationQuarterTurns, onAccept: onAccept, onCancel: onCancel)
    }

    /// Kept for existing callers that need only the prepared pixels.
    init(sourceImage: UIImage, spec: DocumentSpec, initialTransform: CropTransform? = nil,
         onComplete: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.init(sourceImage: sourceImage, spec: spec, initialTransform: initialTransform,
                  onAccept: { onComplete($0.image) }, onCancel: onCancel)
    }

    private var sourceSize: CGSize {
        CGSize(width: workingCGImage?.width ?? 1, height: workingCGImage?.height ?? 1)
    }

    private var cropPixels: CGSize {
        guard workingCGImage != nil else { return .zero }
        let rect = PhotoCrop.cropRect(imageSize: sourceSize, spec: spec, transform: transform)
        let scale = min(1, PhotoCrop.maximumPreparedDimension / max(rect.width, rect.height))
        return CGSize(width: (rect.width * scale).rounded(), height: (rect.height * scale).rounded())
    }

    private var sufficientPixels: Bool {
        cropPixels.width >= CGFloat(spec.widthPixels) && cropPixels.height >= CGFloat(spec.heightPixels)
    }
    private var isBusy: Bool { isPreparing || isCompleting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    StudioStepProgress(current: 1)
                    VStack(alignment: .leading, spacing: 6) {
                        StudioEyebrow(title: "\(spec.documentName) · \(spec.workflow.title)")
                        Text("Make room for your face.")
                            .font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                        Text("Move or zoom the photo. Keep the whole head in view.")
                            .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    preview
                    adjustmentControls
                    if let failure {
                        NoticeCard(icon: "exclamationmark.triangle", title: "Could not prepare this crop",
                                   message: failure, tint: Theme.signalFail)
                    }
                    Label("Your original stays available in this session. Cancel keeps your previous crop.",
                          systemImage: "arrow.uturn.backward")
                        .font(.footnote).foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.margin)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationTitle("Frame your photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .disabled(isCompleting).accessibilityIdentifier("crop.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGuides.toggle() } label: {
                        Image(systemName: showGuides ? "square.grid.3x3.fill" : "square.grid.3x3")
                    }
                    .accessibilityLabel(showGuides ? "Hide framing guides" : "Show framing guides")
                    .accessibilityIdentifier("crop.guides")
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isCompleting ? "Preparing photo…" : "Check this photo",
                              isEnabled: !isBusy && workingCGImage != nil) { complete() }
                    .accessibilityIdentifier("crop.confirm")
                    .padding(.horizontal, Theme.Spacing.margin).padding(.vertical, Theme.Spacing.m)
                    .background(Theme.paperRaised)
                    .overlay(alignment: .top) { Theme.Rule() }
            }
        }
        .interactiveDismissDisabled(isCompleting)
        .task {
            guard !hasPrepared else { return }
            hasPrepared = true
            prepareSource(rotation: initialRotationQuarterTurns, fixedTransform: initialTransform,
                          automatic: initialTransform == nil)
        }
        .onDisappear {
            preparationTask?.cancel()
            completionTask?.cancel()
        }
    }

    private var preview: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scale = max(size.width / max(sourceSize.width, 1), size.height / max(sourceSize.height, 1)) * transform.zoom
            let displaySize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            ZStack {
                Theme.ink
                if let workingImage {
                    Image(uiImage: workingImage)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .offset(x: (0.5 - transform.center.x) * displaySize.width,
                                y: (0.5 - transform.center.y) * displaySize.height)
                        .frame(width: size.width, height: size.height).clipped()
                    if showGuides { CropGuides(spec: spec) }
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.65))
                }
                if isPreparing {
                    ProgressView("Preparing framing…")
                        .font(.footnote.weight(.medium)).padding(16)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: displaySize))
            .simultaneousGesture(magnificationGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Crop preview for \(spec.displayName)")
            .accessibilityHint("Drag or pinch to frame your photo. Move actions and a zoom slider are available.")
            .accessibilityAction(named: "Move crop left") { nudge(x: -0.02, y: 0) }
            .accessibilityAction(named: "Move crop right") { nudge(x: 0.02, y: 0) }
            .accessibilityAction(named: "Move crop up") { nudge(x: 0, y: -0.02) }
            .accessibilityAction(named: "Move crop down") { nudge(x: 0, y: 0.02) }
            .accessibilityIdentifier("crop.preview")
        }
        .aspectRatio(CGFloat(spec.aspectRatio), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.rule, lineWidth: 1)
        }
    }

    private var adjustmentControls: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Framing").font(.headline)
                    Spacer()
                    Text("\(Int(transform.zoom * 100))%")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.inkSecondary)
                }
                Slider(value: Binding(get: { transform.zoom }, set: updateZoom), in: PhotoCrop.zoomRange)
                    .tint(Theme.accent).disabled(isBusy)
                    .accessibilityLabel("Crop zoom")
                    .accessibilityValue("\(Int(transform.zoom * 100)) percent")
                    .accessibilityIdentifier("crop.zoom")
                HStack(spacing: Theme.Spacing.s) {
                    toolButton("Rotate", icon: "rotate.right", identifier: "crop.rotate") {
                        prepareSource(rotation: rotationQuarterTurns + 1, fixedTransform: nil, automatic: true)
                    }
                    toolButton("Auto frame", icon: "viewfinder", identifier: "crop.autoFrame") {
                        prepareSource(rotation: rotationQuarterTurns, fixedTransform: nil, automatic: true)
                    }
                    toolButton("Reset", icon: "arrow.counterclockwise", identifier: "crop.reset") {
                        prepareSource(rotation: 0, fixedTransform: .identity, automatic: false)
                    }
                }
                Theme.Rule()
                Label("\(Int(cropPixels.width)) × \(Int(cropPixels.height)) crop pixels",
                      systemImage: sufficientPixels ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(sufficientPixels ? Theme.accent : Theme.signalVerify)
                    .accessibilityIdentifier("crop.dimensions")
                if !sufficientPixels && workingCGImage != nil {
                    Text("Zoom out or use a larger original to reach \(spec.widthPixels) × \(spec.heightPixels) pixels.")
                        .font(.footnote).foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Theme.ink)
        }
    }

    private func toolButton(_ title: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(Theme.accent)
            .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).disabled(isBusy).accessibilityIdentifier(identifier)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isBusy else { return }
                let start = dragStart ?? transform.center
                if dragStart == nil { dragStart = start }
                transform = clamped(CropTransform(zoom: transform.zoom, center: CGPoint(
                    x: start.x - value.translation.width / max(size.width, 1),
                    y: start.y - value.translation.height / max(size.height, 1)
                )))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !isBusy else { return }
                let start = magnificationStart ?? transform.zoom
                if magnificationStart == nil { magnificationStart = start }
                transform = clamped(CropTransform(zoom: start * value, center: transform.center))
            }
            .onEnded { _ in magnificationStart = nil }
    }

    private func clamped(_ value: CropTransform) -> CropTransform {
        PhotoCrop.clamped(value, imageSize: sourceSize, spec: spec)
    }

    private func updateZoom(_ zoom: CGFloat) {
        guard !isBusy else { return }
        transform = clamped(CropTransform(zoom: zoom, center: transform.center))
    }

    private func nudge(x: CGFloat, y: CGFloat) {
        guard !isBusy else { return }
        transform = clamped(CropTransform(zoom: transform.zoom, center: CGPoint(x: transform.center.x + x, y: transform.center.y + y)))
    }

    private func prepareSource(rotation: Int, fixedTransform: CropTransform?, automatic: Bool) {
        guard !isCompleting, let originalCGImage else {
            isPreparing = false
            failure = "Choose another original photo and try again."
            return
        }
        preparationTask?.cancel()
        let requestID = UUID()
        preparationID = requestID
        isPreparing = true
        failure = nil
        dragStart = nil
        magnificationStart = nil
        let turns = ((rotation % 4) + 4) % 4
        let spec = self.spec
        preparationTask = Task {
            let rotated = await Task.detached(priority: .userInitiated) {
                ImageBridge.rotatedImage(from: originalCGImage, quarterTurns: turns)
            }.value
            guard !Task.isCancelled, preparationID == requestID else { return }
            guard let pixels = rotated.cgImage else {
                isPreparing = false
                failure = "The original could not be rotated. Try another photo."
                return
            }
            let proposed: CropTransform
            if automatic {
                proposed = await Task.detached(priority: .userInitiated) {
                    PhotoCrop.automaticTransform(for: pixels, spec: spec)
                }.value
            } else {
                proposed = fixedTransform ?? .identity
            }
            guard !Task.isCancelled, preparationID == requestID else { return }
            workingImage = rotated
            workingCGImage = pixels
            rotationQuarterTurns = turns
            transform = PhotoCrop.clamped(proposed, imageSize: CGSize(width: pixels.width, height: pixels.height), spec: spec)
            isPreparing = false
        }
    }

    private func complete() {
        guard !isBusy, let pixels = workingCGImage, let originalCGImage else { return }
        isCompleting = true
        failure = nil
        let transform = self.transform
        let turns = rotationQuarterTurns
        let spec = self.spec
        completionTask = Task {
            let cropped = await Task.detached(priority: .userInitiated) {
                PhotoCrop.croppedCGImage(from: pixels, transform: transform, spec: spec)
            }.value
            guard !Task.isCancelled else { return }
            isCompleting = false
            guard let cropped else {
                failure = "Try resetting the crop or choose another original."
                return
            }
            onAccept(PreparedPhotoCrop(originalImage: UIImage(cgImage: originalCGImage),
                                       image: UIImage(cgImage: cropped), transform: transform,
                                       rotationQuarterTurns: turns))
        }
    }
}

private struct CropGuides: View {
    let spec: DocumentSpec

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                Path { path in
                    for fraction in [CGFloat(1.0 / 3), CGFloat(2.0 / 3)] {
                        path.move(to: CGPoint(x: size.width * fraction, y: 0))
                        path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                        path.move(to: CGPoint(x: 0, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                }
                .stroke(.white.opacity(0.48), style: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
                if let eyeRange = spec.eyeLineFromBottomMM {
                    let top = size.height * CGFloat(1 - eyeRange.upperBound / spec.heightMM)
                    let bottom = size.height * CGFloat(1 - eyeRange.lowerBound / spec.heightMM)
                    Rectangle().fill(Theme.accent.opacity(0.15))
                        .frame(width: size.width, height: bottom - top)
                        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.8)).frame(height: 1) }
                        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.8)).frame(height: 1) }
                        .offset(y: top)
                    Text("EYE LINE")
                        .font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.black.opacity(0.52), in: Capsule())
                        .offset(x: 10, y: max(8, top - 29))
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

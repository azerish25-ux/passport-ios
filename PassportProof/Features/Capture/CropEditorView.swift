//
//  CropEditorView.swift
//  PassportProof
//
//  A user-reviewed, aspect-locked crop. No pixels are retouched or synthesized.
//

import SwiftUI
import UIKit

@MainActor
struct CropEditorView: View {
    let sourceImage: UIImage
    let spec: DocumentSpec
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    private let sourceCGImage: CGImage?
    private let startsAutomatically: Bool

    @State private var transform: CropTransform
    @State private var dragStart: CGPoint?
    @State private var magnificationStart: CGFloat?
    @State private var hasInteracted = false
    @State private var isPreparing: Bool
    @State private var isCompleting = false
    @State private var completionTask: Task<Void, Never>?
    @State private var failure: String?

    init(
        sourceImage: UIImage,
        spec: DocumentSpec,
        initialTransform: CropTransform? = nil,
        onComplete: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sourceImage = sourceImage
        self.spec = spec
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.sourceCGImage = ImageBridge.cgImage(from: sourceImage)
        self.startsAutomatically = initialTransform == nil
        _transform = State(initialValue: initialTransform ?? .identity)
        _isPreparing = State(initialValue: initialTransform == nil)
    }

    private var sourceSize: CGSize {
        CGSize(width: sourceCGImage?.width ?? 1, height: sourceCGImage?.height ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { proxy in
                let cropSize = cropSize(in: proxy.size)
                let displaySize = displayedImageSize(in: cropSize)
                let offset = CGSize(
                    width: (0.5 - transform.center.x) * displaySize.width,
                    height: (0.5 - transform.center.y) * displaySize.height
                )

                ZStack {
                    Theme.ink
                    Image(uiImage: sourceImage)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .offset(offset)
                        .frame(width: cropSize.width, height: cropSize.height)
                        .clipped()
                        .overlay { cropGrid }
                        .overlay {
                            Rectangle()
                                .stroke(Theme.paperRaised.opacity(0.85), lineWidth: 1)
                        }
                        .gesture(dragGesture(in: displaySize))
                        .gesture(magnificationGesture(in: cropSize))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Crop preview for \(spec.displayName)")
                        .accessibilityHint("Drag to reposition or pinch to zoom. Accessible crop actions are also available.")
                        .accessibilityAction(named: "Move crop left") { self.nudge(x: -0.02, y: 0) }
                        .accessibilityAction(named: "Move crop right") { self.nudge(x: 0.02, y: 0) }
                        .accessibilityAction(named: "Move crop up") { self.nudge(x: 0, y: -0.02) }
                        .accessibilityAction(named: "Move crop down") { self.nudge(x: 0, y: 0.02) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.m)

            controls
        }
        .background(Theme.paper)
        .interactiveDismissDisabled(isCompleting)
        .task {
            await prepareAutomaticCrop()
        }
        .onDisappear {
            completionTask?.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)
            .disabled(isCompleting)

            Spacer()

            VStack(spacing: Theme.Spacing.xxs) {
                Text("Frame your photo")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(spec.workflow.title)
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
            }

            Spacer()

            Button("Reset") { reset() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(isCompleting)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .frame(minHeight: 64)
        .background(Theme.paperRaised)
    }

    private var cropGrid: some View {
        Image(systemName: "crop")
            .font(.title3)
            .foregroundStyle(Theme.paperRaised.opacity(0.85))
            .padding(Theme.Spacing.s)
            .background(Theme.scrim)
            .clipShape(Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(Theme.Spacing.s)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Label("Pinch or drag to adjust", systemImage: "hand.draw")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Preparing suggested crop")
                }
            }

            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "photo")
                    .foregroundStyle(Theme.inkSecondary)
                Slider(
                    value: Binding(
                        get: { transform.zoom },
                        set: { updateZoom($0) }
                    ),
                    in: PhotoCrop.zoomRange
                )
                .tint(Theme.accent)
                .accessibilityLabel("Crop zoom")
                .accessibilityValue("\(Int(transform.zoom * 100)) percent")
                Image(systemName: "photo.fill")
                    .foregroundStyle(Theme.inkSecondary)
            }

            Text("Only crop and resize are applied. Filters, retouching and background changes are never used.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill")
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.signalFail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(title: isCompleting ? "Preparing photo…" : "Check this photo", isEnabled: !isCompleting && sourceCGImage != nil) {
                complete()
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.xl)
        .background(Theme.paperRaised)
    }

    private func cropSize(in available: CGSize) -> CGSize {
        let width = max(1, available.width)
        let height = max(1, available.height)
        let aspect = CGFloat(spec.aspectRatio)
        var cropWidth = width
        var cropHeight = cropWidth / aspect
        if cropHeight > height {
            cropHeight = height
            cropWidth = cropHeight * aspect
        }
        return CGSize(width: cropWidth, height: cropHeight)
    }

    private func displayedImageSize(in cropSize: CGSize) -> CGSize {
        let baseScale = max(
            cropSize.width / max(sourceSize.width, 1),
            cropSize.height / max(sourceSize.height, 1)
        )
        let scale = baseScale * transform.zoom
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }

    private func dragGesture(in displaySize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                hasInteracted = true
                isPreparing = false
                let start = dragStart ?? transform.center
                if dragStart == nil { dragStart = start }
                transform = clamped(
                    CropTransform(
                        zoom: transform.zoom,
                        center: CGPoint(
                            x: start.x - value.translation.width / max(displaySize.width, 1),
                            y: start.y - value.translation.height / max(displaySize.height, 1)
                        )
                    )
                )
            }
            .onEnded { _ in dragStart = nil }
    }

    private func magnificationGesture(in cropSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                hasInteracted = true
                isPreparing = false
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
        hasInteracted = true
        isPreparing = false
        transform = clamped(CropTransform(zoom: zoom, center: transform.center))
    }

    private func nudge(x: CGFloat, y: CGFloat) {
        hasInteracted = true
        transform = clamped(
            CropTransform(
                zoom: transform.zoom,
                center: CGPoint(x: transform.center.x + x, y: transform.center.y + y)
            )
        )
    }

    private func reset() {
        hasInteracted = false
        failure = nil
        Task { await prepareAutomaticCrop() }
    }

    private func prepareAutomaticCrop() async {
        guard let sourceCGImage else {
            isPreparing = false
            failure = "This photo could not be read. Choose another image."
            return
        }
        isPreparing = true
        let suggested = await Task.detached(priority: .userInitiated) {
            PhotoCrop.automaticTransform(for: sourceCGImage, spec: spec)
        }.value
        guard !Task.isCancelled else { return }
        if !hasInteracted { transform = suggested }
        isPreparing = false
    }

    private func complete() {
        guard !isCompleting else { return }
        isCompleting = true
        failure = nil
        let transform = self.transform
        let sourceImage = self.sourceImage
        let spec = self.spec

        completionTask = Task {
            let cropped = await Task.detached(priority: .userInitiated) {
                PhotoCrop.croppedImage(from: sourceImage, transform: transform, spec: spec)
            }.value
            guard !Task.isCancelled else { return }
            isCompleting = false
            if let cropped {
                onComplete(cropped)
            } else {
                failure = "The crop could not be prepared. Try another photo or a different crop."
            }
        }
    }
}

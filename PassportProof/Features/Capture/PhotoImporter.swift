//
//  PhotoImporter.swift
//  PassportProof
//
//  PhotosUI wrapper. The load happens off the main thread and the decoded
//  `UIImage` is handed back on the main actor. The picker item is reset after
//  each load so choosing the same photo twice fires again.
//
//  The decode goes through ImageIO rather than `UIImage(data:)` for two
//  reasons. First, the EXIF `DateTimeOriginal` travels with the file, and the
//  photo-age rule uses it when available. Second, the working original is
//  bounded to 4096 pixels so retaining it for crop edits does not retain an
//  unbounded camera bitmap. EXIF orientation is baked into the working pixels.
//

import SwiftUI
import PhotosUI
import ImageIO
import UIKit

@MainActor
struct PhotoImporter: View {

    let title: String
    var isEnabled: Bool = true
    let onImage: (UIImage, Date?) -> Void

    /// Sources larger than this are downsampled before entering the session.
    /// Crop resolution is still assessed against the selected workflow.
    nonisolated static let maximumDecodedDimension: CGFloat = 4096

    @State private var item: PhotosPickerItem?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {

            PhotosPicker(selection: $item, matching: .images) {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(isEnabled ? Theme.accent : Theme.inkTertiary)
                        .frame(width: 48, height: 48)
                        .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                            .foregroundStyle(isEnabled ? Theme.ink : Theme.inkTertiary)
                        Text(isLoading ? "Opening your original…" : "Choose an original from your photo library")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Theme.Spacing.m)

                    if isLoading {
                        ProgressView().accessibilityLabel("Loading photo")
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkTertiary)
                    }
                }
                .frame(minHeight: Theme.Metrics.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || isLoading)
            .accessibilityIdentifier("capture.library")

            if didFail {
                Text("This photo could not be opened. If it is in iCloud, download it in Photos and try again, or choose another original.")
                    .font(.footnote)
                    .foregroundStyle(Theme.signalFail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: item) { _, newItem in
            load(newItem)
        }
        .onDisappear {
            loadTask?.cancel()
            isLoading = false
            item = nil
        }
    }

    private func load(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }
        loadTask?.cancel()
        isLoading = true
        didFail = false

        loadTask = Task {
            let data = try? await newItem.loadTransferable(type: Data.self)
            guard !Task.isCancelled else { return }

            // The decode is CPU-bound — for an oversized source it is the
            // expensive step — so it runs off the main actor and only the
            // result comes back.
            let decoded = await Task.detached(priority: .userInitiated) {
                data.flatMap { Self.decodeImage(from: $0) }
            }.value

            guard !Task.isCancelled else { return }
            isLoading = false
            item = nil
            if let decoded {
                onImage(decoded.image, decoded.captureDate)
            } else {
                didFail = true
            }
        }
    }

    // MARK: - Decoding

    /// Decodes image data to a `UIImage` with its EXIF capture date, when the
    /// file carries one. Returns nil when the data is not a readable image.
    nonisolated static func decodeImage(from data: Data) -> (image: UIImage, captureDate: Date?)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let rawProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let captureDate = rawProperties
            .flatMap { $0[kCGImagePropertyExifDictionary] as? [CFString: Any] }
            .flatMap { $0[kCGImagePropertyExifDateTimeOriginal] as? String }
            .flatMap { parseExifDate($0) }

        let width = rawProperties?.getInteger(kCGImagePropertyPixelWidth) ?? 0
        let height = rawProperties?.getInteger(kCGImagePropertyPixelHeight) ?? 0
        let longSide = CGFloat(max(width, height))

        let decodeLimit = longSide > 0 ? min(longSide, maximumDecodedDimension) : maximumDecodedDimension
        guard let cgImage = downsampledImage(from: source, maxDimension: decodeLimit) else {
            return nil
        }
        return (UIImage(cgImage: cgImage), captureDate)
    }

    /// Reads the image at a bounded pixel size. `CreateThumbnailWithTransform`
    /// applies the EXIF rotation, so the pixels come out display-ready.
    nonisolated private static func downsampledImage(from source: CGImageSource, maxDimension: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Parses EXIF's `yyyy:MM:dd HH:mm:ss`. Returns nil for anything else —
    /// a malformed date is "unknown", never a guess.
    nonisolated static func parseExifDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: string)
    }
}

// MARK: - Property helpers

private extension Dictionary where Key == CFString, Value == Any {
    /// Missing dimensions use the bounded thumbnail path as well.
    func getInteger(_ key: CFString) -> Int {
        (self[key] as? NSNumber)?.intValue ?? 0
    }
}

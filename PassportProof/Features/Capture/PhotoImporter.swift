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
//  photo-age rule (R7) needs it: without it the rule can only ever say
//  "cannot verify" for an imported photo. Second, a 48-megapixel library photo
//  decoded at full size allocates roughly 200 MB of bitmap for a measurement
//  that never needs more than 4096 px on the long side; the guard downsamples
//  only oversized sources and leaves every ordinary photo untouched.
//

import SwiftUI
import PhotosUI
import ImageIO
import UIKit

struct PhotoImporter: View {

    let title: String
    var isEnabled: Bool = true
    let onImage: (UIImage, Date?) -> Void

    /// Sources larger than this on the long side are downsampled on decode.
    /// The resolution rule's floor is 1200 px on the short side, so this cap
    /// never turns a compliant photo into a failing one.
    nonisolated static let maximumDecodedDimension: CGFloat = 4096

    @State private var item: PhotosPickerItem?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {

            PhotosPicker(selection: $item, matching: .images) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Typography.button.text(title)
                            .foregroundStyle(isEnabled ? Theme.ink : Theme.inkTertiary)

                        Text(isLoading ? "Reading the file…" : "Photos on this device. Nothing is uploaded.")
                            .typeStyle(Typography.meta)
                            .foregroundStyle(Theme.inkTertiary)
                    }

                    Spacer(minLength: Theme.Spacing.m)

                    Typography.unit.text("photo")
                        .foregroundStyle(Theme.inkTertiary)
                }
                .frame(minHeight: Theme.Metrics.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .disabled(!isEnabled || isLoading)
            .accessibilityIdentifier("capture.library")

            if didFail {
                Text("That file could not be read as an image. Try another photo.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.signalFail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: item) { _, newItem in
            load(newItem)
        }
    }

    private func load(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }

        isLoading = true
        didFail = false

        Task {
            let data = try? await newItem.loadTransferable(type: Data.self)

            // The decode is CPU-bound — for an oversized source it is the
            // expensive step — so it runs off the main actor and only the
            // result comes back.
            let decoded = await Task.detached(priority: .userInitiated) {
                data.flatMap { Self.decodeImage(from: $0) }
            }.value

            await MainActor.run {
                isLoading = false
                item = nil

                if let decoded {
                    onImage(decoded.image, decoded.captureDate)
                } else {
                    didFail = true
                }
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

        if longSide > maximumDecodedDimension {
            // The thumbnail API bakes the EXIF rotation into the pixels, so the
            // result is carried at `.up`.
            guard let cgImage = downsampledImage(from: source, maxDimension: maximumDecodedDimension) else {
                return nil
            }
            return (UIImage(cgImage: cgImage), captureDate)
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        // `CGImageSourceCreateImageAtIndex` returns raw pixels: the EXIF
        // rotation stays metadata. Carry it on the UIImage the way
        // `UIImage(data:)` would, so `ImageBridge` sees the same orientation
        // contract it was written against.
        let exifOrientation = rawProperties?.getInteger(kCGImagePropertyOrientation) ?? 1
        return (UIImage(cgImage: cgImage, scale: 1, orientation: Self.uiOrientation(fromExif: exifOrientation)), captureDate)
    }

    /// EXIF orientation 1–8 → `UIImage.Orientation`. The cases share names and
    /// indices one to one; anything outside 1–8 reads as upright.
    nonisolated private static func uiOrientation(fromExif value: Int) -> UIImage.Orientation {
        switch value {
        case 2: return .upMirrored
        case 3: return .down
        case 4: return .downMirrored
        case 5: return .leftMirrored
        case 6: return .right
        case 7: return .rightMirrored
        case 8: return .left
        default: return .up
        }
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
    /// `CFNumber` pixel dimensions arrive as NSNumber; fail closed to 0, which
    /// routes the decode through the unbounded path only when metadata is absent.
    func getInteger(_ key: CFString) -> Int {
        (self[key] as? NSNumber)?.intValue ?? 0
    }
}

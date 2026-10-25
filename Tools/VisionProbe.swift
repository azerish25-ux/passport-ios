// Standalone diagnostic; not part of the application or its test target.
// Compile with -parse-as-library and run in a NEW process for each mode:
//   VisionProbe <absolute-jpeg-path> <direct|explicit|modern|legacy1>
//
// This probe is specific to the unmodified 1062 × 1210 FullResolutionPortrait
// fixture documented in PassportProofTests/ASSESSMENT-FIXTURES.md. The coarse
// hand-inspected eye/chin regions are sanity checks, not issuer tolerances.
// It uses no application code, UIKit, asset catalogue, or normalizedPoints.

import Foundation
import CoreGraphics
import ImageIO
import Vision
import Darwin

@main
struct VisionProbe {
    enum Mode: String {
        case direct
        case explicit
        case modern
        case legacy1
    }

    struct ProbeError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    struct Measurement {
        let points: [CGPoint]
        let eyeY: Double
        let chinY: Double
    }

    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count == 3, let mode = Mode(rawValue: arguments[2]) else {
            emit(["event": "error", "message": "Usage: VisionProbe <absolute-jpeg-path> <direct|explicit|modern|legacy1>"])
            exit(64)
        }

        let url = URL(fileURLWithPath: arguments[1])
        let repetitions = 12
        var failureCount = 0
        var successfulRequests = 0
        var baseline: Measurement?

        emit([
            "event": "environment",
            "mode": mode.rawValue,
            "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
            "target": targetDescription,
            "architecture": architectureDescription,
            "image": url.lastPathComponent,
            "repetitions": repetitions,
            "landmarkRevision": mode == .modern ? "modern default; recorded per request" as Any : (mode == .legacy1 ? 1 : 3),
            "constellation": mode == .modern ? "modern default" : (mode == .legacy1 ? "65 points" : "76 points"),
            "compute": "system-selected",
            "supportedLandmarkRevisions": Array(VNDetectFaceLandmarksRequest.supportedRevisions),
            "eyeYBoundsFromTop": [0.28, 0.36],
            "chinYBoundsFromTop": [0.53, 0.68],
            "maximumRepeatedImageFractionDrift": 0.001
        ])

        if mode == .modern {
            if #available(iOS 18.0, macOS 15.0, *) {
                exit(await runModern(url: url, repetitions: repetitions))
            }
            emit(["event": "error", "mode": mode.rawValue, "message": "Modern Vision requires iOS 18 or macOS 15."])
            exit(1)
        }

        for index in 0..<repetitions {
            autoreleasepool {
                var record: [String: Any] = ["event": "request", "mode": mode.rawValue, "index": index]
                do {
                    // New ImageIO source and decoded CGImage on every iteration;
                    // the only shared input is the same unchanged JPEG on disk.
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                          let image = CGImageSourceCreateImageAtIndex(
                            source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
                          ) else { throw ProbeError("ImageIO could not decode the JPEG.") }
                    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                    let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
                    let size = CGSize(width: image.width, height: image.height)
                    record["image"] = [
                        "width": image.width,
                        "height": image.height,
                        "orientation": orientation,
                        "bitsPerComponent": image.bitsPerComponent,
                        "bitsPerPixel": image.bitsPerPixel,
                        "bytesPerRow": image.bytesPerRow,
                        "bitmapInfo": image.bitmapInfo.rawValue,
                        "colorSpace": String(describing: image.colorSpace?.name)
                    ]
                    guard image.width == 1062, image.height == 1210, orientation == 1 else {
                        throw ProbeError("This probe's inspected bounds require the original upright 1062 × 1210 fixture.")
                    }

                    // Revision 1 is intentionally a diagnostic of the older,
                    // deprecated implementation, not a production selection.
                    let revision = mode == .legacy1 ? VNDetectFaceLandmarksRequestRevision1 : VNDetectFaceLandmarksRequestRevision3
                    let constellation: VNRequestFaceLandmarksConstellation = mode == .legacy1 ? .constellation65Points : .constellation76Points
                    guard VNDetectFaceLandmarksRequest.supportedRevisions.contains(revision),
                          VNDetectFaceLandmarksRequest.revision(revision, supportsConstellation: constellation) else {
                        throw ProbeError("The requested revision/constellation is unavailable in this runtime.")
                    }
                    let request = VNDetectFaceLandmarksRequest()
                    request.revision = revision
                    request.constellation = constellation

                    if mode == .explicit {
                        // Apple documents passing actual rectangle detections
                        // through inputFaceObservations for landmark analysis:
                        // https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest
                        let rectangles = VNDetectFaceRectanglesRequest()
                        try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([rectangles])
                        let observations = rectangles.results ?? []
                        record["rectangleRevision"] = rectangles.revision
                        record["rectangleFaceCount"] = observations.count
                        record["rectangleBoxes"] = observations.map { boxRecord($0.boundingBox) }
                        guard observations.count == 1 else {
                            throw ProbeError("The explicit rectangle request did not find exactly one face.")
                        }
                        request.inputFaceObservations = observations
                    }

                    try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
                    let faces = request.results ?? []
                    record["landmarkFaceCount"] = faces.count
                    record["requestRevision"] = request.revision
                    record["constellation"] = request.constellation.rawValue
                    guard faces.count == 1, let face = faces.first,
                          let landmarks = face.landmarks,
                          let allRegion = landmarks.allPoints,
                          let contourRegion = landmarks.faceContour,
                          let leftRegion = landmarks.leftEye,
                          let rightRegion = landmarks.rightEye else {
                        throw ProbeError("The landmark request did not provide one face with all required regions.")
                    }
                    record["faceBox"] = boxRecord(face.boundingBox)

                    // Copy public image-coordinate values. No legacy normalized
                    // accessor, application mapper, or subject pixel sampler.
                    let all = imagePoints(allRegion, size: size)
                    let contour = imagePoints(contourRegion, size: size)
                    let left = imagePoints(leftRegion, size: size)
                    let right = imagePoints(rightRegion, size: size)
                    let result = evaluate(all: all, contour: contour, left: left, right: right,
                                          size: size, upperLeft: false, baseline: baseline)
                    record.merge(result.record) { _, new in new }
                    if baseline == nil { baseline = result.measurement }
                    failureCount += result.failures.count
                    if result.failures.isEmpty { successfulRequests += 1 }
                } catch {
                    failureCount += 1
                    record["passed"] = false
                    record["error"] = String(describing: error)
                }
                emit(record)
            }
        }

        exit(finish(mode: mode, repetitions: repetitions, successfulRequests: successfulRequests, failureCount: failureCount))
    }

    static func finish(mode: Mode, repetitions: Int, successfulRequests: Int, failureCount: Int) -> Int32 {
        let passed = failureCount == 0 && successfulRequests == repetitions
        emit([
            "event": "summary", "mode": mode.rawValue, "passed": passed,
            "requests": repetitions, "successfulRequests": successfulRequests,
            "failureCount": failureCount
        ])
        return passed ? 0 : 1
    }

    @available(iOS 18.0, macOS 15.0, *)
    static func runModern(url: URL, repetitions: Int) async -> Int32 {
        var baseline: Measurement?
        var failureCount = 0
        var successfulRequests = 0
        for index in 0..<repetitions {
            var record: [String: Any] = ["event": "request", "mode": Mode.modern.rawValue, "index": index]
            do {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw ProbeError("ImageIO could not decode the JPEG.")
                }
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
                let size = CGSize(width: image.width, height: image.height)
                record["image"] = ["width": image.width, "height": image.height, "orientation": orientation]
                guard image.width == 1062, image.height == 1210, orientation == 1 else {
                    throw ProbeError("This probe's inspected bounds require the original upright 1062 × 1210 fixture.")
                }
                // Follow Apple's public async request and image-coordinate API:
                // https://developer.apple.com/documentation/vision/analyzing-a-selfie-and-visualizing-its-content
                let request = DetectFaceLandmarksRequest()
                record["requestRevision"] = String(describing: request.revision)
                let faces = try await request.perform(on: url, orientation: .up)
                record["landmarkFaceCount"] = faces.count
                guard faces.count == 1, let face = faces.first, let landmarks = face.landmarks else {
                    throw ProbeError("The modern request did not provide exactly one face with landmarks.")
                }
                record["faceBox"] = boxRecord(face.boundingBox.cgRect)
                let result = evaluate(
                    all: landmarks.allPoints.pointsInImageCoordinates(size, origin: .upperLeft),
                    contour: landmarks.faceContour.pointsInImageCoordinates(size, origin: .upperLeft),
                    left: landmarks.leftEye.pointsInImageCoordinates(size, origin: .upperLeft),
                    right: landmarks.rightEye.pointsInImageCoordinates(size, origin: .upperLeft),
                    size: size, upperLeft: true, baseline: baseline
                )
                record.merge(result.record) { _, new in new }
                if baseline == nil { baseline = result.measurement }
                failureCount += result.failures.count
                if result.failures.isEmpty { successfulRequests += 1 }
            } catch {
                failureCount += 1
                record["passed"] = false
                record["error"] = String(describing: error)
            }
            emit(record)
        }
        return finish(mode: .modern, repetitions: repetitions, successfulRequests: successfulRequests, failureCount: failureCount)
    }

    /// All APIs share these unchanged bounds and repeatability checks. Only
    /// the documented origin differs: modern .upperLeft is already top-down.
    static func evaluate(
        all: [CGPoint], contour: [CGPoint], left: [CGPoint], right: [CGPoint],
        size: CGSize, upperLeft: Bool, baseline: Measurement?
    ) -> (record: [String: Any], failures: [String], measurement: Measurement) {
        let regions = [("all", all), ("contour", contour), ("leftEye", left), ("rightEye", right)]
        var record: [String: Any] = [
            "coordinateOrigin": upperLeft ? "upperLeft" : "lowerLeft",
            "pixelRegions": Dictionary(uniqueKeysWithValues: regions.map { ($0.0, pointRange($0.1)) })
        ]
        var failures: [String] = []
        for (name, points) in regions where !valid(points, size: size) {
            failures.append("\(name) has empty, non-finite, or out-of-image coordinates")
        }
        let eyeFraction = (meanY(left) + meanY(right)) / (2 * Double(size.height))
        let eyeY = upperLeft ? eyeFraction : 1 - eyeFraction
        let chinFraction = Double((upperLeft ? contour.map(\.y).max() : contour.map(\.y).min()) ?? .nan) / Double(size.height)
        let chinY = upperLeft ? chinFraction : 1 - chinFraction
        record["eyeYFromTop"] = number(eyeY)
        record["chinYFromTop"] = number(chinY)
        if !eyeY.isFinite || !(0.28...0.36).contains(eyeY) {
            failures.append("eyes are outside the independently inspected fixture region")
        }
        if !chinY.isFinite || !(0.53...0.68).contains(chinY) {
            failures.append("chin is outside the independently inspected fixture region")
        }
        let measurement = Measurement(
            points: all.map { CGPoint(x: $0.x / size.width, y: upperLeft ? $0.y / size.height : 1 - $0.y / size.height) },
            eyeY: eyeY, chinY: chinY
        )
        if let first = baseline {
            let pointDelta = maximumDelta(first.points, measurement.points)
            let eyeDelta = abs(first.eyeY - eyeY)
            let chinDelta = abs(first.chinY - chinY)
            record["pointDriftFromFirst"] = number(pointDelta)
            record["eyeDriftFromFirst"] = number(eyeDelta)
            record["chinDriftFromFirst"] = number(chinDelta)
            if !pointDelta.isFinite || pointDelta > 0.001
                || !eyeDelta.isFinite || eyeDelta > 0.001
                || !chinDelta.isFinite || chinDelta > 0.001 {
                failures.append("identical image pixels produced measurements differing by more than 0.001 image fraction")
            }
        }
        record["failures"] = failures
        record["passed"] = failures.isEmpty
        return (record, failures, measurement)
    }

    static func imagePoints(_ region: VNFaceLandmarkRegion2D, size: CGSize) -> [CGPoint] {
        region.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: $0.y) }
    }

    static func valid(_ points: [CGPoint], size: CGSize) -> Bool {
        !points.isEmpty && points.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && (0...size.width).contains($0.x) && (0...size.height).contains($0.y)
        }
    }

    static func meanY(_ points: [CGPoint]) -> Double {
        guard !points.isEmpty else { return .nan }
        return points.reduce(0) { $0 + Double($1.y) } / Double(points.count)
    }

    static func maximumDelta(_ first: [CGPoint], _ second: [CGPoint]) -> Double {
        guard !first.isEmpty, first.count == second.count else { return .infinity }
        var delta = 0.0
        for (left, right) in zip(first, second) {
            guard left.x.isFinite, left.y.isFinite, right.x.isFinite, right.y.isFinite else { return .infinity }
            delta = max(delta, Double(max(abs(left.x - right.x), abs(left.y - right.y))))
        }
        return delta
    }

    static func pointRange(_ points: [CGPoint]) -> [String: Any] {
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
        return [
            "count": points.count, "finiteCount": finite.count,
            "minX": number(Double(finite.map(\.x).min() ?? .nan)),
            "maxX": number(Double(finite.map(\.x).max() ?? .nan)),
            "minY": number(Double(finite.map(\.y).min() ?? .nan)),
            "maxY": number(Double(finite.map(\.y).max() ?? .nan))
        ]
    }

    static func boxRecord(_ box: CGRect) -> [String: Any] {
        ["x": number(Double(box.minX)), "y": number(Double(box.minY)),
         "width": number(Double(box.width)), "height": number(Double(box.height))]
    }

    // JSON forbids NaN/infinity. Preserve invalid values as explicit strings
    // so an invalid model result cannot silently suppress the entire record.
    static func number(_ value: Double) -> Any { value.isFinite ? value as Any : String(describing: value) }

    static func emit(_ record: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0a]))
        } catch {
            FileHandle.standardError.write(Data("JSON diagnostic encoding failed: \(error)\n".utf8))
            exit(70)
        }
    }

    static var architectureDescription: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "other"
        #endif
    }

    static var targetDescription: String {
        #if targetEnvironment(simulator)
        return "iOS Simulator"
        #elseif os(macOS)
        return "macOS"
        #else
        return "other"
        #endif
    }
}

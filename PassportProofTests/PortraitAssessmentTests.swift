import XCTest
import UIKit
import CoreML
import Vision
@testable import PassportProof

/// Assessment evidence from photographic issuer examples, not an accuracy
/// benchmark. Some reference images are smaller than the required export size;
/// their complete verdict is recorded rather than assumed to be a global pass.
final class PortraitAssessmentTests: XCTestCase {
    private let fixtureNames = ["FullResolutionPortrait", "NeutralPortrait", "BlueBackgroundPortrait", "WhiteBackgroundPortrait"]

    func testFullResolutionPortraitRetainsMeasuredEyesAndChin() throws {
        let source = try fixture(named: "FullResolutionPortrait")
        let analysis = ValidationEngine.analyze(image: source, spec: DocumentCorpus.documents[1])
        record(name: "full-resolution-landmark-regression", image: source, analysis: analysis)
        let geometry = try XCTUnwrap(analysis.geometry, "The full-resolution frontal portrait must provide face geometry; uncertain hair/skull should be reported separately.")
        assertCoarseFullResolutionLandmarks(geometry)
        XCTAssertGreaterThan(geometry.chinY, geometry.eyeY)
        XCTAssertGreaterThan(geometry.eyeY, 0)
        XCTAssertLessThanOrEqual(geometry.chinY, 1)
        XCTAssertNotNil(analysis.findings.first { $0.id == .eyeLine }?.measurement)
    }

    func testRepeatedFullResolutionGeometryIsBoundedAndStable() throws {
        let source = try fixture(named: "FullResolutionPortrait")
        var lines = ["Repeated production geometry; model=\(FaceAnalyzer.defaultModel.rawValue); system-selected compute; real Vision, no injected measurements."]
        defer { attachDiagnostic(lines, name: "repeated-production-geometry") }
        var baseline: FaceGeometry?
        for index in 0..<12 {
            let geometry = FaceAnalyzer.geometry(of: source)
            lines.append("request=\(index) geometry=\(String(describing: geometry))")
            let measured = try XCTUnwrap(geometry, "Repeated request \(index) must retain valid real face measurements.")
            assertCoarseFullResolutionLandmarks(measured)
            XCTAssertTrue((0...1).contains(measured.eyeY))
            XCTAssertTrue((0...1).contains(measured.chinY))
            XCTAssertLessThan(measured.eyeY, measured.chinY)
            if let first = baseline {
                // Identical pixels should not drift between successive reads.
                // This is a repeatability tolerance, not an issuer requirement.
                XCTAssertEqual(measured.eyeY, first.eyeY, accuracy: 0.001, "request \(index)")
                XCTAssertEqual(measured.chinY, first.chinY, accuracy: 0.001, "request \(index)")
            } else {
                baseline = measured
            }
        }
    }

    @MainActor
    func testOfficialPortraitsRecordRealVisionAndPreparedCropFindings() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        print("ASSESSMENT runtime iOS=\(UIDevice.current.systemVersion) operatingSystem=\(ProcessInfo.processInfo.operatingSystemVersionString)")

        for name in fixtureNames {
            let source = try fixture(named: name)
            let sourceGeometry = FaceAnalyzer.geometry(of: source)
            let original = ValidationEngine.analyze(image: source, spec: spec)
            record(name: "\(name)-original", image: source, analysis: original,
                   context: "separateFaceAnalyzerGeometry=\(sourceGeometry == nil ? "nil" : "present")")
            assertAnalysisContract(original, image: source)

            let transform = PhotoCrop.automaticTransform(for: source, spec: spec)
            let crop = try XCTUnwrap(PhotoCrop.croppedCGImage(from: source, transform: transform, spec: spec))
            let prepared = ValidationEngine.analyze(image: crop, spec: spec)
            record(
                name: "\(name)-automatic-crop",
                image: crop,
                analysis: prepared,
                context: "zoom=\(transform.zoom) center=\(transform.center)"
            )
            assertAnalysisContract(prepared, image: crop)
            XCTAssertEqual(Double(crop.width) / Double(crop.height), spec.aspectRatio, accuracy: 0.01)
        }
    }

    func testUnconstrainedAutomaticCropRespectsVisaEyeLine() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let required = try XCTUnwrap(spec.eyeLineFromBottomMM)

        // The small illustrative copies are not guaranteed detector inputs. Try
        // the declared order; a rejected precondition is evidence, not a pass.
        for name in fixtureNames {
            let source = try fixture(named: name)
            let padded = try whiteCanvas(around: source)
            let geometry = FaceAnalyzer.geometry(of: padded)
            record(name: "\(name)-padded-source", image: padded,
                   analysis: ValidationEngine.analyze(image: padded, spec: spec),
                   context: "cropProbeFaceAnalyzerGeometry=\(geometry == nil ? "nil" : "present")")
            guard let geometry else {
                print("ASSESSMENT cropProbe rejected=\(name) reason=production-face-geometry-unavailable")
                continue
            }
            let transform = PhotoCrop.automaticTransform(for: padded, spec: spec)
            let rect = PhotoCrop.cropRect(
                imageSize: CGSize(width: padded.width, height: padded.height),
                spec: spec,
                transform: transform,
                integral: false
            )
            let sourceEyePixelY = geometry.eyeY * Double(padded.height)
            guard rect.minY > 0, rect.maxY < CGFloat(padded.height) else {
                print("ASSESSMENT cropProbe rejected=\(name) reason=unconstrained-placement-precondition-not-established cropRect=\(rect) sourceEyePixelY=\(sourceEyePixelY) zoom=\(transform.zoom)")
                continue
            }
            let cropped = try XCTUnwrap(PhotoCrop.croppedCGImage(from: padded, transform: transform, spec: spec))
            let prepared = ValidationEngine.analyze(image: cropped, spec: spec)

            // Map the original landmark through the real crop. Re-detection is
            // reported independently; it must not conceal a placement error.
            let eyeFromTop = (sourceEyePixelY - Double(rect.minY)) / Double(rect.height)
            let eyeFromBottomMM = (1 - eyeFromTop) * spec.heightMM
            let context = "selectedFixture=\(name) source=\(padded.width)x\(padded.height) cropRect=\(rect) zoom=\(transform.zoom) "
                + "sourceEyeY=\(geometry.eyeY) mappedEyeFromBottomMM=\(eyeFromBottomMM) "
                + "cropCenterMinusSourceEyePX=\(Double(rect.midY) - sourceEyePixelY) "
                + "requiredMM=\(required.lowerBound)...\(required.upperBound) "
                + "redetectedEyeFromBottomMM=\(prepared.geometry.map { (1 - $0.eyeY) * spec.heightMM } as Any)"
            record(name: "\(name)-padded-automatic-crop", image: cropped, analysis: prepared, context: context)
            XCTAssertGreaterThan(rect.minY, 0)
            XCTAssertLessThan(rect.maxY, CGFloat(padded.height))
            assertAnalysisContract(prepared, image: cropped)

            XCTAssertTrue(required.contains(eyeFromBottomMM), context)
            return
        }
        XCTFail("No portrait established measurable, unconstrained source geometry, including the full-resolution fixture. The photographic crop regression was not exercised.")
    }

    /// Exercise the same public image-coordinate accessor as production, with
    /// no normalizedPoints reads anywhere before or within this experiment.
    func testZImagePointAccessorIsBoundedAndStable() throws {
        let source = try fixture(named: "FullResolutionPortrait")
        let imageSize = CGSize(width: source.width, height: source.height)
        var lines = ["Real Vision image-coordinate repeatability. Same observation read three times; no normalized-coordinate accessor."]
        defer { attachDiagnostic(lines, name: "image-point-accessor-repeatability") }
        var baseline: [CGPoint]?
        for index in 0..<12 {
            let request = try FaceAnalyzer.landmarkRequest()
            try VNImageRequestHandler(cgImage: source, orientation: .up, options: [:]).perform([request])
            let faces = request.results ?? []
            lines.append("model=\(FaceAnalyzer.defaultModel.rawValue) revision=\(request.revision) constellation=\(request.constellation.rawValue) devices=\(computeDescription(for: request)) request=\(index) faces=\(faces.count)")
            XCTAssertEqual(faces.count, 1)
            let face = try XCTUnwrap(faces.first)
            let contour = try XCTUnwrap(face.landmarks?.faceContour)
            let reads = (0..<3).map { _ in
                contour.pointsInImage(imageSize: imageSize).map { CGPoint(x: $0.x, y: $0.y) }
            }
            let first = reads[0]
            let normalizedFirst = first.map { FaceAnalyzer.topOriginNormalizedPoint(fromImagePoint: $0, imageSize: imageSize) }
            lines.append("box=\(face.boundingBox) image-pixels-before-normalization \(pointRange(first))")
            for (readIndex, points) in reads.enumerated() {
                let readDelta = maximumPointDelta(first, points)
                lines.append("same-observation-read=\(readIndex) \(pointRange(points)) deltaPixelsFromFirst=\(readDelta)")
                XCTAssertTrue(FaceAnalyzer.imagePointsAreValid(points, imageSize: imageSize),
                              "Image-space landmarks must be finite and inside the image at request \(index).")
                XCTAssertLessThanOrEqual(readDelta, 0.000_001, "Repeated accessor reads must preserve one observation.")
            }
            if let previous = baseline {
                let requestDelta = maximumPointDelta(previous, normalizedFirst)
                lines.append("deltaImageFractionFromFirstRequest=\(requestDelta)")
                XCTAssertLessThanOrEqual(requestDelta, 0.001, "Image coordinates drifted on identical pixels at request \(index).")
            } else {
                baseline = normalizedFirst
            }
        }
    }

    /// Run this legacy-accessor comparison LAST. It is diagnostic only: none of
    /// its values are supplied to production or used to excuse a failed strict
    /// image-coordinate, anatomical-region, or photographic crop regression.
    func testZZNormalizedAccessorComparisonAfterProductionChecks() throws {
        let source = try fixture(named: "FullResolutionPortrait")
        let imageSize = CGSize(width: source.width, height: source.height)
        var lines = ["Diagnostic only: compare public image coordinates before and after the legacy normalized getter on the SAME observation, after all production-path tests."]
        defer { attachDiagnostic(lines, name: "coordinate-accessor-comparison") }
        for index in 0..<8 {
            do {
                let request = try FaceAnalyzer.landmarkRequest()
                try VNImageRequestHandler(cgImage: source, orientation: .up, options: [:]).perform([request])
                let faces = request.results ?? []
                lines.append("model=\(FaceAnalyzer.defaultModel.rawValue) revision=\(request.revision) constellation=\(request.constellation.rawValue) devices=\(computeDescription(for: request)) request=\(index) faces=\(faces.count)")
                guard faces.count == 1, let face = faces.first,
                      let contour = face.landmarks?.faceContour else {
                    lines.append("no single face contour")
                    continue
                }
                let before = contour.pointsInImage(imageSize: imageSize).map { CGPoint(x: $0.x, y: $0.y) }
                let normalizedReads = (0..<3).map { _ in
                    contour.normalizedPoints.map { CGPoint(x: $0.x, y: $0.y) }
                }
                let after = contour.pointsInImage(imageSize: imageSize).map { CGPoint(x: $0.x, y: $0.y) }
                let mappedLegacy = normalizedReads[0].map {
                    CGPoint(x: (face.boundingBox.minX + $0.x * face.boundingBox.width) * imageSize.width,
                            y: (face.boundingBox.minY + $0.y * face.boundingBox.height) * imageSize.height)
                }
                lines.append("image-pixels-before \(pointRange(before))")
                for (readIndex, points) in normalizedReads.enumerated() {
                    lines.append("normalized-read=\(readIndex) \(pointRange(points)) deltaFromFirst=\(maximumPointDelta(normalizedReads[0], points))")
                }
                lines.append("image-pixels-after \(pointRange(after)) deltaFromBefore=\(maximumPointDelta(before, after))")
                lines.append("legacyMappedToImageVsDirectPixelsDelta=\(maximumPointDelta(before, mappedLegacy))")
            } catch {
                lines.append("request=\(index) error=\(error)")
            }
        }
    }

    /// Coarse hand-inspected bounds for this unmodified 1062 × 1210 fixture:
    /// eye centres are near row 390, and the visible chin/beard contour is near
    /// rows 700–790. These deliberately broad image fractions reject a stable
    /// but plainly misplaced model output. They are not issuer tolerances, an
    /// annotated accuracy benchmark, or coordinates supplied to production.
    private func assertCoarseFullResolutionLandmarks(
        _ geometry: FaceGeometry, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue((0.28...0.36).contains(geometry.eyeY),
                      "The measured eyes must lie in the visually inspected eye region, got \(geometry.eyeY).",
                      file: file, line: line)
        XCTAssertTrue((0.53...0.68).contains(geometry.chinY),
                      "The measured chin must lie in the visually inspected lower-face region, got \(geometry.chinY).",
                      file: file, line: line)
    }

    private func fixture(named name: String) throws -> CGImage {
        let image = try XCTUnwrap(UIImage(named: name, in: Bundle(for: Self.self), compatibleWith: nil), "Missing assessment asset: \(name)")
        return try XCTUnwrap(ImageBridge.cgImage(from: image), "Could not decode assessment asset: \(name)")
    }

    private func whiteCanvas(around source: CGImage) throws -> CGImage {
        let width = source.width
        let height = source.height
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width * 3, height: height * 3)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: source).draw(in: CGRect(x: width, y: height, width: width, height: height))
        }
        return try XCTUnwrap(image.cgImage)
    }

    private func assertAnalysisContract(_ analysis: PhotoAnalysis, image: CGImage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(analysis.imagePixelSize, CGSize(width: image.width, height: image.height), file: file, line: line)
        XCTAssertEqual(analysis.findings.map(\.id), RuleID.allCases, file: file, line: line)
        XCTAssertEqual(analysis.overall, ValidationEngine.overall(for: analysis.findings), file: file, line: line)
        XCTAssertEqual(analysis.review, .pending, file: file, line: line)
        if analysis.geometry == nil {
            XCTAssertNil(analysis.background, file: file, line: line)
            for id in [RuleID.headHeight, .headHeightShare, .eyeLine, .centring, .backgroundUniformity] {
                XCTAssertEqual(analysis.findings.first { $0.id == id }?.status, .cannotVerify,
                               "Missing geometry must not become a confident measurement: \(id.rawValue)", file: file, line: line)
            }
        }
        for finding in analysis.findings {
            if let measurement = finding.measurement {
                XCTAssertTrue(measurement.value.isFinite, "Non-finite measurement: \(finding.id.rawValue)", file: file, line: line)
            }
        }
    }

    private func record(name: String, image: CGImage, analysis: PhotoAnalysis, context: String = "") {
        var lines = [
            "ASSESSMENT portrait=\(name) size=\(image.width)x\(image.height) overall=\(analysis.overall.rawValue)",
            "Photographic diagnostic only; reference image resolution may fail. No accuracy or issuer-acceptance claim.",
            visionImagePointSummary(image: image),
            context,
        ]
        if let geometry = analysis.geometry {
            lines.append("geometry eyeY=\(geometry.eyeY) chinY=\(geometry.chinY) inferredCrownY=\(geometry.crownInferredY) envelopeY=\(geometry.crownEnvelopeY) crownDivergence=\(geometry.crownDivergence) hasCrownSilhouette=\(geometry.hasCrownSilhouette)")
        } else {
            lines.append("geometry=nil")
        }
        if let background = analysis.background {
            lines.append("background sigma=\(background.uniformitySigma) crownContrast=\(background.crownContrast) edgeResidual=\(background.edgeResidualFraction)")
        }
        lines += analysis.findings.map { finding in
            let measurement = finding.measurement.map { "value=\($0.value) unit=\($0.unit) required=\($0.displayRange)" } ?? "unmeasured"
            return "\(finding.id.rawValue)=\(finding.status.rawValue) \(measurement) detail=\(finding.detail)"
        }
        let summary = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        print(summary)
        let textAttachment = XCTAttachment(string: summary)
        textAttachment.name = "\(name)-findings"
        textAttachment.lifetime = .keepAlways
        add(textAttachment)
        let imageAttachment = XCTAttachment(image: UIImage(cgImage: image))
        imageAttachment.name = name
        imageAttachment.lifetime = .keepAlways
        add(imageAttachment)
    }

    private func visionImagePointSummary(image: CGImage) -> String {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let imageSize = CGSize(width: image.width, height: image.height)
        do {
            let request = try FaceAnalyzer.landmarkRequest()
            try handler.perform([request])
            let faces = request.results ?? []
            var summary = "rawVisionLandmarkFaceCount=\(faces.count) facesWithLandmarks=\(faces.filter { $0.landmarks != nil }.count) model=\(FaceAnalyzer.defaultModel.rawValue) revision=\(request.revision) constellation=\(request.constellation.rawValue) devices=\(computeDescription(for: request)) (separate diagnostic request; app geometry may reject a detected face)"
            if let face = faces.first, let landmarks = face.landmarks {
                summary += " image-pixels-before-normalization \(pointRange(landmarks.allPoints?.pointsInImage(imageSize: imageSize) ?? []))"
                let eyePoints = (landmarks.leftEye?.pointsInImage(imageSize: imageSize) ?? [])
                    + (landmarks.rightEye?.pointsInImage(imageSize: imageSize) ?? [])
                let mappedEyes = eyePoints.map { FaceAnalyzer.topOriginNormalizedPoint(fromImagePoint: $0, imageSize: imageSize) }
                let mappedChin = landmarks.faceContour?.pointsInImage(imageSize: imageSize).map {
                    FaceAnalyzer.topOriginNormalizedPoint(fromImagePoint: $0, imageSize: imageSize).y
                }.max()
                let mappedEyeY: CGFloat? = mappedEyes.isEmpty ? nil : mappedEyes.map(\.y).reduce(0, +) / CGFloat(mappedEyes.count)
                summary += " box=\(face.boundingBox) mappedEyeY=\(mappedEyeY as Any) mappedChinY=\(mappedChin as Any)"
            }
            return summary
        } catch {
            return "rawVisionLandmarkError=\(error.localizedDescription)"
        }
    }

    private func pointRange(_ points: [CGPoint]) -> String {
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
        return "count=\(points.count) finite=\(finite.count) x=\(finite.map(\.x).min() as Any)...\(finite.map(\.x).max() as Any) y=\(finite.map(\.y).min() as Any)...\(finite.map(\.y).max() as Any)"
    }

    private func maximumPointDelta(_ first: [CGPoint], _ second: [CGPoint]) -> Double {
        guard !first.isEmpty, first.count == second.count else { return .infinity }
        var maximum = 0.0
        for (lhs, rhs) in zip(first, second) {
            guard lhs.x.isFinite, lhs.y.isFinite, rhs.x.isFinite, rhs.y.isFinite else { return .infinity }
            maximum = max(maximum, Double(max(abs(lhs.x - rhs.x), abs(lhs.y - rhs.y))))
        }
        return maximum
    }

    private func computeDescription(for request: VNRequest) -> String {
        guard let stages = try? request.supportedComputeStageDevices else { return "unavailable" }
        return stages.keys.map { stage in
            let name: String
            if let device = request.computeDevice(for: stage) {
                switch device {
                case .cpu: name = "cpu"
                case .gpu: name = "gpu"
                case .neuralEngine: name = "neuralEngine"
                @unknown default: name = "unknown"
                }
            } else {
                name = "automatic"
            }
            return "\(stage)=\(name)"
        }.sorted().joined(separator: ",")
    }

    private func attachDiagnostic(_ lines: [String], name: String) {
        let summary = lines.joined(separator: "\n")
        print(summary)
        let attachment = XCTAttachment(string: summary)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

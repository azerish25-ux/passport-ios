//
//  CaptureGate.swift
//  PassportProof
//
//  The shutter does not fire while the gate is failing.
//
//  Capture enforcement buys the background, not the skull: a compliant updo
//  still puts hair above the crown, so the `cannotVerify` state survives this.
//  All four thresholds below are app-selected defaults, labelled in the UI.
//

import Foundation
import CoreGraphics

struct CaptureGateResult: Sendable {
    let canCapture: Bool
    let message: String
    /// Top of the head silhouette, 0…1 from the top of the frame.
    let headTopFraction: Double?
    /// Chin, 0…1 from the top of the frame.
    let headBottomFraction: Double?
}

enum CaptureGate {

    /// The head may sit up to 15% outside the document's head-height band and
    /// still pass the gate — the gate is a framing aid, not the validator.
    static let headBandTolerance = 0.15

    static func evaluate(frame: CGImage, spec: DocumentSpec) -> CaptureGateResult {
        // The preview guide is the document's aspect box, while the sensor feeds
        // a wider frame. Gate the same central crop the guide represents rather
        // than measuring head share against pixels that will be discarded.
        let measuredFrame = centerCropped(frame, to: spec.aspectRatio) ?? frame

        guard let geometry = FaceAnalyzer.geometry(of: measuredFrame) else {
            return CaptureGateResult(
                canCapture: false,
                message: "No face detected. Fill the frame with your head and shoulders and hold still.",
                headTopFraction: nil,
                headBottomFraction: nil
            )
        }

        let background = BackgroundAnalyzer.analyze(measuredFrame, faceBox: geometry.faceBox)
        let top = geometry.crownEnvelopeY
        let bottom = geometry.chinY

        if background.color?.status == .fail {
            return CaptureGateResult(
                canCapture: false,
                message: "Use a white or off-white background. The wall appears coloured or too dark.",
                headTopFraction: top,
                headBottomFraction: bottom
            )
        }

        // Background first: without an even background the silhouette scan that
        // produces `top` is not trustworthy in the first place.
        if background.uniformitySigma > BackgroundAnalyzer.uniformitySigmaLimit {
            return CaptureGateResult(
                canCapture: false,
                message: "The background is not even. Stand further from the wall and face a single light source.",
                headTopFraction: top,
                headBottomFraction: bottom
            )
        }

        if background.crownContrast < BackgroundAnalyzer.crownContrastLimit {
            return CaptureGateResult(
                canCapture: false,
                message: "Your head does not stand out from the background. Move away from the wall, or find a plainer one.",
                headTopFraction: top,
                headBottomFraction: bottom
            )
        }

        let headFraction = geometry.suggestedHeadHeight(for: spec.headMeasurement)
        guard headFraction > 0.0001 else {
            return CaptureGateResult(
                canCapture: false,
                message: "The head outline could not be measured. Face the camera directly and try again.",
                headTopFraction: top,
                headBottomFraction: bottom
            )
        }

        let targetFraction = (spec.headHeightMM.lowerBound + spec.headHeightMM.upperBound) / 2 / spec.heightMM
        let lowerLimit = targetFraction * (1 - headBandTolerance)
        let upperLimit = targetFraction * (1 + headBandTolerance)

        if headFraction < lowerLimit {
            return CaptureGateResult(
                canCapture: false,
                message: "Your head is too small in the frame. Move closer.",
                headTopFraction: top,
                headBottomFraction: bottom
            )
        }

        if headFraction > upperLimit {
            return CaptureGateResult(
                canCapture: false,
                message: "Your head is too large in the frame. Move back.",
                headTopFraction: top,
                headBottomFraction: bottom
            )
        }

        return CaptureGateResult(
            canCapture: true,
            message: "Framing is good. Hold still.",
            headTopFraction: top,
            headBottomFraction: bottom
        )
    }

    private static func centerCropped(_ image: CGImage, to aspect: Double) -> CGImage? {
        guard aspect > 0, image.width > 0, image.height > 0 else { return nil }
        let imageAspect = Double(image.width) / Double(image.height)
        if abs(imageAspect - aspect) < 0.01 { return image }

        let width: CGFloat
        let height: CGFloat
        if imageAspect > aspect {
            height = CGFloat(image.height)
            width = height * CGFloat(aspect)
        } else {
            width = CGFloat(image.width)
            height = width / CGFloat(aspect)
        }
        let rect = CGRect(
            x: floor((CGFloat(image.width) - width) / 2),
            y: floor((CGFloat(image.height) - height) / 2),
            width: floor(width),
            height: floor(height)
        )
        return image.cropping(to: rect)
    }
}

//
//  CaptureGate.swift
//  PassportProof
//
//  The shutter does not fire while the gate is failing.
//
//  Capture enforcement buys the background, not the skull: a compliant updo
//  still puts hair above the crown, so the `cannotVerify` state survives this.
//  All four thresholds below are prototype defaults.
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
        guard let geometry = FaceAnalyzer.geometry(of: frame) else {
            return CaptureGateResult(
                canCapture: false,
                message: "No face detected. Fill the frame with your head and shoulders and hold still.",
                headTopFraction: nil,
                headBottomFraction: nil
            )
        }

        let background = BackgroundAnalyzer.analyze(frame, faceBox: geometry.faceBox)
        let top = geometry.crownEnvelopeY
        let bottom = geometry.chinY

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

        let headFraction = geometry.headHeight
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
}

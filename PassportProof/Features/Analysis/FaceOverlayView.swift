//
//  FaceOverlayView.swift
//  PassportProof
//
//  The photo, with what the engine measured drawn on it. Everything is placed
//  from `FaceGeometry`, whose coordinates are normalised with the origin at the
//  top-left, so no axis flipping happens here.
//
//  The inferred crown is drawn in `signalVerify`: it is the estimator that can
//  fail to resolve, and when the two estimators diverge the finding is
//  `cannotVerify`. The failing background regions carry `signalFail`, which is
//  what E3 asks for — the user is shown *where* it failed.
//

import SwiftUI

struct FaceOverlayView: View {

    let image: UIImage
    let geometry: FaceGeometry?
    let background: BackgroundReport?
    let spec: DocumentSpec

    private var aspect: CGFloat {
        image.size.height > 0 ? image.size.width / image.size.height : 1
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()

            GeometryReader { proxy in
                let size = proxy.size

                ZStack(alignment: .topLeading) {

                    failingRegions(in: size)
                    headBand(in: size)
                    crownLines(in: size)
                    eyeLine(in: size)
                    centreLine(in: size)
                    faceBox(in: size)
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photograph with the measured face geometry drawn over it")
    }

    // MARK: Layers

    @ViewBuilder
    private func failingRegions(in size: CGSize) -> some View {
        if let background, !background.failingRegions.isEmpty {
            ForEach(Array(background.failingRegions.indices), id: \.self) { index in
                let rect = points(background.failingRegions[index], in: size)
                Rectangle()
                    .fill(Theme.signalFail.opacity(0.22))
                    .overlay(
                        Rectangle()
                            .stroke(Theme.signalFail, lineWidth: Theme.Stroke.rule)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
    }

    @ViewBuilder
    private func headBand(in size: CGSize) -> some View {
        if let geometry {
            let top = CGFloat(geometry.crownEnvelopeY) * size.height
            let bottom = CGFloat(geometry.chinY) * size.height
            let height = max(0, bottom - top)

            Rectangle()
                .fill(Theme.captureInk.opacity(0.10))
                .frame(width: size.width, height: height)
                .overlay(alignment: .top) {
                    Theme.Rule(color: Theme.captureInk, weight: Theme.Stroke.rule)
                }
                .overlay(alignment: .bottom) {
                    Theme.Rule(color: Theme.captureInk, weight: Theme.Stroke.rule)
                }
                .offset(y: top)
        }
    }

    @ViewBuilder
    private func crownLines(in size: CGSize) -> some View {
        if let geometry {
            let envelope = CGFloat(geometry.crownEnvelopeY) * size.height
            let inferred = CGFloat(geometry.crownInferredY) * size.height

            ZStack(alignment: .topLeading) {
                horizontalLine(y: envelope, width: size.width, color: Theme.captureInk, dash: [])
                horizontalLine(y: inferred, width: size.width, color: Theme.signalVerify, dash: [3, 2])

                label("CROWN", x: 0, y: envelope - 18, color: Theme.captureInk)
                label("CROWN · INFERRED", x: 0, y: inferred - 18, color: Theme.signalVerify)
            }
        }
    }

    @ViewBuilder
    private func eyeLine(in size: CGSize) -> some View {
        if let geometry {
            let y = CGFloat(geometry.eyeY) * size.height

            ZStack(alignment: .topLeading) {
                horizontalLine(y: y, width: size.width, color: Theme.captureInk, dash: [4, 3])
                label("EYE", x: 0, y: y - 18, color: Theme.captureInk)
            }
        }
    }

    @ViewBuilder
    private func centreLine(in size: CGSize) -> some View {
        if let geometry {
            let x = CGFloat(geometry.faceCenterX) * size.width

            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            .stroke(
                Theme.captureInk.opacity(0.45),
                style: StrokeStyle(lineWidth: Theme.Stroke.rule, dash: [4, 3])
            )
        }
    }

    @ViewBuilder
    private func faceBox(in size: CGSize) -> some View {
        if let geometry {
            let rect = points(geometry.faceBox, in: size)

            Rectangle()
                .stroke(
                    Theme.captureInk,
                    style: StrokeStyle(lineWidth: Theme.Stroke.rule, dash: [2, 3])
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
    }

    // MARK: Primitives

    private func horizontalLine(
        y: CGFloat,
        width: CGFloat,
        color: Color,
        dash: [CGFloat]
    ) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(
            color,
            style: StrokeStyle(
                lineWidth: Theme.Stroke.rule,
                lineCap: .butt,
                dash: dash.isEmpty ? [] : dash
            )
        )
    }

    private func label(_ text: String, x: CGFloat, y: CGFloat, color: Color) -> some View {
        Typography.unit.text(text)
            .foregroundStyle(color)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.scrim)
            .offset(x: x, y: y)
    }

    /// Normalised (origin top-left) to points.
    private func points(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }
}

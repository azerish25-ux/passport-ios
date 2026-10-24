//
//  FramingOverlay.swift
//  PassportProof
//
//  E1: the live framing guide. Every line on it is computed from the selected
//  document, so the band moves when the document changes and never otherwise.
//
//  Geometry. The guide is the document's aspect box. The chin is taken at the
//  guide's bottom edge, so the crown must land inside the band between the
//  minimum-height crown and the maximum-height crown. That is the only reading
//  of the head-height clause that needs no invented vertical anchor.
//
//  Marks are `onInk` on an `ink` ground, which is how the design system draws
//  both the readout strip and the camera guide.
//

import SwiftUI

struct FramingOverlay: View {
    let spec: DocumentSpec

    /// Paints an `ink` ground behind the guide. Off for the camera overlay,
    /// where the ground is the live feed.
    var drawsGround: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let guide = guideRect(in: proxy.size)

            ZStack(alignment: .topLeading) {
                if drawsGround {
                    Theme.ink
                }

                headBand(guide)
                crownLines(guide)
                chinLine(guide)
                eyeLine(guide)
                centreLine(guide)
                cornerTicks(guide)
            }
        }
    }

    // MARK: Geometry

    private func guideRect(in size: CGSize) -> CGRect {
        let inset = Theme.Spacing.xl
        let availableWidth = max(1, size.width - inset * 2)
        let availableHeight = max(1, size.height - inset * 2)

        let aspect = CGFloat(spec.widthMM / spec.heightMM)
        var width = availableWidth
        var height = width / aspect

        if height > availableHeight {
            height = availableHeight
            width = height * aspect
        }

        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }

    /// Crown when the head is at the maximum permitted height — the highest the
    /// crown may sit.
    private func crownHighY(_ guide: CGRect) -> CGFloat {
        guide.maxY - guide.height * CGFloat(spec.headHeightMM.upperBound / spec.heightMM)
    }

    /// Crown when the head is at the minimum permitted height — the lowest the
    /// crown may sit.
    private func crownLowY(_ guide: CGRect) -> CGFloat {
        guide.maxY - guide.height * CGFloat(spec.headHeightMM.lowerBound / spec.heightMM)
    }

    // MARK: Band

    private func headBand(_ guide: CGRect) -> some View {
        let top = crownHighY(guide)
        let bottom = crownLowY(guide)

        return Rectangle()
            .fill(drawsGround ? Theme.onInk.opacity(0.10) : Theme.captureBand)
            .frame(width: guide.width, height: max(0, bottom - top))
            .overlay(alignment: .top) {
                Theme.Rule(color: Theme.onInk, weight: Theme.Stroke.rule)
            }
            .overlay(alignment: .bottom) {
                Theme.Rule(color: Theme.onInk, weight: Theme.Stroke.rule)
            }
            .offset(x: guide.minX, y: top)
    }

    // MARK: Lines

    private func crownLines(_ guide: CGRect) -> some View {
        let top = crownHighY(guide)
        let bottom = crownLowY(guide)

        return ZStack(alignment: .topLeading) {
            // The solid line is the lower crown limit; the dashed line the upper.
            dashedLine(x1: guide.minX, x2: guide.maxX, y: bottom, dash: [])
            dashedLine(x1: guide.minX, x2: guide.maxX, y: top, dash: [3, 2])

            label("CROWN MIN", at: CGPoint(x: guide.minX, y: bottom - 18))
            label("CROWN MAX", at: CGPoint(x: guide.minX, y: top - 18))
        }
    }

    private func chinLine(_ guide: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            dashedLine(x1: guide.minX, x2: guide.maxX, y: guide.maxY, dash: [3, 2])
            label("CHIN", at: CGPoint(x: guide.minX, y: guide.maxY - 18))
        }
    }

    @ViewBuilder
    private func eyeLine(_ guide: CGRect) -> some View {
        if let eye = spec.eyeLineFromBottomMM {
            let mid = (eye.lowerBound + eye.upperBound) / 2
            let y = guide.maxY - guide.height * CGFloat(mid / spec.heightMM)

            ZStack(alignment: .topLeading) {
                dashedLine(x1: guide.minX, x2: guide.maxX, y: y, dash: [4, 3])
                label("EYE", at: CGPoint(x: guide.minX, y: y - 18))
            }
        }
    }

    private func centreLine(_ guide: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: guide.midX, y: guide.minY))
            path.addLine(to: CGPoint(x: guide.midX, y: guide.maxY))
        }
        .stroke(
            Theme.onInk.opacity(0.45),
            style: StrokeStyle(lineWidth: Theme.Stroke.rule, dash: [4, 3])
        )
    }

    private func cornerTicks(_ guide: CGRect) -> some View {
        let length = Theme.Metrics.captureCornerTickLength

        return Path { path in
            // Top-left
            path.move(to: CGPoint(x: guide.minX, y: guide.minY + length))
            path.addLine(to: CGPoint(x: guide.minX, y: guide.minY))
            path.addLine(to: CGPoint(x: guide.minX + length, y: guide.minY))

            // Top-right
            path.move(to: CGPoint(x: guide.maxX - length, y: guide.minY))
            path.addLine(to: CGPoint(x: guide.maxX, y: guide.minY))
            path.addLine(to: CGPoint(x: guide.maxX, y: guide.minY + length))

            // Bottom-right
            path.move(to: CGPoint(x: guide.maxX, y: guide.maxY - length))
            path.addLine(to: CGPoint(x: guide.maxX, y: guide.maxY))
            path.addLine(to: CGPoint(x: guide.maxX - length, y: guide.maxY))

            // Bottom-left
            path.move(to: CGPoint(x: guide.minX + length, y: guide.maxY))
            path.addLine(to: CGPoint(x: guide.minX, y: guide.maxY))
            path.addLine(to: CGPoint(x: guide.minX, y: guide.maxY - length))
        }
        .stroke(Theme.onInk, style: StrokeStyle(lineWidth: Theme.Stroke.cornerTick, lineCap: .butt))
    }

    // MARK: Primitives

    private func dashedLine(x1: CGFloat, x2: CGFloat, y: CGFloat, dash: [CGFloat]) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x1, y: y))
            path.addLine(to: CGPoint(x: x2, y: y))
        }
        .stroke(
            Theme.onInk,
            style: StrokeStyle(
                lineWidth: Theme.Stroke.rule,
                lineCap: .butt,
                dash: dash.isEmpty ? [] : dash
            )
        )
    }

    private func label(_ text: String, at point: CGPoint) -> some View {
        Typography.unit.text(text)
            .foregroundStyle(Theme.onInk)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.scrim)
            .offset(x: point.x, y: point.y)
    }
}

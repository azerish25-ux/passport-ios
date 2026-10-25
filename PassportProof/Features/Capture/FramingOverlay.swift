import SwiftUI

/// A composition aid, not a measured result. The photo is cropped and checked
/// after capture; the guide deliberately leaves space below the chin.
struct FramingOverlay: View {
    let spec: DocumentSpec
    var drawsGround: Bool = true

    private var ink: Color { drawsGround ? Theme.onInk : .white }

    var body: some View {
        GeometryReader { proxy in
            let guide = guideRect(in: proxy.size)
            let headFraction = CGFloat((spec.headHeightMM.lowerBound + spec.headHeightMM.upperBound) / 2 / spec.heightMM)
            let eyeFraction = spec.eyeLineFromBottomMM.map {
                CGFloat(1 - ($0.lowerBound + $0.upperBound) / 2 / spec.heightMM)
            } ?? 0.42
            let headHeight = guide.height * headFraction
            let eyeY = guide.minY + guide.height * eyeFraction
            // Illustrative oval only: anatomy is not inferred from this drawing.
            let headTop = eyeY - headHeight * 0.43
            let headWidth = headHeight * 0.72
            let head = CGRect(x: guide.midX - headWidth / 2, y: headTop,
                              width: headWidth, height: headHeight)

            ZStack(alignment: .topLeading) {
                if drawsGround { Theme.ink }
                Path { path in
                    path.move(to: CGPoint(x: guide.midX, y: guide.minY))
                    path.addLine(to: CGPoint(x: guide.midX, y: guide.maxY))
                }
                .stroke(ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                RoundedRectangle(cornerRadius: min(head.width, head.height) * 0.46)
                    .stroke(ink.opacity(0.78), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .frame(width: head.width, height: head.height)
                    .offset(x: head.minX, y: head.minY)

                Path { path in
                    let shoulderY = min(guide.maxY, head.maxY + guide.height * 0.11)
                    path.move(to: CGPoint(x: guide.minX + guide.width * 0.1, y: guide.maxY))
                    path.addQuadCurve(to: CGPoint(x: head.minX + head.width * 0.22, y: shoulderY),
                                      control: CGPoint(x: guide.minX + guide.width * 0.1, y: shoulderY))
                    path.move(to: CGPoint(x: head.maxX - head.width * 0.22, y: shoulderY))
                    path.addQuadCurve(to: CGPoint(x: guide.maxX - guide.width * 0.1, y: guide.maxY),
                                      control: CGPoint(x: guide.maxX - guide.width * 0.1, y: shoulderY))
                }
                .stroke(ink.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [5, 6]))

                if let eyeRange = spec.eyeLineFromBottomMM {
                    let top = guide.maxY - guide.height * CGFloat(eyeRange.upperBound / spec.heightMM)
                    let bottom = guide.maxY - guide.height * CGFloat(eyeRange.lowerBound / spec.heightMM)
                    Rectangle().fill(ink.opacity(0.07))
                        .frame(width: guide.width, height: max(0, bottom - top))
                        .offset(x: guide.minX, y: top)
                    Path { path in
                        path.move(to: CGPoint(x: guide.minX, y: eyeY))
                        path.addLine(to: CGPoint(x: guide.maxX, y: eyeY))
                    }
                    .stroke(ink.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }

                cornerMarks(guide)
                    .stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Text("FACE FORWARD")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(drawsGround ? Color.clear : Color.black.opacity(0.36), in: Capsule())
                    .position(x: guide.midX, y: max(12, guide.minY - 14))
            }
        }
        .accessibilityHidden(true)
    }

    private func guideRect(in size: CGSize) -> CGRect {
        let inset: CGFloat = 28
        let widthAvailable = max(1, size.width - inset * 2)
        let heightAvailable = max(1, size.height - inset * 2)
        let aspect = CGFloat(spec.aspectRatio)
        let width = min(widthAvailable, heightAvailable * aspect)
        let height = width / aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func cornerMarks(_ rect: CGRect) -> Path {
        let length = min(22, rect.width * 0.09)
        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
            path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        }
    }
}

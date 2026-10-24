//
//  MeasurementBar.swift
//  PassportProof
//
//  The core gauge, drawn to DesignSystem §4.2. Geometry is fixed; only the data
//  varies. The band never changes colour — the band is the rule, the marker is
//  the fact.
//
//  One deliberate omission: the "NO MEASUREMENT" caption is carried by the
//  summary line rather than floated 4pt above the band, because 7pt of headroom
//  above a 34pt gauge cannot hold an 11pt label without colliding with the row
//  above. The dashed `signalVerify` band line is drawn as specified.
//

import SwiftUI

struct MeasurementBar: View {

    let measurement: Measurement
    let status: FindingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            gauge
                .frame(height: Theme.Metrics.measurementBarHeight)

            summary
                .padding(.top, Theme.Spacing.s)
        }
    }

    // MARK: Gauge

    @ViewBuilder
    private var gauge: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            if let lower = measurement.lowerBound,
               let upper = measurement.upperBound,
               upper > lower {

                let geometry = BarGeometry(
                    width: width,
                    lower: lower,
                    upper: upper,
                    measured: measurement.value
                )

                ZStack(alignment: .topLeading) {

                    // Allowed-range band: fill, then a 1pt rule on each edge.
                    Rectangle()
                        .fill(Theme.bandFill)
                        .frame(
                            width: geometry.bandWidth,
                            height: Theme.Metrics.measurementBandHeight
                        )
                        .overlay(alignment: .top) {
                            Theme.Rule(color: Theme.rule, weight: Theme.Stroke.rule)
                        }
                        .overlay(alignment: .bottom) {
                            Theme.Rule(color: Theme.rule, weight: Theme.Stroke.rule)
                        }
                        .offset(x: geometry.bandX, y: 7)

                    // Axis.
                    Rectangle()
                        .fill(Theme.ruleStrong)
                        .frame(width: width, height: Theme.Stroke.rule)
                        .offset(y: 10)

                    // Ticks, five evenly spaced including both ends.
                    ForEach(Array(0..<Theme.Metrics.measurementTickCount), id: \.self) { index in
                        let step = Double(index) / Double(Theme.Metrics.measurementTickCount - 1)
                        Rectangle()
                            .fill(Theme.rule)
                            .frame(
                                width: Theme.Stroke.hairline,
                                height: Theme.Metrics.measurementTickHeight
                            )
                            .offset(x: min(width - Theme.Stroke.hairline, width * CGFloat(step)), y: 10)
                    }

                    tickLabels(width: width, geometry: geometry)
                    marker(geometry: geometry)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Theme.ruleStrong)
                        .frame(width: width, height: Theme.Stroke.rule)
                        .offset(y: 10)

                    Typography.unit.text("no range published")
                        .foregroundStyle(Theme.inkTertiary)
                        .offset(x: 0, y: 14)
                }
            }
        }
    }

    // MARK: Marker

    @ViewBuilder
    private func marker(geometry: BarGeometry) -> some View {
        if status == .cannotVerify {
            // No marker, no connector. A dashed verify line spans the band.
            Path { path in
                path.move(to: CGPoint(x: geometry.bandX, y: 10))
                path.addLine(to: CGPoint(x: geometry.bandX + geometry.bandWidth, y: 10))
            }
            .stroke(
                Theme.signalVerify,
                style: StrokeStyle(lineWidth: Theme.Stroke.rule, dash: [2, 2])
            )
        } else {
            if !geometry.inRange {
                connector(geometry: geometry)
            }

            Rectangle()
                .fill(geometry.inRange ? Theme.ink : Theme.signalFail)
                .frame(
                    width: Theme.Metrics.measurementMarkerWidth,
                    height: Theme.Metrics.measurementMarkerHeight
                )
                .offset(x: geometry.markerX - Theme.Metrics.measurementMarkerWidth / 2, y: 2)
        }
    }

    /// 1pt `signalFail` from the nearest band edge to the marker.
    private func connector(geometry: BarGeometry) -> some View {
        let below = geometry.markerX < geometry.bandX
        let from = below ? geometry.markerX : geometry.bandX + geometry.bandWidth
        let to = below ? geometry.bandX : geometry.markerX

        return Rectangle()
            .fill(Theme.signalFail)
            .frame(width: max(1, to - from), height: Theme.Stroke.rule)
            .offset(x: from, y: 10)
    }

    // MARK: Tick labels

    /// Only `domainLo`, `lower`, `upper`, and `domainHi` are labelled.
    private func tickLabels(width: CGFloat, geometry: BarGeometry) -> some View {
        ZStack(alignment: .topLeading) {

            HStack(spacing: 0) {
                Text(Format.decimal(geometry.domainLo))
                    .typeStyle(Typography.unit)
                    .foregroundStyle(Theme.inkTertiary)

                Spacer(minLength: Theme.Spacing.s)

                Text(Format.decimal(geometry.domainHi))
                    .typeStyle(Typography.unit)
                    .foregroundStyle(Theme.inkTertiary)
            }
            .frame(width: width, alignment: .leading)
            .offset(y: 15)

            Text(Format.decimal(geometry.lower))
                .typeStyle(Typography.unit)
                .foregroundStyle(Theme.inkTertiary)
                .position(x: geometry.bandX, y: 21)

            Text(Format.decimal(geometry.upper))
                .typeStyle(Typography.unit)
                .foregroundStyle(Theme.inkTertiary)
                .position(x: geometry.bandX + geometry.bandWidth, y: 21)
        }
    }

    // MARK: Summary

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xl) {

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Typography.tabular.text(status == .cannotVerify ? "NO MEASUREMENT" : "MEASURED")
                    .foregroundColor(Theme.inkTertiary)

                if status == .cannotVerify {
                    Typography.measurementInline.text("—")
                        .foregroundColor(Theme.signalVerify)
                } else {
                    Typography.measurementInline.text(measurement.displayValue)
                        .foregroundColor(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Typography.tabular.text("RANGE")
                    .foregroundColor(Theme.inkTertiary)

                Typography.measurementInline.text(measurement.displayRange)
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var valueColor: Color {
        guard let lower = measurement.lowerBound,
              let upper = measurement.upperBound else {
            return Theme.ink
        }
        let inside = measurement.value >= lower && measurement.value <= upper
        return inside ? Theme.ink : Theme.signalFail
    }
}

// MARK: - Geometry

private struct BarGeometry {
    let width: CGFloat
    let lower: Double
    let upper: Double
    let measured: Double

    var span: Double { upper - lower }

    /// `domainLo = max(0, lower − 0.6 × span)`, `domainHi = upper + 0.6 × span`.
    var domainLo: Double { max(0, lower - 0.6 * span) }
    var domainHi: Double { upper + 0.6 * span }

    private var domainSpan: Double { max(0.000_1, domainHi - domainLo) }

    func x(_ value: Double) -> CGFloat {
        width * CGFloat((value - domainLo) / domainSpan)
    }

    var bandX: CGFloat { x(lower) }
    var bandWidth: CGFloat { max(1, x(upper) - x(lower)) }
    var markerX: CGFloat { x(measured) }

    var inRange: Bool { measured >= lower && measured <= upper }
}

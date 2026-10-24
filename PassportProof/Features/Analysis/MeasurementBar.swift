//
//  MeasurementBar.swift
//  PassportProof
//
//  The core gauge, drawn to DesignSystem §4.2. Geometry is fixed; only the data
//  varies. The band never changes colour — the band is the rule, the marker is
//  the fact.
//
//  Two cases the design system does not cover, both of which occur in the real
//  corpus and would otherwise render as a broken row:
//
//  * A lower bound of 0 (`shadow`, `photoAge`, `centring`, `backgroundUniformity`)
//    puts `domainLo == lower == 0`, so the axis-end label and the band-edge label
//    land on the same point. The band-edge label is suppressed near an axis end.
//  * A one-sided rule (`resolution`: ≥ 1200 px, no upper bound). The band is drawn
//    open to the right edge, the synthetic right-hand domain value is not
//    labelled because it means nothing, and the marker still reads against it.
//
//  `markerX` clamps to the gauge width. That is a guard rail, not a layout
//  decision: `domainHi` already widens to include the measurement, so the clamp
//  never fires for any value the engine can produce. Do not remove it, and do
//  not "simplify" the domain back to `lower + 0.6 × span` for the one-sided
//  case — a 3024 px source (12 MP, the common case) would then pin its marker to
//  the right edge and contradict the 3024 px printed underneath it.
//
//  Deliberate omission: the "NO MEASUREMENT" caption is carried by the summary
//  line rather than floated 4pt above the band, because 7pt of headroom above a
//  34pt gauge cannot hold an 11pt label without colliding with the row above.
//  The dashed `signalVerify` band line is drawn as specified.
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

            if let lower = measurement.lowerBound {
                let geometry = BarGeometry(
                    width: width,
                    lower: lower,
                    upper: measurement.upperBound,
                    measured: measurement.value
                )

                ZStack(alignment: .topLeading) {
                    band(geometry)
                    axis(width: width)
                    ticks(width: width)
                    tickLabels(width: width, geometry: geometry)
                    marker(geometry: geometry)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    axis(width: width)

                    Typography.unit.text("no range published")
                        .foregroundStyle(Theme.inkTertiary)
                        .offset(y: 14)
                }
            }
        }
    }

    /// Allowed-range band: fill, then a 1pt rule on each edge. Open to the right
    /// edge when the rule has no upper bound.
    private func band(_ geometry: BarGeometry) -> some View {
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
    }

    private func axis(width: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.ruleStrong)
            .frame(width: width, height: Theme.Stroke.rule)
            .offset(y: 10)
    }

    private func ticks(width: CGFloat) -> some View {
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
                .offset(
                    x: geometry.markerX - Theme.Metrics.measurementMarkerWidth / 2,
                    y: 2
                )
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

    /// Only `domainLo`, `lower`, `upper`, and `domainHi` are labelled. The
    /// right-hand domain value is omitted for a one-sided rule, where it is an
    /// artefact of the axis rather than a bound.
    private func tickLabels(width: CGFloat, geometry: BarGeometry) -> some View {
        ZStack(alignment: .topLeading) {

            HStack(spacing: 0) {
                Text(Format.decimal(geometry.domainLo))
                    .typeStyle(Typography.unit)
                    .foregroundStyle(Theme.inkTertiary)

                Spacer(minLength: Theme.Spacing.s)

                if !geometry.isOpenAbove {
                    Text(Format.decimal(geometry.domainHi))
                        .typeStyle(Typography.unit)
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .frame(width: width, alignment: .leading)
            .offset(y: 15)

            // Suppressed when the band edge sits on an axis end, where the
            // endpoint label above is already drawn.
            if geometry.bandX > Theme.Spacing.l {
                Text(Format.decimal(geometry.lower))
                    .typeStyle(Typography.unit)
                    .foregroundStyle(Theme.inkTertiary)
                    .position(x: geometry.bandX, y: 21)
            }

            if let upper = geometry.upper,
               upper > geometry.lower,
               geometry.bandX + geometry.bandWidth < width - Theme.Spacing.l {
                Text(Format.decimal(upper))
                    .typeStyle(Typography.unit)
                    .foregroundStyle(Theme.inkTertiary)
                    .position(x: geometry.bandX + geometry.bandWidth, y: 21)
            }
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

    /// Mirrors the marker: out of range reads `signalFail`, in range reads `ink`.
    /// A one-sided rule has no upper bound to exceed.
    private var valueColor: Color {
        guard let lower = measurement.lowerBound else { return Theme.ink }
        if measurement.value < lower { return Theme.signalFail }
        if let upper = measurement.upperBound, upper > lower, measurement.value > upper {
            return Theme.signalFail
        }
        return Theme.ink
    }
}

// MARK: - Geometry

private struct BarGeometry {
    let width: CGFloat
    let lower: Double
    /// nil for a one-sided rule such as `resolution` (≥ 1200 px).
    let upper: Double?
    let measured: Double

    /// `span = upper − lower` for a bounded rule. For a one-sided rule there is
    /// no span to speak of, so the axis is padded by 60% of the lower bound.
    private var span: Double {
        if let upper, upper > lower { return upper - lower }
        return max(abs(lower) * 0.6, 0.000_1)
    }

    private var ceiling: Double {
        if let upper, upper > lower { return upper }
        return max(lower, measured)
    }

    /// `max(0, lower − 0.6 × span)` per DesignSystem §4.2, widened only when the
    /// measurement falls below the lower bound and would otherwise plot off the
    /// axis. Widening is what the formula's author would have wanted; it is the
    /// same formula for every value at or above the lower bound.
    var domainLo: Double { max(0, min(lower, measured) - 0.6 * span) }
    var domainHi: Double { max(ceiling, measured) + 0.6 * span }

    private var domainSpan: Double { max(0.000_1, domainHi - domainLo) }

    func x(_ value: Double) -> CGFloat {
        width * CGFloat((value - domainLo) / domainSpan)
    }

    var bandX: CGFloat { x(lower) }

    var bandWidth: CGFloat {
        if let upper, upper > lower { return max(1, x(upper) - bandX) }
        return max(1, width - bandX)
    }

    var markerX: CGFloat { min(max(0, x(measured)), width) }

    /// True when the band runs to the right edge, so no right-hand bound exists.
    var isOpenAbove: Bool {
        if let upper, upper > lower { return false }
        return true
    }

    var inRange: Bool {
        guard measured >= lower else { return false }
        if let upper, upper > lower { return measured <= upper }
        return true
    }
}

//
//  TimelineCurveChart.swift
//  HEMOnitor
//

import SwiftUI

/// The timeline's multi-day level chart: zebra day stripes, reference lines, the
/// filled level curve and a day axis.
///
/// Hand-rolled with `Path`, matching `DecayCurveChart` on Home — the app uses no
/// charting framework, and the mock's exact striping/reference treatment is easier to
/// hit directly than to coax out of one.
///
/// Sized by its content rather than its container: the width is `dayCount × dayWidth`,
/// so the caller scrolls it horizontally instead of the chart compressing.
struct TimelineCurveChart: View {
    let points: [TimelineCurvePoint]
    let range: TimelineRange

    /// Height of the plot area, above the day axis. Shared with `TimelineChartGuides`
    /// so the two line up exactly.
    private let plotHeight = TimelineCurve.plotHeight
    private let topInset = TimelineCurve.plotTopInset
    private let bottomInset = TimelineCurve.plotBottomInset
    private let tickLength: CGFloat = 5

    private var chartWidth: CGFloat {
        CGFloat(range.dayCount) * TimelineCurve.dayWidth
    }

    private var baselineY: CGFloat {
        plotHeight - bottomInset
    }

    var body: some View {
        VStack(spacing: 0) {
            plot
            dayAxis
        }
        .frame(width: chartWidth)
    }

    // MARK: - Plot

    /// Only the parts that belong to specific days live here. The horizontal chrome —
    /// gridlines, reference levels, baseline — is drawn by `TimelineChartGuides`
    /// behind the scroll view, spanning the full viewport. That way overscrolling past
    /// either end reveals chart that simply has no data, rather than a blank gap where
    /// the gridlines stopped.
    private var plot: some View {
        ZStack(alignment: .topLeading) {
            zebra
            curveFill
            dayTicks
        }
        .frame(width: chartWidth, height: plotHeight)
    }

    private var zebra: some View {
        HStack(spacing: 0) {
            ForEach(0..<range.dayCount, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? AppColor.ink.opacity(0.035) : Color.clear)
                    .frame(width: TimelineCurve.dayWidth)
            }
        }
    }

    /// The curve is a filled shape with no stroke, per the mock — the area under the
    /// curve is what carries the meaning here, and at 64pt per day a stroke reads as
    /// noise.
    private var curveFill: some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: x(first.xFraction), y: y(first.displayPercent)))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: x(point.xFraction), y: y(point.displayPercent)))
            }
            path.addLine(to: CGPoint(x: chartWidth, y: baselineY))
            path.addLine(to: CGPoint(x: 0, y: baselineY))
            path.closeSubpath()
        }
        .fill(AppColor.primaryGreen.opacity(0.5))
    }

    private var dayTicks: some View {
        Path { path in
            for index in 0..<range.dayCount {
                let tickX = CGFloat(index) * TimelineCurve.dayWidth
                path.move(to: CGPoint(x: tickX, y: baselineY))
                path.addLine(to: CGPoint(x: tickX, y: baselineY + tickLength))
            }
        }
        .stroke(AppColor.ink.opacity(0.2), lineWidth: 1)
    }

    // MARK: - Day axis

    private var dayAxis: some View {
        HStack(spacing: 0) {
            ForEach(range.days(), id: \.self) { day in
                dayColumn(day)
                    .frame(width: TimelineCurve.dayWidth)
                    // Scroll target: the list below scrolls the chart to a given day
                    // via `ScrollViewReader.scrollTo(day)`.
                    .id(day)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.ink.opacity(0.07))
                .frame(height: 1)
        }
    }

    private func dayColumn(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        return VStack(spacing: 4) {
            Text(day.formatted(.dateTime.day()))
                .font(.jakarta(13, weight: .extraBold))
                .foregroundStyle(isToday ? Color.white : AppColor.ink)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(isToday ? AppColor.primaryGreen : Color.clear)
                }

            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(.jakarta(10.5, weight: .bold))
                .foregroundStyle(AppColor.ink.opacity(0.72))
        }
    }

    // MARK: - Geometry

    private func x(_ fraction: Double) -> CGFloat {
        chartWidth * CGFloat(fraction)
    }

    private func y(_ percent: Double) -> CGFloat {
        TimelineCurve.y(
            forPercent: percent,
            height: plotHeight,
            topInset: topInset,
            bottomInset: bottomInset
        )
    }
}

/// The chart's horizontal chrome: minor gridlines, the three dashed reference levels,
/// and the baseline rule.
///
/// Drawn *behind* the scroll view at full viewport width rather than inside the
/// scrolling content. Nothing here varies by day, so scrolling it would be pointless —
/// and worse, it would end where the data ends, so overscrolling past either edge left
/// a blank white gap. Spanning the viewport means an overscroll reveals an empty
/// stretch of chart with its gridlines intact, which reads as "no data here" instead
/// of as a rendering fault.
struct TimelineChartGuides: View {
    private let plotHeight = TimelineCurve.plotHeight
    private let topInset = TimelineCurve.plotTopInset
    private let bottomInset = TimelineCurve.plotBottomInset

    /// Dashed reference levels, each with the colour it is drawn in.
    private var referenceLines: [(percent: Double, color: Color, opacity: Double)] {
        [
            (100, AppColor.ink, 0.3),
            (40, AppColor.primaryGreen, 0.55),
            (15, AppColor.dangerForeground, 0.55)
        ]
    }

    /// Unlabelled gridlines that give the eye something to read the curve against
    /// between the three labelled levels.
    private let minorLevels: [Double] = [60, 80, 120, 140]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .topLeading) {
                ForEach(minorLevels, id: \.self) { level in
                    line(at: level, width: width)
                        .stroke(AppColor.ink.opacity(0.07), lineWidth: 1)
                }

                ForEach(referenceLines, id: \.percent) { reference in
                    line(at: reference.percent, width: width)
                        .stroke(
                            reference.color.opacity(reference.opacity),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                        )
                }

                Path { path in
                    let baselineY = plotHeight - bottomInset
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: width, y: baselineY))
                }
                .stroke(AppColor.ink.opacity(0.25), lineWidth: 1)
            }
        }
        .frame(height: plotHeight)
        .allowsHitTesting(false)
    }

    private func line(at percent: Double, width: CGFloat) -> Path {
        Path { path in
            let lineY = TimelineCurve.y(
                forPercent: percent,
                height: plotHeight,
                topInset: topInset,
                bottomInset: bottomInset
            )
            path.move(to: CGPoint(x: 0, y: lineY))
            path.addLine(to: CGPoint(x: width, y: lineY))
        }
    }
}

/// The left-edge scale labels. Kept out of `TimelineCurveChart` because they must stay
/// pinned while the chart scrolls horizontally underneath them.
struct TimelineScaleLabels: View {
    private let plotHeight = TimelineCurve.plotHeight
    private let topInset = TimelineCurve.plotTopInset
    private let bottomInset = TimelineCurve.plotBottomInset

    private var labels: [(percent: Double, color: Color)] {
        [
            (100, AppColor.ink.opacity(0.78)),
            (40, AppColor.primaryGreen),
            (15, AppColor.dangerForeground)
        ]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(labels, id: \.percent) { label in
                Text("\(label.percent.wholeNumberText)%")
                    .font(.plexMono(10, weight: .bold))
                    .foregroundStyle(label.color)
                    // Sits just above its own reference line rather than centred on
                    // it, so the dashes stay readable underneath the text.
                    .offset(y: lineY(for: label.percent) - labelHeight - 3)
            }
        }
        .frame(height: plotHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Approximate cap height of the 10pt mono label, used to seat it on its line.
    private let labelHeight: CGFloat = 13

    private func lineY(for percent: Double) -> CGFloat {
        TimelineCurve.y(
            forPercent: percent,
            height: plotHeight,
            topInset: topInset,
            bottomInset: bottomInset
        )
    }
}

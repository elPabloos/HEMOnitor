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

    /// Height of the plot area, above the day axis.
    private let plotHeight: CGFloat = 266
    private let topInset: CGFloat = 14
    private let bottomInset: CGFloat = 14
    private let tickLength: CGFloat = 5

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

    private var plot: some View {
        ZStack(alignment: .topLeading) {
            zebra
            minorGridlines
            referenceGridlines
            curveFill
            baseline
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

    private var minorGridlines: some View {
        ForEach(minorLevels, id: \.self) { level in
            horizontalLine(at: level)
                .stroke(AppColor.ink.opacity(0.07), lineWidth: 1)
        }
    }

    private var referenceGridlines: some View {
        ForEach(referenceLines, id: \.percent) { line in
            horizontalLine(at: line.percent)
                .stroke(
                    line.color.opacity(line.opacity),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
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

    private var baseline: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: baselineY))
            path.addLine(to: CGPoint(x: chartWidth, y: baselineY))
        }
        .stroke(AppColor.ink.opacity(0.25), lineWidth: 1)
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

    private func horizontalLine(at percent: Double) -> Path {
        Path { path in
            let lineY = y(percent)
            path.move(to: CGPoint(x: 0, y: lineY))
            path.addLine(to: CGPoint(x: chartWidth, y: lineY))
        }
    }

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

/// The left-edge scale labels. Kept out of `TimelineCurveChart` because they must stay
/// pinned while the chart scrolls horizontally underneath them.
struct TimelineScaleLabels: View {
    private let plotHeight: CGFloat = 266
    private let topInset: CGFloat = 14
    private let bottomInset: CGFloat = 14

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
                Text("\(Int(label.percent))%")
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

//
//  TimelineCurve.swift
//  HEMOnitor
//

import Foundation

/// One sampled point on the timeline curve.
///
/// `x` is a fraction of the total chart width (0 = the left/oldest edge, 1 = today's
/// right edge) rather than a point value, so the geometry stays independent of the
/// view's size and can be unit-tested without a renderer.
struct TimelineCurvePoint: Equatable {
    let xFraction: Double
    let displayPercent: Double
}

/// The time window a timeline chart covers, in whole days.
struct TimelineRange: Equatable {
    /// Midnight of the first day shown.
    let start: Date
    /// Number of day columns, inclusive of today.
    let dayCount: Int

    /// Midnight of the day after the last one shown — the curve's right edge.
    var end: Date {
        Calendar.current.date(byAdding: .day, value: dayCount, to: start) ?? start
    }

    /// Midnight of each day column, oldest first.
    func days(calendar: Calendar = .current) -> [Date] {
        (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

/// Pure geometry and sampling for the Timeline chart.
///
/// Deliberately separate from `DecayCurve`, which projects *forward* from a single
/// current level for Home's 96-hour look-ahead. This one replays *history*: it walks
/// the injection chain, so each segment decays from the peak of whichever injection
/// preceded it. Neither function's signature fits the other's job, so they stay apart
/// and both defer the actual decay formula to `FactorVIIIModel`.
///
/// Everything here is computed in **real** space and converted to display space only
/// at the final step, per the split described in CLAUDE.md.
enum TimelineCurve {
    /// Day columns are a fixed width, so the chart grows with history and scrolls,
    /// rather than squeezing more days into the same space.
    static let dayWidth: CGFloat = 64

    /// The chart's vertical scale runs to 160 %, not 100 %: a dose peaks well above
    /// 100 % of normal and clipping it would hide the most important part of the curve.
    static let maxPercent: Double = 160

    /// Shortest window shown. With one injection logged today a 1-day chart would be
    /// a single column, so the range is floored at a week.
    static let minimumDays: Int = 7

    /// The window to plot: midnight of the oldest injection through today, never
    /// shorter than `minimumDays`.
    static func range(
        injections: [InjectionEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimelineRange {
        let todayStart = calendar.startOfDay(for: now)
        let floorStart = calendar.date(byAdding: .day, value: -(minimumDays - 1), to: todayStart) ?? todayStart

        let oldest = injections.map(\.date).min() ?? now
        let oldestStart = calendar.startOfDay(for: oldest)
        let start = min(oldestStart, floorStart)

        let spannedDays = calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0
        return TimelineRange(start: start, dayCount: max(minimumDays, spannedDays + 1))
    }

    /// Samples the level across `range`, evenly in time.
    ///
    /// Sampling is clamped at `now`, so the portion of today that hasn't happened yet
    /// flat-lines at the current level instead of predicting forward — this screen is
    /// a record of what happened, and Home already owns the forecast.
    static func sample(
        injections: [InjectionEvent],
        model: FactorVIIIModel,
        range: TimelineRange,
        now: Date = Date(),
        sampleCount: Int = 240
    ) -> [TimelineCurvePoint] {
        guard sampleCount > 0 else { return [] }

        let start = range.start.timeIntervalSince1970
        let span = range.end.timeIntervalSince1970 - start
        guard span > 0 else { return [] }

        return (0...sampleCount).map { index in
            let fraction = Double(index) / Double(sampleCount)
            let instant = min(start + fraction * span, now.timeIntervalSince1970)
            let real = realLevel(at: Date(timeIntervalSince1970: instant), injections: injections, model: model)
            return TimelineCurvePoint(
                xFraction: fraction,
                displayPercent: max(0, model.displayLevel(fromRealPercent: real))
            )
        }
    }

    /// The real (uncalibrated) level at an arbitrary instant, decayed from the most
    /// recent injection at or before it.
    ///
    /// This mirrors `FactorTrackerViewModel.recalculateLevels(at:)`, but as a pure
    /// query — that method mutates published state and so cannot be called once per
    /// sample point.
    static func realLevel(
        at instant: Date,
        injections: [InjectionEvent],
        model: FactorVIIIModel
    ) -> Double {
        guard let last = injections.last(where: { $0.date <= instant }) else {
            return model.baselinePercent
        }
        let hours = instant.timeIntervalSince(last.peakDate) / 3600
        return model.levelAtTime(peakPercent: last.peakRealPercent, hoursSincePeak: max(0, hours))
    }

    /// Maps a percentage onto a y position within a plot of `height`, inset by
    /// `topInset`/`bottomInset`. Higher percentages sit higher on screen.
    static func y(
        forPercent percent: Double,
        height: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) -> CGFloat {
        let bottom = height - bottomInset
        let usable = bottom - topInset
        guard usable > 0 else { return bottom }
        let clamped = min(max(percent, 0), maxPercent)
        return bottom - CGFloat(clamped / maxPercent) * usable
    }
}

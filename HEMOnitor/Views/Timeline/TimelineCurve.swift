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

/// One day column's axis label, resolved ahead of render.
///
/// The chart used to format these inside its `body`: a `Date.formatted` call plus
/// `Calendar` queries per column, redone every time the marked day changed. At a
/// few months of history that is several hundred formatter invocations per rebuild —
/// enough on its own to miss a frame, and it landed squarely in the middle of a scroll.
/// Formatting once per history change and handing the chart plain strings removes all
/// of it from the scrolling path.
struct TimelineDayLabel: Identifiable, Equatable {
    /// Midnight of the day this column represents.
    let day: Date
    /// Day of the month, e.g. "21".
    let dayNumber: String
    /// Whether this column is today, so the axis can keep it findable.
    let isToday: Bool

    var id: Date { day }
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

    /// Plot geometry, shared so the scrolling content and the fixed chrome drawn
    /// behind it land on exactly the same y positions.
    static let plotHeight: CGFloat = 266
    static let plotTopInset: CGFloat = 14
    static let plotBottomInset: CGFloat = 14

    /// Gap between the plot and the row of day numbers. Shared because the centred
    /// day marker is drawn as a fixed overlay on the viewport rather than inside the
    /// scrolling axis, and the two have to land on the same y.
    static let dayAxisTopPadding: CGFloat = 10

    /// Side of the square frame each day number sits in — and therefore the diameter of
    /// the centred-day circle drawn over it. A fixed frame, not a text metric, so the
    /// marker's geometry holds whatever the rendered type size.
    static let dayNumberSize: CGFloat = 34

    /// Gap below the day numbers, closing out the axis.
    static let dayAxisBottomPadding: CGFloat = 12

    /// Total height of the chart: the plot, plus the day axis and its padding. Derived
    /// rather than hardcoded so removing or resizing part of the axis cannot leave a
    /// band of empty space below it.
    static let chartHeight: CGFloat =
        plotHeight + dayAxisTopPadding + dayNumberSize + dayAxisBottomPadding

    /// Furthest the chart will ever project beyond today, however slowly the level is
    /// decaying. Past this the curve is a flat line at baseline and adds nothing.
    static let maximumFutureDays: Int = 14

    /// The window to plot: midnight of the oldest injection through today, plus
    /// `futureDays` of projection, never shorter than `minimumDays`.
    static func range(
        injections: [InjectionEvent],
        now: Date = Date(),
        calendar: Calendar = .current,
        futureDays: Int = 0
    ) -> TimelineRange {
        let todayStart = calendar.startOfDay(for: now)
        let floorStart = calendar.date(byAdding: .day, value: -(minimumDays - 1), to: todayStart) ?? todayStart

        let oldest = injections.map(\.date).min() ?? now
        let oldestStart = calendar.startOfDay(for: oldest)
        let start = min(oldestStart, floorStart)

        let spannedDays = calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0
        let trailing = min(max(futureDays, 0), maximumFutureDays)
        return TimelineRange(start: start, dayCount: max(minimumDays, spannedDays + 1 + trailing))
    }

    /// How many days ahead the chart should keep plotting before the level has decayed
    /// back to baseline and there is nothing left to show.
    ///
    /// Returns 0 when the level is already at baseline. `hoursUntilLevelReaches`
    /// approaches baseline asymptotically and never actually arrives, so this aims at
    /// a small margin above it rather than at baseline itself.
    static func projectedFutureDays(
        model: FactorVIIIModel,
        currentRealPercent: Double,
        marginAboveBaseline: Double = 0.5
    ) -> Int {
        let target = model.baselinePercent + marginAboveBaseline
        guard let hours = model.hoursUntilLevelReaches(
            targetRealPercent: target,
            fromRealPercent: currentRealPercent
        ) else {
            return 0
        }
        return min(max(Int((hours / 24).rounded(.up)), 0), maximumFutureDays)
    }

    /// Samples the level across `range`, evenly in time.
    ///
    /// Sampling runs to the end of the range, including days after `now`. Those are a
    /// projection: the decay simply continues from the last injection, which is what
    /// makes the "days remaining" tail meaningful. An earlier version clamped at `now`
    /// on the grounds that this screen is a record rather than a forecast — but with
    /// the range deliberately extended past today, clamping would draw that tail as a
    /// flat line at the current level, which would be wrong rather than conservative.
    static func sample(
        injections: [InjectionEvent],
        model: FactorVIIIModel,
        range: TimelineRange,
        sampleCount: Int = 240
    ) -> [TimelineCurvePoint] {
        guard sampleCount > 0 else { return [] }

        let start = range.start.timeIntervalSince1970
        let span = range.end.timeIntervalSince1970 - start
        guard span > 0 else { return [] }

        return (0...sampleCount).map { index in
            let fraction = Double(index) / Double(sampleCount)
            let instant = start + fraction * span
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

    /// How far the chart should be slid horizontally, given how far the injection list
    /// has scrolled vertically.
    ///
    /// Mirrors the design mock's coupling exactly — the mock computes
    /// `scrollLeft = (1 - verticalFraction) * maxHorizontalScroll`, a *continuous*
    /// mapping rather than a snap to whole days. The list runs newest-first, so
    /// scrolling down walks back in time: at the top the chart sits on today (fully
    /// scrolled right), at the bottom on the oldest day (fully left).
    ///
    /// Returns how many points of chart content should sit to the left of the
    /// viewport, in `0...maxChartScroll` — i.e. a scroll-view content offset, with 0
    /// showing the oldest day and `maxChartScroll` showing today.
    ///
    /// Pure so the coupling can be tested without a scroll gesture — which the agent
    /// cannot synthesise (see CLAUDE.md). Note that this verifies the *mapping* only;
    /// whether the scroll handler fires at all is not something a test can establish.
    static func chartScrollOffset(
        scrollOffset: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        maxChartScroll: CGFloat
    ) -> CGFloat {
        guard maxChartScroll > 0 else { return 0 }

        let scrollable = contentHeight - viewportHeight
        // Nothing to scroll through: stay pinned on today.
        guard scrollable > 1 else { return maxChartScroll }

        let progress = min(max(Double(scrollOffset / scrollable), 0), 1)
        return CGFloat(1 - progress) * maxChartScroll
    }

    /// Resolves every day column's axis labels in one pass, reusing a single calendar.
    ///
    /// Called when the history changes, never from a view's `body` — see
    /// `TimelineDayLabel`.
    static func dayLabels(for range: TimelineRange, calendar: Calendar = .current) -> [TimelineDayLabel] {
        range.days(calendar: calendar).map { day in
            TimelineDayLabel(
                day: day,
                dayNumber: day.formatted(.dateTime.day()),
                isToday: calendar.isDateInToday(day)
            )
        }
    }

    /// Index of the day column sitting at the centre of the viewport, given how far
    /// the chart is scrolled. This is the day that carries the filled marker, so the
    /// marker names whichever day you have scrolled to rather than always today.
    static func centredDayIndex(
        scrollOffset: CGFloat,
        viewportWidth: CGFloat,
        dayCount: Int
    ) -> Int {
        guard dayCount > 0 else { return 0 }
        let centreX = scrollOffset + viewportWidth / 2
        let index = Int((centreX / dayWidth).rounded(.down))
        return min(max(index, 0), dayCount - 1)
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

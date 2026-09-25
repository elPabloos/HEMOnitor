//
//  TimelineCurveTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

struct TimelineCurveTests {

    // MARK: - Fixtures

    /// A fixed clock keeps day-boundary maths deterministic. Midday avoids the case
    /// where "now" sits within rounding distance of midnight.
    private var now: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 23
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    private func model() -> FactorVIIIModel {
        FactorVIIIModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)
    }

    private func injection(daysAgo: Double, doseIU: Double = 3000, peak: Double = 94) -> InjectionEvent {
        InjectionEvent(
            id: UUID(),
            date: now.addingTimeInterval(-daysAgo * 86_400),
            doseIU: doseIU,
            realLevelBefore: 2,
            peakRealPercent: peak
        )
    }

    private func isClose(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - Range

    @Test func rangeFloorsAtSevenDaysWhenHistoryIsShort() {
        let range = TimelineCurve.range(injections: [injection(daysAgo: 1)], now: now)
        #expect(range.dayCount == 7)
    }

    @Test func rangeFloorsAtSevenDaysWhenThereIsNoHistory() {
        let range = TimelineCurve.range(injections: [], now: now)
        #expect(range.dayCount == 7)
    }

    @Test func rangeSpansFromTheOldestInjection() {
        let range = TimelineCurve.range(
            injections: [injection(daysAgo: 21), injection(daysAgo: 3)],
            now: now
        )
        // 21 days back through today, inclusive of both endpoints.
        #expect(range.dayCount == 22)
    }

    @Test func rangeStartsAtMidnightOfTheOldestDay() {
        let range = TimelineCurve.range(injections: [injection(daysAgo: 10)], now: now)
        #expect(range.start == Calendar.current.startOfDay(for: range.start))
    }

    @Test func rangeProducesOneDayPerColumn() {
        let range = TimelineCurve.range(injections: [injection(daysAgo: 12)], now: now)
        #expect(range.days().count == range.dayCount)
    }

    // MARK: - Sampling

    @Test func sampleReturnsRequestedNumberOfPoints() {
        let range = TimelineCurve.range(injections: [injection(daysAgo: 5)], now: now)
        let points = TimelineCurve.sample(
            injections: [injection(daysAgo: 5)],
            model: model(),
            range: range,
            sampleCount: 240
        )
        // Inclusive of both ends.
        #expect(points.count == 241)
    }

    @Test func sampleSpansTheFullWidth() {
        let range = TimelineCurve.range(injections: [injection(daysAgo: 5)], now: now)
        let points = TimelineCurve.sample(
            injections: [injection(daysAgo: 5)],
            model: model(),
            range: range
        )
        #expect(isClose(points.first!.xFraction, 0))
        #expect(isClose(points.last!.xFraction, 1))
    }

    @Test func levelSitsAtBaselineBeforeAnyInjection() {
        let event = injection(daysAgo: 2)
        let level = TimelineCurve.realLevel(
            at: now.addingTimeInterval(-5 * 86_400),
            injections: [event],
            model: model()
        )
        #expect(isClose(level, 2))
    }

    @Test func levelEqualsPeakAtTheMomentOfInjection() {
        let event = injection(daysAgo: 2, peak: 94)
        let level = TimelineCurve.realLevel(at: event.date, injections: [event], model: model())
        #expect(isClose(level, 94))
    }

    @Test func levelDecaysByHalfOverOneHalfLife() {
        let event = injection(daysAgo: 2, peak: 94)
        let oneHalfLifeLater = event.date.addingTimeInterval(19 * 3600)
        let level = TimelineCurve.realLevel(
            at: oneHalfLifeLater,
            injections: [event],
            model: model()
        )
        // Only the infused component halves; baseline is the floor it decays toward.
        #expect(isClose(level, 2 + (94 - 2) * 0.5))
    }

    @Test func laterInjectionTakesOverFromEarlierOne() {
        let older = injection(daysAgo: 4, peak: 50)
        let newer = injection(daysAgo: 1, peak: 90)
        let level = TimelineCurve.realLevel(
            at: newer.date,
            injections: [older, newer],
            model: model()
        )
        #expect(isClose(level, 90))
    }

    @Test func samplingProjectsPastNowRatherThanFlatLining() {
        // The range now deliberately extends beyond today so the chart can show how
        // much cover is left. Samples after `now` must keep decaying rather than hold
        // the current level — the opposite of what this screen did originally.
        let event = injection(daysAgo: 0.5, peak: 80)
        let range = TimelineCurve.range(injections: [event], now: now, futureDays: 3)
        let points = TimelineCurve.sample(injections: [event], model: model(), range: range)

        let levelAtNow = TimelineCurve.realLevel(at: now, injections: [event], model: model())
        #expect(points.last!.displayPercent < levelAtNow)
        // ...and never below baseline.
        #expect(points.last!.displayPercent >= 2)
    }

    @Test func calibrationScalesDisplayedValuesOnly() {
        let event = injection(daysAgo: 1, peak: 50)
        var calibrated = model()
        calibrated.calibrationFactor = 2

        let range = TimelineCurve.range(injections: [event], now: now)
        let plain = TimelineCurve.sample(injections: [event], model: model(), range: range)
        let scaled = TimelineCurve.sample(injections: [event], model: calibrated, range: range)

        for (a, b) in zip(plain, scaled) {
            #expect(isClose(b.displayPercent, a.displayPercent * 2, 1e-6))
        }
    }

    // MARK: - Vertical scale

    @Test func oneHundredSixtyPercentSitsAtTheTopOfTheScale() {
        let y = TimelineCurve.y(forPercent: 160, height: 266, topInset: 14, bottomInset: 14)
        #expect(isClose(Double(y), 14))
    }

    @Test func zeroPercentSitsOnTheBaseline() {
        let y = TimelineCurve.y(forPercent: 0, height: 266, topInset: 14, bottomInset: 14)
        #expect(isClose(Double(y), 252))
    }

    @Test func percentagesAboveTheScaleAreClampedNotClipped() {
        let overshoot = TimelineCurve.y(forPercent: 400, height: 266, topInset: 14, bottomInset: 14)
        let top = TimelineCurve.y(forPercent: 160, height: 266, topInset: 14, bottomInset: 14)
        #expect(isClose(Double(overshoot), Double(top)))
    }

    @Test func higherPercentagesSitHigherOnScreen() {
        let low = TimelineCurve.y(forPercent: 15, height: 266, topInset: 14, bottomInset: 14)
        let high = TimelineCurve.y(forPercent: 100, height: 266, topInset: 14, bottomInset: 14)
        #expect(high < low)
    }

    // MARK: - Day labels
    //
    // These are precomputed so the chart does no date formatting while scrolling. The
    // values are what the axis renders, so they are worth pinning down — but only the
    // properties that matter, not every string for every locale.

    @Test func oneLabelPerDayColumnInOrder() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let labels = TimelineCurve.dayLabels(for: TimelineRange(start: start, dayCount: 5), calendar: calendar)

        #expect(labels.count == 5)
        #expect(labels.map(\.day) == TimelineRange(start: start, dayCount: 5).days(calendar: calendar))
    }

    @Test func exactlyOneColumnIsMarkedToday() {
        let calendar = Calendar.current
        // A window starting two days ago necessarily contains today.
        let start = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date()))!
        let labels = TimelineCurve.dayLabels(for: TimelineRange(start: start, dayCount: 5), calendar: calendar)

        #expect(labels.filter(\.isToday).count == 1)
        #expect(labels[2].isToday)
    }

    @Test func noColumnIsMarkedTodayInAPurelyHistoricWindow() {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: Date()))!
        let labels = TimelineCurve.dayLabels(for: TimelineRange(start: start, dayCount: 7), calendar: calendar)

        #expect(labels.allSatisfy { !$0.isToday })
    }

    /// Day numbers must keep counting across a month boundary rather than restarting —
    /// the axis showed ... 30, 31, 1, 2 ... incorrectly once before.
    @Test func dayNumbersRunAcrossAMonthBoundary() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 30
        let start = calendar.startOfDay(for: calendar.date(from: components)!)

        let labels = TimelineCurve.dayLabels(for: TimelineRange(start: start, dayCount: 4), calendar: calendar)
        let numbers = labels.map(\.dayNumber)

        #expect(numbers.count == 4)
        #expect(numbers[0] != numbers[2])
        // The 30th and 31st of January, then the 1st and 2nd of February.
        #expect(calendar.component(.day, from: labels[0].day) == 30)
        #expect(calendar.component(.day, from: labels[3].day) == 2)
    }

    @Test func everyLabelCarriesAWeekdayAndADayNumber() {
        let calendar = Calendar.current
        let labels = TimelineCurve.dayLabels(
            for: TimelineRange(start: calendar.startOfDay(for: now), dayCount: 7),
            calendar: calendar
        )

        #expect(labels.allSatisfy { !$0.dayNumber.isEmpty && !$0.weekday.isEmpty })
    }
}

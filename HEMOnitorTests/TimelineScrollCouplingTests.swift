//
//  TimelineScrollCouplingTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

/// Covers `TimelineCurve.chartScrollOffset` — the mapping from the injection list's
/// vertical scroll position onto the chart's horizontal scroll offset.
///
/// **What this verifies:** the arithmetic. **What it does not verify:** that the
/// scroll handler driving it ever fires, or how the scrolling feels. Those need a
/// finger, and are the user's to check — see "Never write tests for physical
/// interaction" in CLAUDE.md. An earlier version of this coupling passed every test
/// here while doing nothing whatsoever on screen.
struct TimelineScrollCouplingTests {

    private let maxScroll: CGFloat = 1600

    private func offset(
        _ scrollOffset: CGFloat,
        content: CGFloat = 2000,
        viewport: CGFloat = 400
    ) -> CGFloat {
        TimelineCurve.chartScrollOffset(
            scrollOffset: scrollOffset,
            contentHeight: content,
            viewportHeight: viewport,
            maxChartScroll: maxScroll
        )
    }

    private func isClose(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 0.0001) -> Bool {
        abs(a - b) < tolerance
    }

    @Test func listAtTopShowsTodayAndAtBottomTheOldestDay() {
        // scrollable = 2000 - 400 = 1600
        #expect(isClose(offset(0), maxScroll))
        #expect(isClose(offset(1600), 0))
    }

    @Test func mappingIsContinuousNotSteppedByDay() {
        // The mock maps pixels, not whole days: a small scroll must move the chart a
        // small, non-zero amount. This is the assertion that catches a snapping design.
        #expect(isClose(offset(800), maxScroll / 2))
        #expect(isClose(offset(440) - offset(400), -maxScroll * CGFloat(40.0 / 1600.0)))
    }

    @Test func overscrollAndDegenerateInputsStayInRange() {
        // Rubber-banding produces offsets outside the content bounds.
        #expect(isClose(offset(-300), maxScroll))
        #expect(isClose(offset(9999), 0))
        // Content shorter than, and exactly equal to, the viewport: nothing to couple
        // to, so stay on today. The equal case is the boundary an earlier
        // `max(1, ...)` denominator got wrong.
        #expect(isClose(offset(0, content: 300, viewport: 400), maxScroll))
        #expect(isClose(offset(0, content: 400, viewport: 400), maxScroll))
    }

    @Test func chartThatFitsEntirelyNeverScrolls() {
        let fits = TimelineCurve.chartScrollOffset(
            scrollOffset: 800,
            contentHeight: 2000,
            viewportHeight: 400,
            maxChartScroll: 0
        )
        #expect(isClose(fits, 0))
    }
}

/// Covers the two pure functions behind the new chart behaviour: how far ahead the
/// chart projects, and which day column sits at the centre of the viewport.
///
/// As above: this verifies arithmetic only. Whether the marker visibly tracks a drag
/// is a physical check and belongs to the user.
struct TimelineProjectionAndMarkerTests {

    private func model(halfLife: Double = 19, baseline: Double = 2) -> FactorVIIIModel {
        FactorVIIIModel(weightKg: 65, baselinePercent: baseline, halfLifeHours: halfLife)
    }

    // MARK: - Future projection

    @Test func atBaselineThereIsNothingLeftToProject() {
        let days = TimelineCurve.projectedFutureDays(model: model(), currentRealPercent: 2)
        #expect(days == 0)
    }

    @Test func aHighLevelProjectsSeveralDaysAhead() {
        // 94% decaying at a 19h half-life takes a few days to reach baseline + 0.5.
        let days = TimelineCurve.projectedFutureDays(model: model(), currentRealPercent: 94)
        #expect(days > 0)
        #expect(days <= TimelineCurve.maximumFutureDays)
    }

    @Test func aHigherLevelNeverProjectsFewerDays() {
        let low = TimelineCurve.projectedFutureDays(model: model(), currentRealPercent: 20)
        let high = TimelineCurve.projectedFutureDays(model: model(), currentRealPercent: 120)
        #expect(high >= low)
    }

    @Test func projectionIsCappedSoTheChartCannotRunAway() {
        // A very long half-life would otherwise project for months.
        let days = TimelineCurve.projectedFutureDays(
            model: model(halfLife: 5000),
            currentRealPercent: 150
        )
        #expect(days == TimelineCurve.maximumFutureDays)
    }

    @Test func rangeGrowsByTheProjectedDays() {
        let plain = TimelineCurve.range(injections: [], futureDays: 0)
        let extended = TimelineCurve.range(injections: [], futureDays: 5)
        #expect(extended.dayCount == plain.dayCount + 5)
    }

    @Test func rangeClampsAbsurdFutureDays() {
        let extended = TimelineCurve.range(injections: [], futureDays: 9999)
        let plain = TimelineCurve.range(injections: [], futureDays: 0)
        #expect(extended.dayCount == plain.dayCount + TimelineCurve.maximumFutureDays)
    }

    // MARK: - Centred day marker

    @Test func atTheLeftEdgeTheMarkerIsNearTheFirstDay() {
        // Viewport 402pt ≈ 6.3 columns, so its centre sits in column 3.
        let index = TimelineCurve.centredDayIndex(scrollOffset: 0, viewportWidth: 402, dayCount: 30)
        #expect(index == 3)
    }

    @Test func scrollingRightMovesTheMarkerForward() {
        let a = TimelineCurve.centredDayIndex(scrollOffset: 0, viewportWidth: 402, dayCount: 30)
        let b = TimelineCurve.centredDayIndex(scrollOffset: 640, viewportWidth: 402, dayCount: 30)
        #expect(b > a)
        // 640pt = 10 columns, so the centre moves 10 columns along.
        #expect(b == a + 10)
    }

    @Test func markerIndexStaysWithinTheRange() {
        for offset in stride(from: CGFloat(-500), through: 5000, by: 100) {
            let index = TimelineCurve.centredDayIndex(
                scrollOffset: offset,
                viewportWidth: 402,
                dayCount: 30
            )
            #expect(index >= 0)
            #expect(index < 30)
        }
    }

    @Test func emptyRangeDoesNotCrash() {
        #expect(TimelineCurve.centredDayIndex(scrollOffset: 0, viewportWidth: 402, dayCount: 0) == 0)
    }
}

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

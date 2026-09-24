//
//  TimelineScrollCouplingTests.swift
//  HEMOnitorTests
//

import Testing
import Foundation
@testable import HEMOnitor

/// Covers `TimelineCurve.focusedDayIndex` — the mapping from the injection list's
/// scroll position to the day the chart scrolls to.
///
/// This exists because the gesture itself can't be exercised: the agent has no working
/// drag command, so the *coupling* would otherwise ship completely unverified. The
/// maths is testable even when the scrolling isn't.
struct TimelineScrollCouplingTests {

    private let dayCount = 30

    private func index(offset: CGFloat, content: CGFloat = 2000, viewport: CGFloat = 400) -> Int {
        TimelineCurve.focusedDayIndex(
            scrollOffset: offset,
            contentHeight: content,
            viewportHeight: viewport,
            dayCount: dayCount
        )
    }

    @Test func listAtTopFocusesToday() {
        // Today is the last column.
        #expect(index(offset: 0) == dayCount - 1)
    }

    @Test func listAtBottomFocusesTheOldestDay() {
        // scrollable = 2000 - 400 = 1600
        #expect(index(offset: 1600) == 0)
    }

    @Test func halfwayFocusesTheMiddleOfTheRange() {
        let middle = index(offset: 800)
        // 29 * 0.5 = 14.5, rounded to 15 (indices are 0...29).
        #expect(middle == 15)
    }

    @Test func mappingIsMonotonicallyBackwardsInTime() {
        let offsets: [CGFloat] = [0, 200, 400, 800, 1200, 1600]
        let indices = offsets.map { index(offset: $0) }
        for (earlier, later) in zip(indices, indices.dropFirst()) {
            #expect(later <= earlier)
        }
    }

    @Test func overscrollIsClamped() {
        // Rubber-banding produces offsets outside the content bounds.
        #expect(index(offset: -300) == dayCount - 1)
        #expect(index(offset: 9999) == 0)
    }

    @Test func unscrollableListStaysOnToday() {
        // Content shorter than the viewport: nothing to couple to.
        #expect(index(offset: 0, content: 300, viewport: 400) == dayCount - 1)
        // And exactly-fitting content, which is the boundary case that a naive
        // `max(1, ...)` denominator got wrong.
        #expect(index(offset: 0, content: 400, viewport: 400) == dayCount - 1)
    }

    @Test func singleDayRangeIsAlwaysIndexZero() {
        let only = TimelineCurve.focusedDayIndex(
            scrollOffset: 500,
            contentHeight: 2000,
            viewportHeight: 400,
            dayCount: 1
        )
        #expect(only == 0)
    }

    @Test func resultIsAlwaysAValidIndex() {
        for offset in stride(from: CGFloat(-500), through: 2500, by: 100) {
            let i = index(offset: offset)
            #expect(i >= 0)
            #expect(i < dayCount)
        }
    }
}

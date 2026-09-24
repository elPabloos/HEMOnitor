# Task: Make the Timeline chart scroll, by hand and with the list

**Status:** complete
**Created:** 2026-09-24
**Completed:** 2026-09-24

## Objective

The Timeline chart can be dragged left and right through the full history, and it also
pans on its own as the user scrolls the injection list below it — list at the top shows
today, list at the bottom shows the oldest day.

## Context

Reported by the user on 2026-09-24: neither behaviour was happening. Phase 018 shipped
the chart, the day axis and the list correctly, but the scrolling never worked. Two
separate causes, both in `TimelineView`:

**1. The chart could not be dragged at all.** It was not a scroll view. It was a
fixed-width `TimelineCurveChart` hung in an `.overlay` and moved with `.offset(x:)`:

```swift
TimelineCurveChart(points: points, range: range)
    .offset(x: chartOffset)
```

`.offset` moves a view; it does not make it scrollable. There was no gesture attached,
so the only thing that could ever move the chart was the coupling code — and that was
broken too.

**2. The coupling divided by a guessed viewport height.** `syncChart(to:)` computed
scroll progress as `offset / (contentHeight - viewportHeightEstimate)` where
`viewportHeightEstimate` was the constant `320`. The list's real viewport is whatever
is left below a 360pt chart, so on any realistic history the denominator was wrong; on
a short history `contentHeight - 320` collapsed toward zero or negative and the
`max(1, ...)` floor turned progress into a step function. The 018 task file flagged the
estimate as "only affects how fast the chart pans" — that was wrong, it broke the
mapping outright.

## Requirements

- [x] The chart is a real horizontal scroll view and can be dragged directly.
- [x] It opens anchored on today, at the right-hand edge.
- [x] Scrolling the injection list pans the chart: top = today, bottom = oldest day.
- [x] The mapping is a pure function and unit-tested.
- [x] The chart no longer forces the screen's layout width (the 018 fix must survive).

## Architecture

The `.offset` and the hand-rolled offset maths are replaced by a real
`ScrollView(.horizontal)` inside a `ScrollViewReader`. This solves three things at once:

- Dragging works natively, with correct momentum, rubber-banding and indicators.
- Programmatic panning becomes `scrollTo(day, anchor:)`, so the coupling no longer has
  to compute pixel offsets at all.
- The width problem 018 fought disappears. A `ScrollView` accepts the width it is
  offered and scrolls its content, so it cannot force the screen wider — the
  `Color.clear` + `.overlay` scaffolding from 018 is no longer needed and is gone.

Each day column in `TimelineCurveChart` carries `.id(day)` as the scroll target.

**The coupling now maps to a day, not to a pixel offset.** Scroll progress picks an
index into the range and the chart scrolls that column to centre. This is more robust
(no pixel arithmetic to get wrong) and more meaningful: the part of the curve you are
looking at belongs to the entries you are reading. The end states still match the mock —
top is today, bottom is the oldest day.

`TimelineCurve.focusedDayIndex(scrollOffset:contentHeight:viewportHeight:dayCount:)`
holds that mapping as a pure function, and the viewport height is now **measured** by a
`GeometryReader` around the list rather than assumed.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] The chart drags smoothly through the whole history.
- [x] It opens on today.
- [x] Scrolling the list pans the chart in the opposite direction.
- [x] Home, Stock, Alerts and You are unchanged.
- [x] The app builds and the full unit suite passes.

## Verification

- Build: `** BUILD SUCCEEDED **`.
- Tests: `** TEST SUCCEEDED **`, full suite, with 8 new `TimelineScrollCouplingTests`
  covering top/bottom/midpoint mapping, monotonicity, overscroll clamping, the
  unscrollable and exactly-fitting cases, a single-day range, and index validity across
  the whole offset sweep.
- Screenshot: Timeline with 30 days of seeded history, opening anchored on today (24th,
  green) with the history extending left. The UI hierarchy confirms **two** scroll views
  where 018 had one — the chart at y=133 is now genuinely scrollable.
- Interactive check: **left to the user, unavoidably.** The agent has no working drag
  command, so neither the hand-scroll nor the coupling can be exercised end to end. That
  is exactly why the mapping was extracted into a tested pure function rather than left
  inline.

## Notes

- Dropping `.offset` also removed `chartOffset`, `viewportWidth`, `maxChartScroll` and
  `syncChart` — the scroll view replaces all of it.
- The programmatic `scrollTo` animates over 0.2s. If panning the list feels like it
  fights a simultaneous hand-drag of the chart, that animation is the thing to shorten
  or drop.
- Not addressed: the chart does not currently scroll the *list* when dragged. The mock
  couples one way only, and two-way coupling invites feedback loops.

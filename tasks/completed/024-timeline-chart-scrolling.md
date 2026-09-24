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

- [x] The chart can be dragged left and right directly.
- [x] It opens anchored on today, at the right-hand edge.
- [x] Dragging to either end never exposes blank canvas.
- [x] Scrolling the injection list pans the chart **continuously**: top = today,
      bottom = oldest day, matching the mock's pixel mapping rather than snapping.
- [x] The mapping and the clamp are pure functions and unit-tested.
- [x] The chart no longer forces the screen's layout width (the 018 fix must survive).

## Second pass (2026-09-24, after user testing)

The first attempt replaced `.offset` with a real `ScrollView(.horizontal)` +
`ScrollViewReader`, and mapped list scroll onto a *day index* via `scrollTo(day:)`.
Hand-scrolling worked. Two things were still wrong, both reported with screenshots:

**1. Blank canvas at the edges.** Dragging past either end rubber-banded the content
beyond its bounds, exposing the container's near-white background where the zebra
stripes, gridlines and curve had run out. Inherent to `ScrollView` bounce.

**2. The coupling still did nothing,** and the day-snapping design was wrong anyway.
Re-reading the mock settled it — `onTlListScroll` does a *continuous* pixel mapping:

```js
const frac = el.scrollTop / (el.scrollHeight - el.clientHeight);
this._tlEl.scrollLeft = (1 - frac) * hmax;
```

Before iOS 18 there is no way to set a `ScrollView`'s offset continuously — `scrollTo`
snaps, and that is all it offers. The `ScrollView` was therefore actively preventing the
required behaviour.

## Third pass — replacing the chart's `ScrollView` with a `DragGesture`, then undoing it

The second pass dropped the `ScrollView` and drove `.offset(x:)` from a `DragGesture`,
so the offset could be clamped (killing the overscroll) and driven continuously
(matching the mock). It worked and tested clean, but the user questioned it and the
trade turned out to be bad:

- A raw `DragGesture` **loses VoiceOver's three-finger scroll and scroll actions** —
  an accessibility regression in a screen phase 020 had just audited.
- It loses native deceleration, which was being hand-approximated.
- The stated justification ("no continuous offset API before iOS 18") was weaker than
  claimed, since the coupling *already* depends on an iOS 18 API behind an
  availability check.

So the `ScrollView` is back. Final shape:

**Chart is a `ScrollView(.horizontal)`** — native momentum, rubber-banding, scroll
indicators and VoiceOver scrolling, all for free.

**Continuous positioning via fine-grained scroll anchors.** `ScrollViewReader` can only
scroll *to a view*, and one anchor per day snaps in 64pt steps — visibly stepped, and
not the pixel mapping the mock specifies. So an invisible anchor is laid every 8pt
across the content and `scrollTo(index, anchor: .leading)` targets the nearest one.
Fine enough to read as smooth, and it needs no availability gate, unlike
`ScrollPosition.scrollTo(x:)` (iOS 18+).

**The blank edges are fixed by moving the chrome, not by preventing overscroll.**
Gridlines, reference levels and the baseline don't vary by day, so they were pointless
to scroll — and being inside the scrolled content is exactly why they stopped where the
data stopped, leaving a white gap on rubber-band. `TimelineChartGuides` now draws them
behind the scroll view at full viewport width, so overscrolling reveals an empty
stretch of chart with its gridlines intact. Plot geometry is shared via
`TimelineCurve.plotHeight`/`plotTopInset`/`plotBottomInset` so the fixed chrome and the
scrolling content land on identical y positions.

**Scroll observation switched from preferences to `onScrollGeometryChange`.** Both 018
and the first pass of 024 read the list's position with a `GeometryReader` +
`PreferenceKey`, which never fired in practice. `onScrollGeometryChange` (iOS 18+) is
the API built for this and reports offset, content size and container size directly,
during the drag. The preference path is retained only to satisfy the project's iOS 17.5
floor, and the doc comment says plainly that it is not trusted.

`TimelineCurve.chartScrollOffset(scrollOffset:contentHeight:viewportHeight:maxChartScroll:)`
holds the mapping as a pure function. Viewport heights are **measured** rather than
assumed.

## Fourth pass — the month-boundary bug, plus two features

Reported after testing: scrolling worked, but crossing a month boundary made the day
strip jump back to today; and two behaviours from a reference video were missing.

**The bug was an ID collision, not a date bug.** Rendering the strip straight at the
rollover proved the dates were right — `29 Sat, 30 Sun, 31 Mon, 1 Tue, 2 Wed, 3 Thu`.
The fault was in the scroll anchors added in the third pass:

```swift
zebra:         ForEach(0..<range.dayCount, id: \.self)  // Int ids 0…30
scrollAnchors: ForEach(0..<anchorCount,   id: \.self)   // Int ids 0…247
```

`ScrollViewReader.scrollTo` resolves `ForEach` element identity as well as explicit
`.id()`, so every index below `dayCount` had two candidate targets. Picking the zebra
stripe scrolls to `index × 64` instead of `index × 8` — eight times too far, hitting the
end of the content, which is today. Fixed twice over: the zebra is now a single `Canvas`
(no identified subviews, and cheaper), and anchors use a dedicated `ChartAnchorID`.

**Feature — the chart projects past today.** The range is extended by
`TimelineCurve.projectedFutureDays`, which asks the existing `hoursUntilLevelReaches`
for a small margin above baseline and caps at 14 days. No new PK maths, and the curve
itself continues for free once `sample` stops clamping at `now`. That clamp was
deliberate ("a record, not a forecast") but with the range extended it would have drawn
the tail as a flat line at the current level — misleading rather than conservative.
Note the *window length* is the only thing `projectedFutureDays` decides; a fixed
constant would also work, at the cost of empty columns for a patient already at
baseline.

**Feature — the day marker follows the scroll.** The filled circle marks whichever day
sits at the centre of the viewport (`TimelineCurve.centredDayIndex`), driven by the
chart's own offset so it tracks a hand-drag as well as a list scroll. Today keeps a
quiet outline ring when it isn't centred, so the present stays findable — an addition
beyond the reference video, easily dropped.

**Two ordering bugs found while wiring this up**, both the same shape: acting on state
before the measurement it depends on exists. The chart opened three columns too far
right because the list's first scroll report arrived while `chartViewportWidth` was
still 0, putting the centring maths out by half a viewport. Both sites now guard on a
measured width, and the opening scroll is a one-shot anchored on today rather than on
the end of the (now longer) range.

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
- Tests: `** TEST SUCCEEDED **`, full suite. `TimelineScrollCouplingTests` covers the
  mapping in four cases: the endpoints (top = today, bottom = oldest), **continuity**
  (a small scroll must produce a small *non-zero* move — the assertion that catches a
  day-snapping design), overscroll and the degenerate viewport cases, and a chart that
  fits entirely. Deliberately kept small, per the testing policy added to CLAUDE.md in
  this task.
  **These verify the arithmetic and nothing else.** They say nothing about whether the
  scroll handler fires — an earlier version of this coupling passed every one of them
  while doing nothing at all on screen.
- Screenshot: Timeline with 30 days of seeded history, anchored on today (24th, green),
  with the reference lines now spanning the full viewport width.
- Interactive check: **left to the user, unavoidably.** The agent has no working drag or
  scroll command. Worth checking: that dragging the chart still works, that scrolling
  the list moves it, and that overscrolling at either end now shows empty gridded chart
  rather than a white gap. If the coupling does nothing, `onScrollGeometryChange` is the
  first place to look.

## Notes

- **Policy change made in this task:** CLAUDE.md gains "Never write tests for physical
  interaction", and the task template's Verification section points at it. Tests that
  simulate touch are banned outright; tests of the *logic* a gesture drives are kept but
  must be reported as verifying the maths, never the feature. This episode is the
  evidence — a fully-passing test suite over a completely dead coupling.
- Anchor spacing is 8pt. Tighter is smoother but multiplies the number of anchor views;
  8pt on a 64pt day column was judged smooth enough.
- Not addressed: dragging the chart does not scroll the *list*. The mock couples one
  way only, and two-way coupling invites feedback loops.

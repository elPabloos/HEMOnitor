# Task: Build the Timeline screen

**Status:** complete
**Created:** 2026-09-23
**Completed:** 2026-09-23

## Objective

The user can open a full-screen Timeline from the You tab and see their Factor VIII
level plotted across several days, with every logged injection listed underneath,
grouped by day — and can correct a past entry (change its dose or date/time) or delete
it, with the curve and every downstream level updating to match.

## Context

Phase 018 of the redesign plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`).
It is the last feature phase; only the accessibility/iPad pass (020) follows.

The entry point is already wired but stubbed: `YouView`'s Timeline row calls
`onOpenTimeline`, which `AppShellView` maps to `presentedSheet = .timeline`, currently
rendering `ComingSoonView` (`HEMOnitor/Views/Shell/AppShellView.swift:92-95`).

Three things established by exploration that shape the work:

1. **The existing curve sampler cannot be reused as-is.**
   `DecayCurve.sample(model:currentRealPercent:totalHours:pointCount:)`
   (`Views/Home/Cards/DecayCurve.swift:28`) projects *forward from now* off a single
   current level. Timeline needs *history*, which means walking the `injections` chain
   and sampling each segment from its own `peakRealPercent`. That is a new pure
   function, not a change to `DecayCurve` — Home's use of it must keep working.

2. **`recalculateLevels(at:)` is not a query.** It mutates the two published
   current-level properties (`FactorTrackerViewModel.swift:131`), so it must not be
   called per sample point. Sampling reconstructs levels with
   `model.levelAtTime(peakPercent:hoursSincePeak:)` directly, exactly as `DecayCurve`
   already does.

3. **`recomputeChain(fromIndex:)` is private** (`FactorTrackerViewModel.swift:164`).
   Editing goes through the existing public `updateInjection(id:doseIU:date:)` and
   `deleteInjection(id:)` (`:223`, `:247`), which already splice, recompute the chain
   and persist. Phase 011 built and tested this; 018 adds no view-model API.

Relevant CLAUDE.md sections: "The real vs. display level distinction", "Injection
history and current level", and "Who verifies what".

## Mock specification

Taken from the Claude Design project "Mobile app design project", file
`HEMOnitor App.dc.html` — the `══ TIMELINE (full screen) ══` block and its
`timelineVals()` method. Reachable via the `claude-design` MCP tools; project id
`05f89777-4f32-4616-8ea0-646bd9b4700b`. Exact values below rather than
approximations, because the mock is the source of truth for this screen.

**Presentation.** Full-screen overlay (not a sheet), own gradient background, fading
in. Header: centred "Timeline" title, 34pt circular ✕ close button on the trailing
edge, balancing spacer leading. A 1.5pt dark rule separates header from content.

**Time range.** From midnight of the *oldest* injection through today, floored at 7
days (`today - 6 days`) so a near-empty history still renders a sensible chart. Day
columns are a fixed **64pt wide**, so the chart is **horizontally scrollable** and
grows with history rather than compressing. It opens scrolled fully right (today).

**Chart geometry.** Plot area 266pt tall, `top = 14`, `bottom = 252`. The y scale
spans **0–160 %**, not 0–100 — post-dose peaks overshoot 100 and must fit:
`y(pct) = bottom - clamp(pct, 0, 160) / 160 * (bottom - top)`. Sampled at **240
points** across the whole width.

**Layers, back to front:** zebra day stripes (alternating `ink @ 0.035` / clear);
faint minor gridlines at 60/80/120/140 %; dashed reference lines at 100 % (ink @ 0.3),
40 % (green @ 0.55) and 15 % (red @ 0.55), dash pattern 5-5; the curve as a **filled
shape with no stroke** (green at 0.5 opacity, closed down to the baseline); a solid
baseline rule; per-day tick marks descending 5pt below it.

**Labels.** "FVIII activity (% of normal)" top-left, uppercase. Left-edge mono labels
"100%", "40%" (green) and "15%" (red), each sitting on its own reference line. Below
the plot, a day axis: per 64pt column a 34pt circle holding the day number — filled
green with white text for today — and the abbreviated weekday beneath.

**List.** Grouped by calendar day, newest first, header = full date ("23 September
2026"). Rows are tinted cards (green gradient, green hairline border, 16pt radius)
showing product name, dose in IU, "September 23 · 14:05", and the lot number.

**Scroll coupling.** Scrolling the list vertically pans the chart horizontally in the
opposite direction: list at top = chart at today, list at bottom = chart at oldest.

## Requirements

- [x] A new `TimelineView` replaces `ComingSoonView` as the `.timeline` destination,
      presented **full-screen**.
- [x] Curve, day axis, gridlines, zebra striping and labels per the mock spec above.
- [x] Curve values are plotted in **display** space (`displayLevel(fromRealPercent:)`
      applied at the last step); all decay math stays in real space.
- [x] Horizontal scrolling at 64pt/day, opening at today, coupled to list scrolling.
- [x] Day-grouped injection list, newest day first, rows per the mock.
- [x] **Tap a row to edit** it — dose and date/time — with an iOS disclosure chevron on
      the row so the affordance is visible. No swipe actions.
- [x] Delete from within the edit sheet, behind a confirmation.
- [x] Re-dating an entry earlier than its neighbours reorders it correctly (the chain
      already supports this; the UI must not prevent it).
- [x] The curve-sampling and layout maths are pure functions and unit-tested.
- [x] Empty state when there are no injections yet (the mock does not specify one).

## Architecture

Two local changes, both recorded here per the template.

**`InjectionEvent` gains `lot` and `productName`, both optional.** The mock's rows
show which product and which vial lot a dose came from. `LogDoseSheet` already knows
the batch when logging from stock and currently discards it. Both are `String?` so
the synthesised `Codable` decoder uses `decodeIfPresent` and existing saved state
still loads — the decode-time-default rule the redesign plan sets for every new
persisted field. `nil` product falls back to the product in `AppSettings`; `nil` lot
(manual doses) simply omits the line. Improves: the screen's usefulness — a timeline
without lot traceability is materially weaker for the user's actual purpose. Cost:
three `InjectionEvent` construction sites in `FactorTrackerViewModel` must carry the
fields through `recomputeChain` rather than dropping them, since the chain rebuild
reconstructs each value.

**A new pure sampler**, `TimelineCurve`, alongside the existing `DecayCurve` rather
than generalising `DecayCurve` to handle both the forward-only Home case and the
historical multi-day case. Reason: `DecayCurve`'s signature takes a single
`currentRealPercent` with no notion of a chain; widening it to accept `[InjectionEvent]`
plus a time window would leave Home passing empty/ignored arguments and would put two
unrelated sampling strategies behind one function. Two focused pure functions are more
testable and each stays readable. Cost: a small amount of duplicated "sample a decay
segment" arithmetic between the two — acceptable, and both delegate the actual formula
to `FactorVIIIModel.levelAtTime`, so the PK math still exists in exactly one place.

Everything else follows existing patterns: hand-rolled `Path`/`GeometryReader` drawing
as in `DecayCurveChart` (no Swift Charts — the repo has none), row styling after
`RecentActivityCard`, design tokens from `DesignSystem/`.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not change `DecayCurve`/`DecayCurveChart` or Home's behavior.
- Do not add view-model API; use the phase 011 methods as they stand.
- Do not introduce Swift Charts or any other dependency.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] Opening Timeline from the You tab shows the curve and the grouped list.
- [x] With no injections, an empty state appears instead of a broken/blank chart.
- [x] Deleting an entry removes it and the curve redraws without it.
- [x] Editing an entry's date to before the preceding injection reorders it correctly
      and the levels after it change accordingly.
- [x] Edits survive relaunch.
- [x] Home, Stock, Alerts and You are visually and behaviourally unchanged.
- [x] The app builds and the full unit suite passes.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
# Note: the iPhone 17 Pro named in CLAUDE.md no longer exists on this machine;
# the available runtime is iOS 27.0 (iPhone 18 Pro).
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,id=<udid>' test
```

- Build: **`** BUILD SUCCEEDED **`**. The only warnings are pre-existing `Combine`
  import warnings in `HomeView.swift:41`, untouched by this task.
- Tests: **`** TEST SUCCEEDED **`**, full suite. 17 new tests in
  `HEMOnitorTests/TimelineCurveTests.swift` covering the range floor, multi-day span,
  midnight alignment, sample count//span, baseline-before-first-dose, peak-at-injection,
  half-life decay, later-injection-takes-over, clamping at now, calibration scaling,
  and the four vertical-scale cases.
- Screenshot: taken of the Timeline (with 10 seeded injections over 22 days), the edit
  sheet, and the empty state. **Two real bugs were caught this way and fixed:**
  1. The 1408pt-wide chart was setting the layout width for the whole screen, so the
     ✕ button, the scale labels and every list row's text were pushed off-screen to
     the left. Fixed by hanging the chart in an `overlay` on a flexible spacer, which
     cannot influence its container's width.
  2. `Double.formatted` applied the locale's grouping separator, rendering a 3000 IU
     dose as "3.000 IU" — i.e. three. Now uses `.grouping(.never)`, matching
     `RecentActivityCard`.
  A third, smaller fix: the delete button rendered grey because
  `SecondaryPillButtonStyle` sets its own foreground colour inside `makeBody`,
  overriding the outer modifier. Styled inline instead, matching `YouView`'s reset.
- Interactive check: **left to the user** — per "Who verifies what" in CLAUDE.md.
  Worth tapping through specifically: **the scroll coupling** (does panning the list
  move the chart at a rate that feels right?), editing a dose and re-dating one
  *earlier than its neighbours*, the delete confirmation, and relaunching to confirm an
  edit persisted. The screenshots prove these screens render; they do **not** prove the
  edit actually writes through.

## Notes

- **Scroll-coupling caveat.** The list viewport height is approximated as a constant
  (`viewportHeightEstimate`) rather than measured, because the list's height is just
  "whatever is left below the chart" and measuring it would mean another
  `GeometryReader` feeding a second piece of state. The approximation only affects how
  *fast* the chart pans, never where it starts or ends, so a wrong guess degrades feel
  rather than correctness. If it feels off in use, measure it properly.
- **Deliberately not done:** editing which lot/product a dose came from. Changing that
  would have to reconcile stock quantities to mean anything, which is a different task.
  The edit sheet shows them read-only.
- The old pre-redesign templates `tasks/templates/002-swift-charts-visualization.md`
  and `004-timeline-injection-history.md` both cover this screen and are now
  superseded: 002 proposed Swift Charts (rejected — the app has no charting framework
  and the mock's exact treatment is easier hand-rolled), and 004 predates the redesign,
  referencing types that no longer exist.

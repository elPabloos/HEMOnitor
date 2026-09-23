# Bug: the Home "look ahead" slider doesn't move the level

**Status:** complete
**Created:** 2026-09-23
**Completed:** 2026-09-23

## Objective

Dragging the "Look ahead" slider on the Home screen projects the whole screen forward
in time — the big level, its zone, and the curve — instead of changing one line of
text inside the cover-window card.

## Context

Reported by the user on 2026-09-23, testing a build on their own iPhone: moving the
slider did not update the big factor level above it. Confirmed, and **not** a
regression from phase 018 (which touched nothing on Home) — the wiring has never
existed. It dates from phase 014, when Home was rebuilt.

What the code actually did: `HomeView` held `lookAheadHours` as `@State` and passed it
to `CoverWindowCard` and nowhere else. `LevelVisualization` was handed
`viewModel.currentDisplayLevelPercent`, which only ever changes via
`recalculateLevels()` on appear and on the 60-second timer. So no code path existed by
which the slider could move the headline number. The card computed its own private
`previewDisplayPercent` and rendered it as a caption — the only visible effect.

The design mock is unambiguous that this is wrong. From `HEMOnitor App.dc.html`
(Claude Design project `05f89777-4f32-4616-8ea0-646bd9b4700b`), `renderVals()`:

```js
const at = s.now + s.simOffset * H;   // simOffset is the look-ahead slider
const real = this.currentReal(at);
const display = this.disp(real);
const z = this.zone(display);
```

`display` feeds `levelInt` (the big number) and `ringOffset` (the ring fill), `z` feeds
the zone colour and badge, and the curve's sample loop is also built from `at`. The
entire Home screen renders "as of" the previewed instant.

## Requirements

- [x] The slider projects the level shown by `LevelVisualization` (all three styles).
- [x] The zone badge and colour follow the projected level.
- [x] The decay curve starts from the projected level.
- [x] The cover-window headline counts its crossing from the previewed instant.
- [x] At 0 hours the screen is identical to before — "now" is unchanged.
- [x] The projection is a pure, unit-tested function.
- [x] A "+12h"-style badge and a "Previewing <date>" line show when the slider is off
      zero, per the mock.

## Architecture

No structural change. The projection is one new pure function,
`DecayCurve.projectedRealPercent(model:currentRealPercent:hoursAhead:)`, sitting beside
the existing `DecayCurve.sample` — same file, same memoryless-decay justification, and
it delegates to `FactorVIIIModel.levelAtTime` so no PK math is duplicated.

Ownership moved deliberately: `HomeView` now projects **once** and passes the result
down to the visualization, the zone, the curve and the card alike. `CoverWindowCard`
previously projected privately; it now receives an already-projected level plus the
`asOf` instant it describes, and must not project again. That keeps a single source of
truth for "what time is this screen showing".

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] With the slider at 0, Home is unchanged.
- [x] Moving it forward lowers the displayed level along the decay curve.
- [x] The projection stays in real space; calibration is applied only at display.
- [x] The app builds and the full unit suite passes.

## Verification

- Build: `** BUILD SUCCEEDED **`.
- Tests: `** TEST SUCCEEDED **`. 8 new tests in
  `HEMOnitorTests/LookAheadProjectionTests.swift`: zero-hours identity, one-half-life
  decay, monotonic decrease, baseline floor, negative-input guard, calibration not
  leaking into real space, display conversion scaling, and agreement with the curve
  sampler at the same hour.
- Screenshot: n/a for the *gesture*. See below.
- Interactive check: **left to the user, and unavoidably so.** The agent cannot drag a
  slider at all — `t <x> <y>` taps, but every spelling of a drag command
  (`d`/`s`/`sw`/`swipe`/`p`/`dr`) is rejected, and a tap does not move a SwiftUI
  `Slider`. This is now recorded in CLAUDE.md so the next session doesn't rediscover
  it. The projection logic is therefore verified by unit test rather than by gesture;
  **please confirm on device that dragging moves the big number.**

## Notes

- The diagnosis came from reading the code, not from reproducing the gesture — the
  absence of any binding between `lookAheadHours` and `LevelVisualization` is proof
  enough, and the mock settled what the correct behaviour is.
- The card's old caption showed the previewed *percentage*; it now shows the previewed
  *date* only, because the percentage is displayed above it in the ring/numeral and
  repeating it there would be redundant.
- Not addressed: the slider has no haptic detents and no "reset to now" affordance
  beyond dragging back to 0. The mock has neither either.

# Bug: the big level number lags behind the look-ahead slider

**Status:** complete
**Created:** 2026-09-24
**Completed:** 2026-09-24

## Objective

Dragging the "Look ahead" slider moves the big level number in lockstep with the
finger, with no trailing or catch-up.

## Context

Reported by the user on 2026-09-24 after confirming the slider itself works (see
`022-look-ahead-slider-inert.md`). The projection was correct; the *motion* was wrong —
the number visibly lagged the drag.

One line caused it, `HEMOnitor/Views/Home/Cards/LevelVisualization.swift:35`:

```swift
.animation(.easeInOut(duration: 0.35), value: displayPercent)
```

The slider is `in: 0...72, step: 1`, so a single drag emits up to 72 discrete changes.
Each one starts a fresh 0.35-second ease-in-out that the next change interrupts
mid-flight, so the displayed value is permanently chasing a number the finger has
already passed. The animation is wanted for the *other* reasons the level changes —
the 60-second refresh, a newly logged dose, a calibration — where it reads as a smooth
update rather than lag.

## Requirements

- [x] While the slider is being dragged, the level tracks it with no transition.
- [x] When the level changes for any other reason, the existing 0.35s ease-in-out is
      preserved.
- [x] The ring fill, the numeral and the zone colour all behave consistently — they
      share the one animation modifier, so none of them can drift out of step.

## Architecture

No structural change. `LevelVisualization` gains an `isScrubbing` flag (defaulting to
`false`, so every other call site is unaffected) which selects between the eased
animation and `nil`. `CoverWindowCard` surfaces the slider's existing
`onEditingChanged` as an `onScrubbingChanged` callback, and `HomeView` holds the flag —
the same ownership pattern as the look-ahead offset itself, which Home already owns and
pushes down.

Rejected: simply shortening the duration. That reduces the lag without removing it, and
leaves the same interrupt-per-step behaviour. Dropping the animation for the duration of
the drag is what makes scrubbing feel direct.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] Scrubbing the slider moves the number without visible delay.
- [x] Releasing the slider leaves the number where the finger left it.
- [x] The app builds and the full unit suite passes.

## Verification

- Build: `** BUILD SUCCEEDED **`.
- Tests: `** TEST SUCCEEDED **`, full suite (no new tests — this is a presentation-only
  change with no logic to assert; the projection it displays is already covered by
  `LookAheadProjectionTests`).
- Interactive check: **left to the user, and it is the whole point of this fix.** The
  agent cannot drag a slider (see CLAUDE.md), so the feel of the change is unverified.

## Notes

- Deliberately not added: `.contentTransition(.numericText())` on the big numeral. It
  looks good for a value that ticks occasionally, but during a scrub it would
  reintroduce exactly the per-change transition this fix removes.

# Task: Bottom-sheet system — log a dose and add stock

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

Dose logging works again through the design's floating "+" button: a sheet that draws vials from stock or takes a typed dose, at a date and time the user chooses (including in the past), previewing the effect before committing. Deliveries can be added to stock the same way.

## Context

Phase 015 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`).

This phase closes a real functional gap: phase 014 replaced Home's dose-entry text field with the design's "+" button, but that button opened a placeholder — so between 014 and this task there was **no way to log a dose at all**. That is why this was the agreed gate before merging anything to `main`.

It also puts phase 011's back-dating work to use for the first time: the sheet's date picker is what lets a user record a dose they forgot to log.

The calibration sheet restyle listed in the plan for this phase was already done during 014, so it isn't repeated here.

## Requirements

- [x] `SheetChrome` — shared grab handle, centred title, close button, gradient background, so all sheets read as one family.
- [x] `LogDoseSheet` — source toggle (from stock / manual), per-lot vial steppers, date/time picker capped at the present, live summary, commit.
- [x] `AddStockSheet` — vial-size chips, quantity stepper, lot number, expiry date, live total, commit.
- [x] `DoseLogPlan` — pure, SwiftUI-free computation of total dose, predicted peak, time above threshold and stock-after.
- [x] Wire both sheets into `AppShellView`, replacing the placeholders.
- [x] Stock is decremented on commit, and a dose that stock can't cover is refused rather than silently clamped.

## Architecture

**Native `DatePicker(.wheel)` instead of a hand-rolled three-column picker.** The mock implements its own scroll-snap date/hour/minute columns because it is HTML and has no alternative. SwiftUI's wheel-style `DatePicker` is the same interaction, already localized, already accessible, and already correct about month lengths and time zones. Reimplementing it would be strictly worse on maintainability, testability and accessibility for an identical result. Recorded here rather than applied silently, per the Architecture rules.

**One log sheet with a source toggle, rather than the mock's two separate sheets.** Everything except how the dose is *sourced* is shared — the date picker, the summary, the validation, the save path. Two sheets would duplicate all of it to vary one section. This is a small, local simplification, applied and recorded.

**Arithmetic extracted into `DoseLogPlan`.** The preview maths (totalling vials, predicting the peak, converting the display-space threshold back to real space) is a pure value type with no SwiftUI import, so it is unit-testable without standing up a view. This is the piece most likely to be wrong and least likely to be caught by eye.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not drift away from MVVM as a side effect.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] The app builds; all tests pass.
- [x] The "+" button opens a working log sheet; committing records the injection.
- [x] Committing from stock decrements the right lot.
- [x] The predicted level stacks on the level *at the chosen time*, not the level now (otherwise a back-dated dose would preview wrongly).
- [x] A dose exceeding available vials is refused, with nothing recorded.
- [x] The threshold duration is computed in real space even though it is quoted in display space.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **` — 79 cases, 0 failures; 9 new `DoseLogPlanTests`)
- Manual check: **driven end-to-end with real taps** (see the new "Driving the UI in the simulator" section in CLAUDE.md — this is newly possible and contradicts task 003's note). Seeded one injection (1300 IU, 20 h ago) and two lots (1500 IU × 4, 1000 IU × 2), then: Home showed 21 %; tapped "+"; selected 2 × 1500 IU; summary read Total 3000 IU / Predicted 114 % / Above 5 % for 4.1 days / Stock after 5000 IU; tapped "Log dose"; Home jumped to 114 % with the zone badge moving to "High"; the Stock tab showed lot A24K18 down from 4 vials to 2 and the hero total down from 8000 IU to 5000 IU. No clipping, overlap or contrast problems.

Every figure was checked against the model by hand rather than accepted: `2 + 40 × 0.5^(20/19)` = 21.3 %, and `21.3 + 3000/65 × 2.0` = 113.6 %, both matching the display.

## Notes

**Back-dated doses stack on the level at their own timestamp.** `plan` computes `currentRealPercent` via a local `realLevelAt(date)` that walks back to the last injection at or before the chosen moment, rather than using `viewModel.currentRealLevelPercent` (which tracks *now*). Without this, back-dating a dose would preview a peak built on today's level — wrong, and wrong in a way that looks plausible. This reuses the same "last injection at or before" rule that `recalculateLevels(at:)` adopted in phase 011.

**Stock is taken before the injection is written.** `consume` rejects rather than clamps (phase 013's decision), so the save path drains vials first and aborts without recording anything if a lot can't cover the selection. The alternative order would risk an injection existing with no stock behind it.

**`totalIU` ignores selections for unknown batches** rather than treating them as zero-size vials, so a selection left stale by a concurrent edit under-counts nothing silently — it simply drops. Covered by a test.

Files added: `Views/Sheets/{SheetChrome,DoseLogPlan,LogDoseSheet,AddStockSheet}.swift`, `HEMOnitorTests/DoseLogPlanTests.swift`. Modified: `Views/Shell/AppShellView.swift` (sheet wiring), `CLAUDE.md` (UI-driving and build-setting notes).

Out of scope, still placeholders: the Timeline sheet (phase 018) and the Alerts tab (phase 016).

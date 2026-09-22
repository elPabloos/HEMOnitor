# Task: Level-crossing alerts and notifications

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

The app warns the user before their estimated level drops below a threshold they choose, and can nudge them again if nothing is logged afterwards — delivered by iOS even when the app is closed.

## Context

Phase 016 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`). The last screen phase; only Timeline (018) and the QA pass (020) remain.

This is the feature the user asked for when they described wanting the app to "keep calculating in the background and notify me". Worth recording the reasoning, because the obvious approach is the wrong one: **iOS suspends apps, so continuous background computation isn't possible — and isn't needed.** The decay is a closed-form function of elapsed time, so the crossing moment can be computed *once*, up front, and handed to iOS as a one-shot calendar notification. iOS delivers it whether or not the app is running. No background execution, no periodic wake-ups.

Reuses `FactorVIIIModel.hoursUntilLevelReaches`, which has existed since task 003 for the Home threshold projection.

## Requirements

- [x] `AlertSchedule` — pure computation of *when* alerts fire, free of UserNotifications.
- [x] `NotificationService` behind a `NotificationScheduling` protocol, wrapping `UNUserNotificationCenter`.
- [x] `AlertsViewModel` — owns `AlertSettings`, requests permission, keeps pending notifications in step.
- [x] `AlertsView` — toggle, threshold slider, lead-time chips, follow-up toggle + chips, scheduled list, disclaimer.
- [x] Permission requested on first toggle-on, not at launch.
- [x] Schedule rebuilt whenever the injection history changes.
- [x] Settings persist.

## Architecture

**Timing logic separated from delivery.** `AlertSchedule` decides *when*; `NotificationService` only delivers. The timing rules are where the real risk is (threshold space conversion, lead time, past-dated alerts), and splitting them out makes them testable without iOS — which can neither be authorized nor inspected from a unit test.

**`NotificationScheduling` is a protocol** so the view model can be tested against a fake that records what it was asked to schedule. Small, local, applied and recorded per the Architecture rules.

**Cross-domain composition stays in the shell.** Alerts need the decay curve, which only `FactorTrackerViewModel` knows. Rather than let `AlertsViewModel` reach across, it exposes `refreshSchedule(model:currentRealPercent:)` and `AppShellView` supplies it — the same arrangement already used for the stock cover estimate.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not drift away from MVVM as a side effect.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] The app builds; all tests pass.
- [x] Alerts off by default; controls hidden until enabled.
- [x] Enabling asks for permission; refusing leaves the toggle off.
- [x] The warning fires the lead time *before* the predicted crossing; the follow-up *after* it.
- [x] A threshold set in display space is converted to real space before the decay is computed.
- [x] Alerts whose moment has passed are dropped, not fired immediately.
- [x] Settings and schedule survive relaunch.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **` — 93 cases, 0 failures; 14 new across `AlertScheduleTests` and `AlertsViewModelTests`). Declared count reconciled against the run (93 = 93) rather than trusting the summary.
- Manual check: driven with real taps on the simulator. Seeded a dose 2 h old. Home showed **39 %** (hand-checked: `2 + 40 × 0.5^(2/19)` = 39.2 ✓). Alerts tab: controls correctly hidden while off; toggling on produced the iOS permission prompt, and "Allow" revealed the threshold slider at 15 % and lead-time chips with 6h selected. Scheduled list showed **"Factor level dropping" 23 Sep 21:49**; enabling follow-up added **"Still below your threshold" 24 Sep 07:49**.

  The two timestamps are **exactly 10 h apart** — the 6 h lead plus the 4 h follow-up — both derived from one predicted crossing at 24 Sep 03:49. That interval is the strongest available confirmation that the scheduling arithmetic is right, and it is verifiable from the two displayed times alone. Consistent too with Home's independent "below 5 % in 2.9d" (`19 × log₂(37.2/3)` = 69 h ✓). No clipping, overlap or contrast problems.

**Not verified in the UI:** dragging the threshold slider. No drag command the interaction tool accepts was found, and SwiftUI `Slider` ignores taps on its track, so "changing the threshold moves the alert earlier" could not be exercised on screen. It *is* covered by the `changingASettingReschedules` unit test, but that is a weaker check than observing it — flagged rather than glossed.

## Notes

**Three deliberate behaviours, each with a test:**

- *Permission is requested on first toggle-on*, so the prompt arrives when the user has just expressed intent, rather than at launch when it reads as noise.
- *A refused permission leaves the toggle off.* Leaving it on would have the screen promise alerts that can never arrive. `refusedPermissionLeavesRemindersOff` pins this.
- *Past-dated alerts are dropped.* If the crossing is closer than the lead time, the warning's moment has already gone — iOS wouldn't deliver it, and the app is on screen anyway. `warningIsDroppedWhenItsMomentHasPassed` pins this.

**The threshold is set in display space and must be converted before use.** With calibration active, a 15 % threshold on screen is a different real number, and computing decay against the display figure would fire the alert at the wrong level. `thresholdIsConvertedOutOfDisplaySpace` covers it — the same trap `DoseLogPlan` had in phase 015.

**Rescheduling replaces rather than diffs.** The predicted crossing moves on every dose logged, edited or deleted, so almost any change invalidates everything pending; alert ids are stable per kind so replacement can't accumulate duplicates.

The 24-hour lead-time chip renders as "1d" rather than "24h" — intentional formatting, noted because it differs from the mock's label.

Files added: `Models/AlertSchedule.swift`, `Services/NotificationService.swift`, `ViewModels/AlertsViewModel.swift`, `Views/Alerts/AlertsView.swift`, `HEMOnitorTests/{AlertScheduleTests,AlertsViewModelTests}.swift`. Modified: `Views/Shell/AppShellView.swift`, `HEMOnitorApp.swift`, `CLAUDE.md`.

**CLAUDE.md correction included here.** The UI-driving instructions added in phase 015 said to have a subagent load a `device-interaction` skill. That skill proved unresolvable for two of three agents, stalling both. The section now says to drive the `mcp__xcode__DeviceInteraction*` tools directly, and records that the session must be opened *by* the subagent — a key handed down from the parent doesn't survive the subagent being resumed.

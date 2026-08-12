# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

HEMOnitor is a SwiftUI iOS app (iPhone + iPad) that estimates a hemophilia patient's Factor VIII (FVIII) level over time from injection doses and exponential half-life decay. It is a tracking/visualisation aid only — the code explicitly disclaims dosing decisions. User-facing strings and doc comments are written in Romanian; keep new ones in Romanian to match.

## Build & test

Xcode project, no dependency manager (no `Package.swift`, `Podfile`, or `Fastfile`). One shared scheme `HEMOnitor`; three targets — the `HEMOnitor` app plus `HEMOnitorTests` (Swift Testing) and `HEMOnitorUITests` (XCTest).

```bash
# Build the app
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build

# Run tests (verified green on an iOS 26.5 simulator)
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Narrow the run: one bundle, or one Swift Testing test
xcodebuild ... -only-testing:HEMOnitorTests test
xcodebuild ... -only-testing:HEMOnitorTests/HEMOnitorTests/example() test
```

Building and testing both work on this machine as of 2026-08-12; the two blockers previously recorded here are resolved. `xcodebuild ... test` against an iOS 26.5 simulator (e.g. `iPhone 17 Pro`) reports `** TEST SUCCEEDED **`. What was fixed, in case either regresses:

1. **Deployment-target mismatch (resolved).** `@testable import HEMOnitor` used to fail because the app target's `IPHONEOS_DEPLOYMENT_TARGET` (18.6) was higher than the test targets' (18.5). The app target is now 17.5, so the test min (18.5) is ≥ the app min and the import compiles with no `IPHONEOS_DEPLOYMENT_TARGET=` override. The three targets are still not fully aligned (app 17.5, tests 18.5, project default 18.5) — benign for `@testable import`, but align them if you want it tidy. Do **not** hand-edit `project.pbxproj` while Xcode is open (a harness hook blocks it and it can crash Xcode); change project settings in Xcode or ask the user.
2. **Simulator runtime (resolved).** An iOS 26.5 runtime is installed (iPhone 17 Pro / 17 / Air, iPad Pro/Air/mini, etc.), so an eligible destination exists. If you land on a machine with only the older runtimes (15.2 / 17.2 / 17.4 / 17.5) again, install one with `xcodebuild -downloadPlatform iOS`. The `platform=macOS,variant=Designed for iPad` destination is *not* a workaround — the test targets have no `DEVELOPMENT_TEAM` and code signing fails.

If `test` fails with "Scheme HEMOnitor is not currently configured for the test action", the shared scheme has lost its `<Testables>` block — restore it with `git checkout HEAD -- HEMOnitor.xcodeproj/xcshareddata/xcschemes/HEMOnitor.xcscheme`.

Both test bundles are still unmodified Xcode templates: `HEMOnitorTests.example` is empty and the UI tests only launch the app. There is no existing test coverage of the pharmacokinetic math.

All three target directories are Xcode 16+ `fileSystemSynchronizedGroups` (objectVersion 77): new source files placed under `HEMOnitor/`, `HEMOnitorTests/`, or `HEMOnitorUITests/` are picked up automatically — do not hand-edit `project.pbxproj` to register them.

## Architecture

MVVM, ~735 lines of Swift in the app target, with no persistence and no networking — all state lives in memory and is lost on relaunch. `HEMOnitorApp` → `ContentView` (owns a `FactorTrackerViewModel` via `@StateObject`) → `CalibrationView`, presented as a sheet and sharing the same view model via `@ObservedObject`.

### The real vs. display level distinction

This is the single concept that everything else hangs off. Every level exists in two forms:

- **real** — the raw pharmacokinetic prediction: `baseline + (peak - baseline) * 0.5^(hours / halfLife)`, floored at `baseline`. All stored state (`InjectionEvent.realLevelBefore`, `peakRealPercent`, `currentRealLevelPercent`) is real/uncalibrated.
- **display** — `real * calibrationFactor`, produced only by `FactorVIIIModel.displayLevel(...)` at render time.

New computations must be done in real space and converted for display at the last step.

### Calibration: two independent mechanisms

`CalibrationView` collects a dose, an observed lab percentage and the hours between them, then always applies A, and additionally applies B when the toggle is on:

- **A — `calibrateRecovery`**: sets `calibrationFactor` so the displayed level at the lab draw time matches the observed lab percentage. Purely cosmetic; PK parameters untouched. Default/recommended.
- **B — `calibrateRecoveryParameter`**: back-solves `recoveryPercentPerIUPerKg` (default 2.0 %/IU/kg) so the *real* prediction matches the observation, undoing the decay to recover the t0 infusion component. Changes the underlying model.

Only B crosses back from display space to real space, dividing the observed value by `calibrationFactor`; A consumes the observed percentage directly. Since `CalibrationView` runs A first and A has just overwritten `calibrationFactor`, B converts through that fresh factor — reordering the two calls changes the numeric result, so treat the ordering as intentional.

Both paths also assume the dose was given from `baselinePercent`, ignoring any residual FVIII from earlier injections.

### Injection history and current level

`FactorTrackerViewModel.recalculateLevels(at:)` only ever decays from `injections.last`; it does not sum contributions from earlier injections. Stacking is handled at injection time instead: `addInjection` recalculates to `date`, reads the current real level, and adds the new dose's delta on top to form the new peak. Consequence: injections must be appended in chronological order, and back-dating an injection would silently corrupt the chain.

`resetAll()` clears the history and returns the level to baseline but deliberately leaves `calibrationFactor` in place, so a reset app is still calibrated.

`ContentView` refreshes via a 60-second `Timer.publish` plus `onAppear`. Patient parameters are hardcoded as init defaults (65 kg, 2 % baseline, 19 h half-life for Elocta) — there is no settings screen. Doses are entered in a "Doză (UI)" text field; `ContentView.parsedDoseIU` normalises commas and rejects anything non-finite or ≤ 0, gating both the "Adaugă injecție" button and an inline validation caption. It is the sole entry point to `addInjection`.

### Time simulation

The `+1h/+6h/+12h/+24h/-24h` controls are view-local (`simulatedOffsetHours` in `ContentView`) and never touch view-model state. For non-negative offsets `simulatedDisplayInfo()` delegates to `FactorVIIIModel.levelAtTime`, but it hand-rolls the backwards case: `levelAtTime` refuses negative `hoursSincePeak` by returning the peak unchanged, so the view re-implements the decay to extrapolate backwards toward the peak, clamped to `[baseline, peak]`. Changing the decay formula therefore means changing it in both the model and that negative branch.

## Agent Workflow

Claude Code operates as an autonomous coding agent for this repository.

### Before starting a task

1. Read `CLAUDE.md`.
2. Read the relevant task file from `tasks/active/`.
3. Inspect the existing implementation before making changes.
4. Identify relevant files, dependencies, and existing behavior.
5. Create an implementation plan internally before editing.

### Implementation

- Keep changes focused on the requested task.
- Prefer the existing architecture and patterns.
- Do not introduce new dependencies unless explicitly required.
- Do not refactor unrelated code.
- Do not change existing business logic unless the task explicitly requires it.
- Preserve existing behavior outside the scope of the task.
- Never change pharmacokinetic formulas or calibration behavior unless explicitly requested.

### Verification

After implementation:

1. Build the affected target.
2. Run relevant tests when available.
3. If the build or tests fail, investigate and fix the issue autonomously.
4. Re-run verification after fixes.
5. Do not claim success without actually verifying it.

### Task completion

When the task is complete:

- Summarize what changed.
- List the files modified.
- Report build/test results.
- Mention any remaining limitations or follow-up work.
- Do not modify files outside the task scope without justification.

### Task lifecycle

Active tasks live in `tasks/active/`.

When a task is fully implemented and verified:
- move the task file to `tasks/completed/`;
- do not modify the completed task unless explicitly requested.

### Human approval

Claude may autonomously inspect, edit, build, test, and fix code for an active task.

Stop and ask for clarification when:
- requirements conflict;
- a change would alter established business logic;
- a destructive operation is required;
- a significant architectural decision is required;
- the task cannot be completed safely from the available requirements.

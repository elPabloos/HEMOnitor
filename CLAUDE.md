# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

HEMOnitor is a SwiftUI iOS app (iPhone + iPad) that estimates a hemophilia patient's Factor VIII (FVIII) level over time from injection doses and exponential half-life decay. It is a tracking/visualisation aid only — the code explicitly disclaims dosing decisions. User-facing strings and doc comments are written in Romanian; keep new ones in Romanian to match.

## Build & test

Xcode project, no dependency manager (no `Package.swift`, `Podfile`, or `Fastfile`). One shared scheme `HEMOnitor`; three targets — the `HEMOnitor` app plus `HEMOnitorTests` (Swift Testing) and `HEMOnitorUITests` (XCTest).

```bash
# Build the app
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build

# Run tests (see the two blockers below first)
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=<device>' test

# Narrow the run: one bundle, or one Swift Testing test
xcodebuild ... -only-testing:HEMOnitorTests test
xcodebuild ... -only-testing:HEMOnitorTests/HEMOnitorTests/example() test
```

Two blockers were confirmed on this machine; re-check them before reporting that tests pass:

1. **The test targets are pinned to iOS 18.5 while the app target is 18.6**, so `@testable import HEMOnitor` fails to compile: `compiling for iOS 18.5, but module 'HEMOnitor' has a minimum deployment target of iOS 18.6`. Appending `IPHONEOS_DEPLOYMENT_TARGET=18.6` to the invocation makes `build-for-testing` succeed. The real fix is to align `IPHONEOS_DEPLOYMENT_TARGET` across all three targets.
2. **No iOS ≥18.6 simulator runtime is installed** (only 15.2 / 17.2 / 17.4 / 17.5), so no eligible simulator destination exists. Install one with `xcodebuild -downloadPlatform iOS`. The `platform=macOS,variant=Designed for iPad` destination is *not* a workaround — the test targets have no `DEVELOPMENT_TEAM` and code signing fails.

Because of blocker 2 no test has actually been executed here, so the per-test `-only-testing:` identifier form above is unverified. Both test bundles are also still unmodified Xcode templates: `HEMOnitorTests.example` is empty and the UI tests only launch the app. There is no existing test coverage of the pharmacokinetic math.

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

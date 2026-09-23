# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

HEMOnitor is a SwiftUI iOS app (iPhone + iPad) that estimates a hemophilia patient's Factor VIII (FVIII) level over time from injection doses and exponential half-life decay. It is a tracking/visualisation aid only — the code explicitly disclaims dosing decisions. User-facing strings and doc comments are written in English; keep new ones in English to match. (The app was originally written in Romanian and translated wholesale in task 009 — if you find stray Romanian text anywhere, it's a leftover, translate it.)

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

`HEMOnitorTests` (Swift Testing) covers persistence (`PersistenceTests`), patient settings (`PatientSettingsTests`) and the injection chain (`InjectionChainTests` — insertion incl. back-dating, editing, deletion, and the real/display split). The template `HEMOnitorTests.example` is still empty, and the UI tests are still the unmodified template that only launches the app. `FactorVIIIModel`'s formulas have no direct unit tests of their own; they're exercised indirectly through the chain tests.

All three target directories are Xcode 16+ `fileSystemSynchronizedGroups` (objectVersion 77): new source files placed under `HEMOnitor/`, `HEMOnitorTests/`, or `HEMOnitorUITests/` are picked up automatically — do not hand-edit `project.pbxproj` to register them.

To change a **build setting** (e.g. `PRODUCT_BUNDLE_IDENTIFIER`), use the Xcode MCP `UpdateTargetBuildSetting` tool rather than editing `project.pbxproj`. It works while Xcode is open, which hand-editing does not — call `XcodeOpenWorkspace` once first to get a `workspaceIdentifier` and to grant access.

## Who verifies what

Agreed split (2026-09-23), after measuring what agent-driven UI testing actually cost and caught:

**The agent does:** build, unit tests, and a **screenshot** of any screen it changed (`xcrun simctl io <udid> screenshot <path>`, then read the image). Screenshots are cheap and they catch layout faults — overlap, clipping, content hidden behind the tab bar. One found a real bug in task 012 for a few thousand tokens.

**The user does:** the interactive tap-through. Tapping buttons, completing flows, checking things feel right.

**Why:** two agent-driven tap sessions cost ~71K and ~130K tokens — comparable to *building an entire screen* — and found no bugs between them. Meanwhile the one real UI bug caught by an agent all session came from a screenshot at ~2% of that price.

**Known consequence, accepted deliberately:** screenshots and unit tests cannot catch "the view renders but its buttons are wired to nothing." Task 021 (unresponsive onboarding buttons) is exactly that, and it reached the user rather than the agent. That is the expected shape of this trade-off, not a failure of it — so don't claim a screen "works" on the strength of a screenshot. Say what was actually checked.

## Driving the UI in the simulator

**Not routine — see the split above.** Reach for this only when a bug genuinely can't be reproduced any other way, and expect it to be expensive. The notes below are kept because they were costly to work out.

Real taps **are** possible, contrary to what earlier task notes (003) recorded. `osascript`/System Events does fail on Accessibility permissions, but Xcode's own device-interaction tooling works and was used to verify the dose-logging flow end to end in task 015. The sequence:

**Spawn a subagent to do it**, and have that subagent own the whole session: `DeviceInteractionStartSession` → `DeviceInteractionSynthesize` (repeatedly) → `DeviceInteractionEndSession`. Sessions are expensive, so always end them, including on abort.

Four traps, all hit in practice:

- **`StartSession` tells you to spawn a subagent that loads a `device-interaction` skill. That skill is frequently not resolvable** — one agent found it, two later ones could not, and stalled. Tell the subagent up front to ignore that instruction and drive the `mcp__xcode__DeviceInteraction*` tools directly from their schemas.
- **Don't open the session in the parent and hand the key down.** It doesn't survive the subagent being resumed ("Session not found"). Let the subagent open its own.
- **Xcode's device list differs from `simctl`'s.** Xcode exposed only iOS 27.0 simulators while `simctl` had been using an iOS 26.5 iPhone 17 Pro, which was *not* selectable. Pick a device from the list `StartSession` returns on failure, then `simctl install`/`launch` onto that same UUID.
- **Coordinates must come from a fresh UI hierarchy dump**, never from the screenshot. `Synthesize` returns paths to both; `interactionCommand` is a short string (`t <x> <y>` to tap), and omitting it just captures current state.

To reach a specific app state without tapping through it, seed the persisted store directly: `xcrun simctl get_app_container <udid> <bundle-id> data`, then write `Library/Application Support/app_state.json` (see `AppState`; dates are `millisecondsSince1970`) and relaunch. Note the app must have been launched once first so the container exists.

## Architecture

MVVM, with local persistence and no networking. Everything the user enters — patient settings, injection history, stock batches, alert preferences — is saved to a single JSON file (`app_state.json`) under Application Support, and reloaded at launch. See "Persistence" below.

`HEMOnitorApp` owns one `AppRepository` plus a `FactorTrackerViewModel` and a `StockViewModel` built against it, and roots at `AppShellView`. That shell shows `OnboardingView` until onboarding is done, then a four-tab layout (`HomeView`, `StockView`, Alerts placeholder, `YouView`) with a floating log button, and presents the sheets (`LogDoseSheet`, `AddStockSheet`, `CalibrationView`).

### Persistence

`PersistenceStore` is a two-method protocol (`load()`/`save(_:)`) with two conformances: `FileManagerPersistenceStore` (atomic JSON on disk, falls back to defaults if the file is missing or corrupt) and `InMemoryPersistenceStore` (previews and tests). `AppRepository` holds the loaded `AppState` and exposes scoped mutators, so every view model writes into one shared state rather than clobbering each other's slice. View models call an explicit `persist…()` after each mutation — no automatic saving.

The protocol is deliberately the only thing that knows storage is a local file. Swapping in a remote backend means writing a third conformance; note the protocol is currently **synchronous**, which is the main thing that would have to change for a network-backed store.

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

`FactorTrackerViewModel.recalculateLevels(at:)` decays from a single injection — the most recent one at or before the given date — rather than summing contributions from all earlier injections. Stacking is handled at injection time instead: each event stores the real level immediately before it (`realLevelBefore`) and the peak it produced (`peakRealPercent`), each built on the decayed remainder of the event before it.

`injections` is therefore an ordered chain, kept sorted ascending by `date`, where every event depends on the one preceding it. Any change to the chain invalidates everything after the change, so `addInjection`, `updateInjection` and `deleteInjection` all splice the array and then call `recomputeChain(fromIndex:)`, which walks forward rebuilding each event from its predecessor (events before the change point are provably unaffected and left alone). Events keep their `id` across a rebuild, so SwiftUI identity survives.

This means back-dating is fully supported: an injection can be recorded, re-dated or deleted at any position, and the resulting chain depends only on the *set* of injections, not the order they were entered (there's a test asserting exactly that). Two injections sharing a timestamp are ordered by insertion and stack without decay between them.

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
5. Ask whether the existing patterns actually serve this task. If a different one would
   be a clear improvement in maintainability, scalability, testability, or separation of
   concerns, write it up in the task file's **Architecture** section (see
   `tasks/templates/task.md`) instead of either applying it silently or ignoring it.
   Small, local improvements can just be made and recorded; anything structural needs
   sign-off first — see "Human approval" below.
6. Create an implementation plan internally before editing.

### Implementation

- Keep changes focused on the requested task.
- Follow the existing architecture and established patterns by default. Propose and use alternative architectural patterns when they provide a clear technical improvement in maintainability, scalability, testability, or separation of concerns.
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

# Task: Move patient parameters into persisted AppSettings

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

Patient parameters (weight, baseline, half-life, product) and app preferences (onboarding state, display style) come from the persisted `AppSettings` rather than literals hardcoded in a view, and changes to them survive a relaunch. State plumbing only — no new UI.

## Context

Phase 010 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`), depends on 008's persistence layer.

Before this task, `ContentView.init` carried `FactorTrackerViewModel(weightKg: 65, baselinePercent: 2, halfLifeHours: 19)` as a default-parameter literal — the only place patient parameters were defined (CLAUDE.md: "Patient parameters are hardcoded as init defaults... there is no settings screen"). Task 008 added `AppSettings` with the same values as `defaultSettings` but nothing read them for the patient params yet.

Phases that need this: 012 nav-shell (app root), 017 you-tab (profile editing), 019 onboarding (writes the params, flips `hasCompletedOnboarding`), 014 home-rebuild (reads `displayStyle`).

## Requirements

- [x] Remove the hardcoded 65/2/19 literals from `ContentView.init`; its default is now `FactorTrackerViewModel()`, which builds from `AppSettings.defaultSettings`.
- [x] Replace the old `init(weightKg:baselinePercent:halfLifeHours:)` with `init(settings:)` so no construction site can reintroduce loose patient-parameter literals.
- [x] Expose `productName`, `hasCompletedOnboarding` and `displayStyle` on `FactorTrackerViewModel`, loaded from settings.
- [x] `updatePatientParameters(weightKg:baselinePercent:halfLifeHours:productName:)` — all optional, updates only what's passed, recalculates levels, persists.
- [x] `completeOnboarding()` — flips the flag and persists.
- [x] `displayStyle` is settable and persists via `didSet`.
- [x] Fold `persistCalibration()` into a single `persistSettings()` that writes the whole settings slice.
- [x] Update the `CalibrationView` preview to build its view model from `AppSettings`.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`, `calibrateRecoveryParameter`, or their ordering) — only the persistence call after them was renamed.
- Do not refactor the MVVM architecture.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.
- No new UI — editing these values from a screen is phase 017 (You tab) and 019 (onboarding).

## Acceptance Criteria

- [x] The app builds.
- [x] Patient parameters, onboarding state and display style all survive a reload from the same store.
- [x] Calibration still persists (regression — its persistence path was refactored).
- [x] Updating a patient parameter doesn't clobber calibration, and vice versa.
- [x] The preview-only, unpersisted init writes to no store.
- [x] Existing behavior is unchanged: with default settings the app starts at exactly the same 65/2/19 parameters as before.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **` — 13 cases: 7 new `PatientSettingsTests`, plus the 4 `PersistenceTests` and the template `example()`)
- Manual check: none — no UI changed. `defaultSettingsMatchThePreviouslyHardcodedValues` pins the old literals as a test, so a silent change to the startup parameters would fail the suite.

## Notes

**Single source of truth for PK parameters.** `AppSettings` and `FactorVIIIModel` both carry weight/baseline/half-life/recovery/calibrationFactor, which risks two competing copies. Resolved by making `model` authoritative at runtime and treating `AppSettings` as pure storage: settings are read into `model` once at init, and `persistSettings()` projects `model` back out. Settings are never read back into `model` outside of init. The alternative — storing an `AppSettings` on the view model and deriving `model` from it — doesn't work cleanly because the calibration methods mutate `model` in place.

**`persistCalibration()` → `persistSettings()`.** Rather than one persist function per concern (which would need a new one for patient params and another for preferences, each at risk of dropping a field), there's now a single function that writes every settings field from current state. It's always correct to call after any settings-affecting change. Two tests specifically guard the failure mode this design avoids: calibration surviving a patient-parameter update, and vice versa.

**Removed rather than kept** the old `init(weightKg:baselinePercent:halfLifeHours:)`. Keeping it would leave an easy path to reintroduce exactly the hardcoded literals this task removes. Tests and previews that want non-default parameters mutate a copy of `AppSettings.defaultSettings`, which is two lines and reads clearly.

`updatePatientParameters` takes all-optional parameters so a caller can update one field without restating the others — the You tab (017) will edit these individually. It calls `recalculateLevels()` because changing baseline or half-life changes the current estimate immediately.

Files modified: `ViewModels/FactorTrackerViewModel.swift`, `Views/ContentView.swift`, `Views/CalibrationView.swift` (preview only). Added: `HEMOnitorTests/PatientSettingsTests.swift`.

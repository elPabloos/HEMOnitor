# Task: Replace the hardcoded test-injection button with a dose input

**Status:** completed
**Created:** 2026-08-12
**Completed:** 2026-08-12

## Objective

The user can type an injection dose in IU and add that injection, instead of being
limited to the hardcoded "Injecție 3000 UI (test)" button. The entered dose flows into
the existing `addInjection` path unchanged.

## Context

`ContentView` was the only entry point for creating injections, via a fixed
`Injecție 3000 UI (test)` button that called
`FactorTrackerViewModel.addInjection(doseIU:)` with a literal 3000. That is a
development placeholder, not usable behavior.

Relevant code:

- `HEMOnitor/Views/ContentView.swift` — the dose entry UI and its validation.
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — `addInjection(doseIU:)`, which
  already accepts an arbitrary dose and handles stacking on top of the current real
  level. No view-model change should be needed.

Relevant CLAUDE.md sections: **Architecture → Injection history and current level**
(injections must be appended in chronological order; `addInjection` is where stacking
happens) and **The real vs. display level distinction** (the dose is consumed in real
space; nothing here touches display conversion).

Note: an uncommitted implementation of this task already exists in the working tree
(`doseText`, `parsedDoseIU`, `addInjectionFromInput()`, the "Doză (UI)" field). This
task file specifies the intended work and is the checklist that implementation must be
verified against before it is committed.

## Requirements

- [x] Remove the hardcoded "Injecție 3000 UI (test)" button.
- [x] Add a text field for entering a dose in IU, labelled in Romanian ("Doză (UI)"),
      using a numeric keyboard.
- [x] Parse the entered text into a dose, accepting both `.` and `,` as the decimal
      separator.
- [x] Reject empty, non-numeric, non-finite and non-positive input.
- [x] Disable the "Adaugă injecție" button while the input is invalid, and show an
      inline validation caption in Romanian when the user has typed something invalid.
- [x] Pass the parsed dose to the existing `viewModel.addInjection(doseIU:)`; do not
      duplicate or reimplement any of its logic.
- [x] Clear the input after a successful injection.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`,
  `calibrateRecoveryParameter`, or their ordering).
- Do not refactor the MVVM architecture; this is a view-layer change plus, if strictly
  needed, nothing more.
- Keep all user-facing strings and doc comments in Romanian.
- Do not hand-edit `project.pbxproj`.
- Do not touch the time-simulation controls, the injection history list, or
  `resetAll()`.
- Keep the change minimal and scoped to dose entry.

## Acceptance Criteria

- [x] The user can enter a dose in IU and add an injection with it.
- [x] The dose is validated before an injection is created; invalid input cannot
      produce an injection.
- [x] The existing calculation logic receives the entered dose (a 3000 IU entry
      produces the same result the old test button did).
- [x] The hardcoded test button is gone.
- [x] The app builds.
- [x] Behavior unrelated to dose entry — decay display, history, calibration, time
      simulation — is unchanged.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
```

- Build: PASS. `BuildProject` succeeded in ~4.9s with no errors/warnings (Xcode build
  system). The `xcodebuild ... build` command in this file is the documented equivalent.
- Tests: NOT RUN — blocked. Per CLAUDE.md "Build & test": test targets pinned to iOS
  18.5 vs app 18.6 (`@testable import` fails to compile) and no iOS ≥18.6 simulator
  runtime is installed, so no eligible test destination exists. There is also no
  existing test coverage of dose entry to run.
- Manual check: reasoned from `parsedDoseIU` — valid dose accepted; comma decimal
  normalised via `replacingOccurrences(of: ",", with: ".")`; `0` and negative rejected
  by `dose > 0`; empty rejected (`Double("")` → nil, and caption suppressed while
  empty); garbage text rejected by `Double(...)` returning nil. Not exercised in a
  running simulator due to the runtime blocker above.

## Notes

- The implementation already existed uncommitted in the working tree; this task was a
  verification pass against the checklist, not new authoring. No source changes were
  needed — the existing `ContentView.swift` satisfies every requirement and constraint.
- The lone remaining "3000" in the codebase is an illustrative example in a doc comment
  at `FactorVIIIModel.swift:80` (calibration explanation), not the removed test button.
  Left untouched — out of scope and not user-facing UI.
- Pharmacokinetic formulas, the real/display split, calibration behavior and ordering,
  time-simulation controls, history and `resetAll()` were all left unchanged.

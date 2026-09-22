# Task: Three-step onboarding wizard

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

A self-contained `OnboardingView` that walks a new patient through body weight &
baseline, product & half-life, and a summary, committing the result to the
existing view model only on the final step.

## Context

Phase 019 of the full-rebuild plan, built in parallel with sibling agents working on
other screens off `task/012-nav-shell`. `AppSettings.hasCompletedOnboarding` and
`FactorTrackerViewModel.completeOnboarding()` already exist (task 010); this task
only builds the wizard UI that calls them. Wiring `OnboardingView` into the app root
(gating `AppShellView`/`HEMOnitorApp` on `hasCompletedOnboarding`) is explicitly out
of scope — see "Integration notes" below.

Relevant existing files (read-only inputs to this task):
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — `updatePatientParameters(weightKg:baselinePercent:halfLifeHours:productName:)` and `completeOnboarding()`.
- `HEMOnitor/Models/AppSettings.swift` — `defaultSettings` (65kg / 2% baseline / 19h Elocta), used by previews.
- `HEMOnitor/DesignSystem/{Colors,Theme,Typography,Modifiers}.swift` — design tokens; `AppTextStyle.onboardingTitle` (34pt extraBold) already exists and was clearly sized for this screen.

## Requirements

- [x] Shared chrome: 3-bar progress indicator, uppercase kicker, large title (max width ~300pt), body paragraph, bottom Back (steps 2–3) + primary CTA row.
- [x] Step 1: weight stepper (44×44 circular ± buttons, 1kg steps, 20–200kg range) and a 3-tier baseline severity picker (severe <1%, moderate 1–5%, mild >5%), inside a `.glassCard()`.
- [x] Step 2: vertical list of selectable product cards (Elocta 19h, Adynovi 15h, Advate 12h, Other 12h), half-life in `Font.plexMono` bold, green border when selected, footnote about calibration personalizing the estimate later.
- [x] Step 3: `.glassCard()` "Your setup" summary with hairline-divided key/value rows in `Font.plexMono`, plus a tracking-aid-not-a-dosing-tool disclaimer.
- [x] Local `@State` for all in-progress selections; commit only on the final step via `updatePatientParameters` + `completeOnboarding` (no new view-model API).
- [x] `onFinished: () -> Void` closure, called after committing.
- [x] Does not touch `AppShellView`/`HEMOnitorApp` or gate the app root itself.
- [x] `#Preview`s for all three steps.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not drift away from MVVM as a side effect.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.
- Keep the change minimal and scoped to this task — no edits outside `HEMOnitor/Views/Onboarding/` and this task file (plus a new test file).

## Acceptance Criteria

- [x] The app builds.
- [x] Existing tests still pass.
- [x] `OnboardingView(viewModel:onFinished:)` compiles standalone and can be dropped into any presentation context (sheet, root swap) by a future integration task.
- [x] Behavior unrelated to this task (existing screens, view model) is unchanged.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`).
- Tests: PASS — 36 tests total (30 pre-existing + 6 new `OnboardingModelsTests`), all green including `** TEST SUCCEEDED **`.
- Manual check: not performed — this environment can't drive simulator taps/scrolls (same limitation noted in tasks 003/012). Verified by mechanism: the wizard is pure state + existing view-model calls, and `#Preview`s render all three steps for visual inspection in Xcode.

## Notes

**Baseline tiers.** Used the standard hemophilia severity classification (WFH
guidelines): severe <1%, moderate 1–5%, mild >5%. Representative numeric values
chosen from the middle of each range — 0.5%, 3%, 7% — since the picker asks for a
tier, not an exact lab value. `BaselineTier.closest(to:)` maps a stored percentage
back to a tier (used to pre-select step 1 from the view model's current
`baselinePercent`, e.g. so re-opening onboarding with the 2% default lands on
"Moderate") and is unit-tested, including that the app's actual 2% default maps to
moderate.

**Product catalogue.** `OnboardingProduct.catalogue`: Elocta (19h, extended
half-life — matches the app's own hardcoded default), Adynovi (15h, extended
half-life), Advate (12h, standard half-life), and a generic "Other" entry (12h,
fixed, not user-editable) for anything not listed. Half-lives are population
averages for a tracking aid, explicitly not prescribing information — the existing
`CalibrationView` is how a patient personalizes this from a real lab result, and
step 2's footnote says so. `OnboardingProduct.matching(productName:)` falls back to
"Other" for any unrecognized name, used to pre-select step 2 from the view model's
current `productName`.

**"Other" has a fixed half-life, not a custom-entry field.** The task only asked
for a generic fallback option in the list, not a custom half-life input. Kept it to
scope; a follow-up could add a numeric field that appears when "Other" is selected
if that turns out to be needed.

**Preview support required a small, deliberate addition to the public init.**
`OnboardingView.init` takes an optional `previewStepIndex: Int = 0` purely so the
three `#Preview`s can land directly on steps 2 and 3 without a human walking
through the wizard in Xcode. Default is 0 so every real call site is unaffected;
flagging it since it's a slight widening of the "clean initializer" ask.

**Selections are pre-filled from the view model's current values**, not blank —
`init` reads `viewModel.model.{weightKg,baselinePercent}` and `viewModel.productName`
to seed the initial `@State`. This wasn't explicitly requested but costs nothing and
avoids re-onboarding overwriting good existing settings with the picker's defaults
if the wizard is ever re-entered after first completion (e.g. from a future
"redo onboarding" entry point in Settings).

### Integration notes for the parent/integrator

- **Not wired into the app root.** Per the task's explicit instruction, this agent
  did not touch `HEMOnitor/Views/Shell/AppShellView.swift` or
  `HEMOnitor/HEMOnitorApp.swift`. Whoever wires this up should show
  `OnboardingView(viewModel: viewModel, onFinished: { /* dismiss or nothing —
  hasCompletedOnboarding is already true */ })` when
  `viewModel.hasCompletedOnboarding == false`, and let that published property
  (already `@Published` on `FactorTrackerViewModel`) drive the switch back to the
  normal shell — `completeOnboarding()` is called before `onFinished()`, so by the
  time the closure runs the flag is already flipped and persisted.
- No new view-model or model API was added; `updatePatientParameters` and
  `completeOnboarding` are called exactly as they exist today.

Files added:
- `HEMOnitor/Views/Onboarding/OnboardingModels.swift` — `BaselineTier`, `OnboardingProduct` (pure, unit-tested).
- `HEMOnitor/Views/Onboarding/OnboardingWeightBaselineStep.swift` — step 1.
- `HEMOnitor/Views/Onboarding/OnboardingProductStep.swift` — step 2.
- `HEMOnitor/Views/Onboarding/OnboardingSummaryStep.swift` — step 3.
- `HEMOnitor/Views/Onboarding/OnboardingView.swift` — chrome + step switch + commit.
- `HEMOnitorTests/OnboardingModelsTests.swift` — 6 tests over the tier mapping and product catalogue.

# Task: "You" tab (profile/settings screen)

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

A standalone `YouView` exists, built with the design-token system, showing the
patient's profile, an editable settings sheet, a display-style picker, a timeline
entry point, a calibration call-to-action, and a reset control — matching the "You"
design mock. It is not yet wired into `AppShellView`.

## Context

Phase 017 of the full-rebuild plan, one of several screen phases that fill in the
tab shell built by 012 (`tasks/completed/012-nav-shell.md`). Built in an isolated
worktree in parallel with sibling agents building other screens, so this task
touches only `HEMOnitor/Views/You/**` (plus this task file and one new test file) —
see `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` and
`HEMOnitor/Models/AppSettings.swift` for the APIs consumed here (both read-only to
this task; every method needed — `updatePatientParameters`, `displayStyle`,
`resetAll` — already existed).

## Requirements

- [x] Profile rows card (`.glassCard()`): Weight (kg), Baseline level (%),
      Half-life (h), Product, Recovery (%/IU/kg) — key left in
      `AppColor.inkSecondary`, value right-aligned in `Font.plexMono` bold,
      hairline dividers between rows.
- [x] Editing via a sheet (`ProfileEditSheet`), opened from a pencil button in the
      card header. Saves through the existing
      `updatePatientParameters(weightKg:baselinePercent:halfLifeHours:productName:)`,
      passing `nil` for any field the user didn't actually change.
- [x] Comma-tolerant parsing, same convention as `HomeView.parsedDoseIU`. Validation:
      weight and half-life must be finite and > 0; baseline must be finite and >= 0;
      product name must be non-blank after trimming. Inline validation messages in
      the same style as `HomeView.doseValidationMessage` (caption, `.secondary`,
      shown only once the field is non-empty but invalid).
- [x] Display-style picker ("Level display"), segmented control bound directly to
      `viewModel.displayStyle` (`.ring` / `.numeral` / `.curve`).
- [x] Timeline nav row: tappable glass card, "Timeline" / "Estimated level over
      time & injection history", chevron, takes `onOpenTimeline: () -> Void`.
      Does not build the timeline screen itself.
- [x] Calibration CTA: `AppColor.brandGradient` fill, `.themeShadow(.ctaGreen)`,
      white text, title + explanatory body line + a status line ("Calibration
      active" / "Not calibrated yet") with a chevron, derived from
      `viewModel.model.calibrationFactor != nil`. Takes `onCalibrate: () -> Void`.
- [x] Reset button: full-width capsule, `AppColor.dangerBackground` fill /
      `AppColor.dangerForeground` border+label, "Reset level & history", gated by a
      confirmation alert before calling `viewModel.resetAll()`.
- [x] Footnote explaining that reset clears injections and returns to baseline but
      keeps calibration (confirmed against `resetAll()` before writing the copy —
      it clears `injections`, resets both level fields to baseline, and never
      touches `model.calibrationFactor`).

## Architecture

No deviations from the existing patterns. `YouView` takes navigation as closures
(`onOpenTimeline`, `onCalibrate`) rather than presenting those destinations itself,
matching `QuickActionsCard`'s existing `onAddInjection`/`onCalibrate`/
`onViewHistory` shape and `AppShellView`'s stated preference (see 012's Architecture
section) for closures over a router object.

One small, local addition recorded here per the Architecture section's own
guidance: `ProfileValueFormatting`/`ProfileEditParsing` (`HEMOnitor/Views/You/
ProfileEditParsing.swift`) are free functions with no SwiftUI dependency, split out
so the parsing/validation/formatting rules are unit-testable without a hosted view.
This mirrors how `FactorVIIIModel` already keeps the pure math separate from the
views that render it — no new layer, just keeping non-UI logic non-UI.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`, `calibrateRecoveryParameter`,
  or their ordering) — this task doesn't touch either; the CTA only opens a
  caller-supplied calibration flow.
- Do not drift away from MVVM as a side effect.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.
- Keep the change minimal and scoped to this task: only
  `HEMOnitor/Views/You/**`, this task file, and one new test file were touched.
  `FactorTrackerViewModel`, `AppSettings`, the design system, `HomeView`, and
  `AppShellView` were not modified.

## Acceptance Criteria

- [x] `YouView` builds and previews with `FactorTrackerViewModel(settings: .defaultSettings)`.
- [x] Editing profile fields through `ProfileEditSheet` updates `viewModel.model`/
      `viewModel.productName` via `updatePatientParameters`, sending `nil` for
      unchanged fields.
- [x] Invalid input (non-finite/non-positive weight or half-life, negative
      baseline, blank product name) shows an inline message and disables Save.
- [x] The display-style picker changes `viewModel.displayStyle` (which persists on
      its own, per `didSet` on the view model — unchanged by this task).
- [x] Tapping the reset button requires confirmation before `resetAll()` runs.
- [x] The app builds; existing tests are unaffected.
- [x] `YouView` is not referenced from `AppShellView` — deliberately left for the
      integrating agent (see Integration notes below).

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`).
- Tests: PASS (`** TEST SUCCEEDED **`) — all pre-existing tests plus the 12 new
  `ProfileEditParsingTests` cases (formatting: whole-number trimming, decimal
  rounding, non-finite handling; parsing: weight/baseline/half-life bounds,
  comma-tolerant input, blank/garbage rejection; product-name trimming).
- Manual check: not performed — this environment can't drive taps/scrolls in the
  simulator (same limitation noted in tasks 003 and 012). Verified by reading
  through the view code and by the `#Preview`s compiling for each new file
  (`YouView`, `ProfileRowsCard`, `ProfileEditSheet`, `TimelineNavCard`,
  `CalibrationCTACard`).

## Notes

**Not wired into the app.** Per the task brief, `AppShellView.swift` was left
untouched — a sibling agent owns that file. See "Integration notes" below for
exactly what the integrating change needs to do.

**Sheet uses a plain `Form`, not the glass design tokens.** The card-level chrome
(profile rows, timeline nav, calibration CTA) follows the new design system, but
`ProfileEditSheet` is a `NavigationStack` + `Form`, matching `CalibrationView`'s
existing sheet pattern rather than introducing a new glass-styled form. The task
brief didn't specify a look for the sheet itself beyond "make the profile rows
editable via a sheet," and reusing the established sheet pattern keeps the edit
flow consistent with the app's other data-entry sheet.

**Product name is required, with no way to clear it.** `updatePatientParameters`
takes an optional `productName`, but empty text is treated as invalid input (Save
disabled) rather than "no product," since the profile card always needs something
to display in that row.

### Integration notes (for whoever wires this into `AppShellView`)

- Replace the `.you` case in `AppShellView.content` with:
  ```swift
  case .you:
      YouView(
          viewModel: viewModel,
          onOpenTimeline: { /* switch to the timeline destination, once it exists */ },
          onCalibrate: { /* e.g. isShowingCalibrationSheet = true, then .sheet { CalibrationView(viewModel: viewModel) } */ }
      )
  ```
- `YouView` renders on a transparent background by design, so `AppShellView`'s
  `AppColor.backgroundGradient` shows through underneath — do not wrap it in an
  opaque container.
- The timeline screen itself is out of scope for this task (later phase); until it
  exists, `onOpenTimeline` can point at a `ComingSoonView(tab: .you)` or similar.
- `onCalibrate` can reuse the existing `CalibrationView` sheet exactly as `HomeView`
  already does — no changes needed there.

Files added: `HEMOnitor/Views/You/{YouView,ProfileRowsCard,ProfileEditSheet,
ProfileEditParsing,TimelineNavCard,CalibrationCTACard}.swift`,
`HEMOnitorTests/ProfileEditParsingTests.swift`.

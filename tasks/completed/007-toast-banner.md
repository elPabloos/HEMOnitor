# Task: Reusable toast/snackbar component

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

There's a small, self-contained toast component (success/error/info) that any screen can present via a `ToastPresenter`, styled with the phase-006 design tokens, so later phases (Stock, log sheets, Alerts, Calibration) can surface confirmations/errors without inventing their own each time.

## Context

Phase 007 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`), depends only on phase 006's design tokens (`AppColor`, `Theme`, `.glassCard()`). Sequenced early because several later phases (012 stock-tab, 014 sheet-system, 015 alerts) are expected to need it, e.g. for the "blocked — not enough vials" case noted in phase 012's scope.

## Requirements

- [x] `Toast`/`ToastKind` model (success/error/info, each with an SF Symbol + tint).
- [x] `ToastPresenter` (`ObservableObject`) with `show(_:kind:duration:)` and `dismiss()`, auto-dismissing after a duration via `Task.sleep`.
- [x] `ToastBanner` view rendering a single toast with the phase-006 glass-card style.
- [x] `.toastHost(_:)` view modifier any screen can attach to overlay the current toast at the top, with a spring transition and tap-to-dismiss.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not refactor the MVVM architecture.
- Keep all user-facing strings and doc comments in Romanian.
- Do not hand-edit `project.pbxproj`.
- Not wired into any existing screen yet — this phase only adds the component; adoption happens in the phases that need it (012+).

## Acceptance Criteria

- [x] The app builds.
- [x] `ToastPresenter`/`ToastBanner`/`.toastHost` compile and are usable from any `View` without additional setup beyond owning a `ToastPresenter` instance.
- [x] Existing behavior is unchanged (no existing screen references the new files yet).

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **`, `HEMOnitorTests/example()`)
- Manual check: none needed beyond build/test — component isn't wired into any live screen yet, so there's nothing to exercise in the simulator UI. A `#Preview` was added to `ToastBanner.swift` for visual iteration in Xcode.

## Notes

Kept the toast surface as a glass card (matching phase 006's card style) rather than a fully saturated colored banner, so it reads as part of the same design system as everything else rather than a one-off component.

`ToastPresenter` is `@MainActor` + `ObservableObject`, matching this codebase's existing pattern (`FactorTrackerViewModel`) rather than introducing the `@Observable` macro — kept consistent per CLAUDE.md's "don't refactor the MVVM architecture."

Files added: `HEMOnitor/Views/Toast/{ToastPresenter,ToastBanner}.swift`. No existing files touched.

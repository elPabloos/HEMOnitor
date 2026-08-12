# Task: <short imperative title>

**Status:** active
**Created:** YYYY-MM-DD
**Completed:** —

## Objective

One or two sentences: what must be true when this task is done. State the outcome,
not the implementation.

## Context

Why this task exists and what a reader needs to know before touching the code.
Point at the relevant files/types (e.g. `HEMOnitor/Views/ContentView.swift`,
`FactorTrackerViewModel.addInjection`) and at the CLAUDE.md sections that apply.

## Requirements

- [ ] Concrete, checkable statements of what to build.
- [ ] One requirement per line; keep them observable.

## Constraints

What must NOT change. Default constraints for this project — delete only if the task
explicitly overrides them:

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`, `calibrateRecoveryParameter`,
  or their ordering).
- Do not refactor the MVVM architecture.
- Keep all user-facing strings and doc comments in Romanian.
- Do not hand-edit `project.pbxproj`; new sources under the synchronized target
  directories are picked up automatically.
- Keep the change minimal and scoped to this task.

## Acceptance Criteria

- [ ] Observable, user- or test-verifiable outcomes.
- [ ] Behavior unrelated to this task is unchanged.
- [ ] The app builds.

## Verification

How the criteria above were actually checked. Record the commands run and their real
outcome — including "not run" and why.

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
```

- Build: <result>
- Tests: <result, or the blocker from CLAUDE.md "Build & test" that prevented running them>
- Manual check: <what was exercised in the UI, if anything>

## Notes

Decisions taken, alternatives rejected, assumptions made, and follow-up work that was
deliberately left out of scope.

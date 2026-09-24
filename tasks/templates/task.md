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

## Architecture

Optional — omit this section entirely when the task just follows the existing patterns.
Most tasks should.

Follow the existing architecture by default. Where a different pattern would be a clear
technical improvement in **maintainability, scalability, testability, or separation of
concerns**, it may be used — but record it here rather than applying it silently:

- What the current pattern is, and where it falls short *for this task*.
- The proposed alternative, and which of the four dimensions above it improves.
- What it costs: migration effort, added indirection, anything it makes harder or
  less obvious to a reader.

A change that is small and local (extracting a helper, introducing a protocol so
something can be faked in tests, splitting an overloaded type) can be applied and simply
recorded here. Anything structural — a new layer, a change to how state flows or who
owns it, swapping a framework-level choice — is a significant architectural decision:
propose it and get sign-off *before* applying it, per the "Human approval" rules in
CLAUDE.md.

"It would be tidier" is not sufficient justification. Name the concrete problem it
solves in this task.

## Constraints

What must NOT change. Default constraints for this project — delete only if the task
explicitly overrides them:

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`, `calibrateRecoveryParameter`,
  or their ordering).
- Do not drift away from MVVM as a side effect. A deliberate, justified deviation is
  fine — it belongs in the Architecture section above, stated rather than slipped in.
- Keep all user-facing strings and doc comments in English.
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
  State what the tests actually verify. If the task involves a gesture, they verify the
  logic behind it, not the interaction — say so in those words.
- Screenshot: <what the screenshot showed, or "n/a — no UI changed">
- Interactive check: **left to the user** — see "Who verifies what" in CLAUDE.md.
  Note here anything specific worth tapping through, and be explicit that it is
  unverified. Do not describe a screen as working on the strength of a screenshot.
  **Never write tests that simulate touch** (tap/drag/swipe/scroll/pinch) — see
  "Never write tests for physical interaction" in CLAUDE.md. Leave those to the user
  and list them here instead.

## Notes

Decisions taken, alternatives rejected, assumptions made, and follow-up work that was
deliberately left out of scope.

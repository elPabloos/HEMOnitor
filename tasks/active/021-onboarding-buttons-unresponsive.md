# Task: Fix unresponsive onboarding buttons

**Status:** active
**Created:** 2026-09-23
**Completed:** —

## Objective

The onboarding wizard's controls respond to taps, so a new user can actually complete setup instead of being stuck on step 1.

## Context

Found by the user running the app on the simulator on 2026-09-23. On a fresh install the app opens to `OnboardingView` and **no button works** — reportedly including the weight steppers, the baseline tier buttons, and the "Continue" CTA.

This was not caught earlier: task 019's agent verified only that it built, and the screenshot taken during task 012 showed onboarding rendering correctly but nothing was ever tapped. It is exactly the bug class that screenshots and unit tests cannot catch — "the view looks right but is wired to nothing."

Built in phase 019 (`tasks/completed/019-onboarding.md`). Relevant files:
- `HEMOnitor/Views/Onboarding/OnboardingView.swift` — owns step state, Back/CTA footer, `commitAndFinish()`
- `HEMOnitor/Views/Onboarding/OnboardingWeightBaselineStep.swift` — weight steppers, baseline tiers
- `HEMOnitor/Views/Onboarding/OnboardingProductStep.swift`, `OnboardingSummaryStep.swift`
- `HEMOnitor/Views/Shell/AppShellView.swift` — gates on `viewModel.hasCompletedOnboarding`

## Requirements

- [ ] Reproduce on a clean install (delete the app, or clear `app_state.json`).
- [ ] Identify why taps aren't landing. Likely candidates, cheapest first:
  - A `.glassCard()` / background or overlay above the controls swallowing hits (missing `.contentShape`, or an overlay without `.allowsHitTesting(false)`).
  - Buttons nested inside a container that is itself a `Button` or has a tap gesture.
  - The step views taking value copies instead of `@Binding`, so taps mutate a discarded copy and nothing visibly changes — the buttons would "work" but appear dead.
- [ ] Fix, and confirm all three steps can be completed through to the app root.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [ ] On a clean install, a user can set weight and baseline, choose a product, review the summary, and reach Home.
- [ ] `updatePatientParameters` and `completeOnboarding()` are called with the chosen values, and they persist across relaunch.
- [ ] Back navigation works from steps 2 and 3.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: —
- Tests: —
- Manual check: **the user taps through it.** This is the agreed split going forward: the agent does build + tests + screenshot, interactive tap-through is the user's. This bug is the case in point for why.

## Notes

**Workaround while unfixed:** the onboarding gate can be skipped by setting `hasCompletedOnboarding` in the simulator's saved state, without touching code:

```bash
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
C=$(xcrun simctl get_app_container $UDID com.ciudinpaul.HEMOnitor data)
# edit "$C/Library/Application Support/app_state.json" → settings.hasCompletedOnboarding = true
```

**The user also noted they've never seen this screen in the design mock.** Worth confirming the onboarding flow is actually wanted before investing in fixing it — the mock does contain a 3-step onboarding section, but if it isn't part of the intended product, deleting `Views/Onboarding/` and dropping the gate in `AppShellView` is a smaller change than fixing it.

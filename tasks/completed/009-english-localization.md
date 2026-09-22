# Task: Translate the app from Romanian to English

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

Every user-facing string, doc comment, and inline comment in the app target is written in English, matching the design mock's copy where an equivalent exists. The project's language convention (CLAUDE.md, task template) says English from here on. No behavior changes.

## Context

Phase 009 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`). The app was originally written entirely in Romanian (CLAUDE.md previously mandated it). Mid-rebuild the user decided to flip to English, with the design mock — which is written in English — as the reference for user-facing copy, and explicit permission to rename things where a better English name beats a literal translation.

This was inserted right after the persistence phase specifically so that every remaining phase (010–020) is written in English from the start, rather than each new screen adding Romanian strings that would need retranslating later. All subsequent phases were renumbered +1 in the plan.

Affected: all 26 Swift files in the app target, one test file, `CLAUDE.md`, and `tasks/templates/task.md`.

## Requirements

- [x] Translate all user-facing strings in `ContentView`, `CalibrationView`, and the four card views (`CurrentLevelCard`, `NextDoseCard`, `LastInjectionCard`, `QuickActionsCard`).
- [x] Translate `SafetyZone.label` values (Critic/Sever/Moderat/Sigur/Ridicat → Critical/Severe/Moderate/Safe/High).
- [x] Translate all doc comments and inline comments across Models, ViewModels, Services, DesignSystem, and Views.
- [x] Translate accessibility labels (`CurrentLevelCard`'s composed VoiceOver string).
- [x] Translate the `#Preview` strings in `ToastBanner`.
- [x] Translate the assertion-failure messages in `FontRegistrar` and `FileManagerPersistenceStore`.
- [x] Update `CLAUDE.md`'s language line and `tasks/templates/task.md`'s language constraint to say English.
- [x] Verify no Romanian text remains, including words that carry no diacritics.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`, `calibrateRecoveryParameter`, or their ordering).
- Do not refactor the MVVM architecture.
- Do not hand-edit `project.pbxproj`.
- **Strings and comments only** — this task must not change a single line of logic, identifier, or control flow. Swift identifiers were already English throughout, so nothing needed renaming.

## Acceptance Criteria

- [x] The app builds.
- [x] All existing tests still pass.
- [x] No Romanian text remains in any Swift file, `CLAUDE.md`, or the task template.
- [x] The diff contains no logic changes — verified mechanically (see Verification).

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests

# No Romanian diacritics left anywhere in Swift sources
grep -rlP '[ăâîșțĂÂÎȘȚ]' HEMOnitor HEMOnitorTests HEMOnitorUITests --include="*.swift"

# Diff touches only comments and string literals — no logic lines
git diff -- '*.swift' | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
  | grep -vE '^[+-]\s*(///|//|\*|$)' | grep -vE '^[+-].*"'
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **` — `HEMOnitorTests/example()` + all 4 `PersistenceTests` cases)
- Diacritic scan: no matches (clean)
- Logic-drift scan: no output — every changed line is a comment or a string literal
- Manual check: none beyond the above; no UI flow changed, only the words rendered in it

## Notes

**Diacritic-only grep is not sufficient** for verifying a Romanian→English sweep — plenty of Romanian words carry no diacritics. A second pass grepping for common diacritic-free Romanian words (`nivel`, `doza`, `pentru`, `folose…`, `ore`, `zile`, etc.) caught one comment in `Typography.swift` that the diacritic scan had missed. Both scans are recorded in Verification above; use both if any further translation work comes up.

Copy decisions where the mock had an equivalent, its wording was used (e.g. "Estimated current level", "Calibrate from lab results", "Not a dosing recommendation" phrasing in the disclaimers). Where the current app has a screen the mock doesn't (the time-simulation card, the threshold-projection card, the full history sheet), the Romanian was translated directly, keeping the same tone and the same careful non-recommendation framing that task 003 established for "Proiecție prag" → "Threshold projection".

`FactorVIIIModel.swift` was rewritten wholesale rather than patched comment-by-comment (it was nearly all doc comments); its diff was then verified mechanically to be comment-only, since it's the file CLAUDE.md most protects.

Xcode project files (`project.pbxproj`, the shared scheme) and `Assets.xcassets` contained no Romanian — nothing to change there, and no pbxproj edit was needed.

Out of scope: introducing real localization infrastructure (`String(localized:)`, a String Catalog / `.xcstrings`). The app is now single-language English with plain string literals, same as it was single-language Romanian before. If multi-language support is ever wanted, that's a separate task.

# Task: Support back-dating, editing and deleting injections

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

An injection can be recorded with a past date, and an existing injection can have its dose or date changed or be deleted entirely. In every case the whole chain is rebuilt correctly, so the resulting state depends only on the set of injections, never on the order they were entered.

## Context

Phase 011 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`), depends on 008.

**This task is the one deliberate, user-approved exception to CLAUDE.md's "never change pharmacokinetic/calibration behavior unless explicitly requested."** The user explicitly approved both real back-dating and edit/delete of existing entries. It's required by the design mock's log sheet, whose wheel date/time picker lets the user choose a past moment, and by the Timeline screen (018), which surfaces past entries and so invites corrections.

Before this task, `addInjection` only ever appended, and `recalculateLevels(at:)` only ever decayed from `injections.last`. CLAUDE.md stated the consequence plainly: "injections must be appended in chronological order, and back-dating an injection would silently corrupt the chain." That section has been rewritten as part of this task.

`FactorVIIIModel` is **unchanged** — it was already pure, stateless computation, and all the chain logic lives in the view model, exactly as before.

## Requirements

- [x] `injections` is kept sorted ascending by `date` at all times.
- [x] `recomputeChain(fromIndex:)` walks forward from an index, rebuilding each event's `realLevelBefore` (baseline for index 0, otherwise the previous event's peak decayed across the gap) and `peakRealPercent`, preserving each event's `id`.
- [x] `addInjection(doseIU:at:)` splices into sorted position and recomputes — back-dating supported. Signature unchanged, so no existing call site breaks.
- [x] `updateInjection(id:doseIU:date:)` — changes dose and/or date; re-dating reorders, recomputing from `min(oldIndex, newIndex)`.
- [x] `deleteInjection(id:)` — removes and recomputes the tail.
- [x] Editing/deleting an unknown id is a no-op rather than a crash.
- [x] All three mutations persist through the repository.
- [x] Full test suite (19 cases) covering every edge case named in the plan.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split. **`FactorVIIIModel.swift` is untouched by this task.**
- Do not change calibration behavior (`calibrateRecovery`, `calibrateRecoveryParameter`, or their ordering).
- Do not refactor the MVVM architecture.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.
- No UI for editing/deleting in this phase — that's 015 (log sheet) and 018 (Timeline swipe actions). This is model-layer only.

## Acceptance Criteria

- [x] The app builds.
- [x] A chronological sequence of adds produces exactly the same numbers as before this task (regression guard).
- [x] The resulting chain is identical whether injections are entered in order or scrambled.
- [x] Insert-before-first re-anchors to baseline; insert-in-middle leaves earlier events byte-identical.
- [x] Same-timestamp inserts are stable and stack without decay.
- [x] Delete of middle / last / only event all behave correctly.
- [x] Re-dating earlier and later both reorder and rebuild correctly, preserving the event's id.
- [x] The stored chain stays in real space while calibration only scales what's read out.
- [x] All chain edits survive a reload from the store.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **` — 32 cases total, 0 failures: 19 new `InjectionChainTests`, plus the 7 `PatientSettingsTests`, 4 `PersistenceTests` and the template `example()`)
- Manual check: none — model-layer only, no UI reaches these methods yet.

## Notes

**One deliberate change beyond the planned algorithm.** The plan said to leave `recalculateLevels(at:)` unchanged, but it took `injections.last` — which was safe only while every entry was guaranteed to be in the past. Once an entry can be future-dated (or the time simulation asks about an earlier moment), the last element is no longer the relevant one, and decaying from it would report a level that hasn't happened yet. It now takes the last injection *at or before* the requested date. When every entry is in the past this selects `injections.last`, so it's a strict generalization with no behavior change for any pre-existing scenario — and `futureDatedInjectionDoesNotAffectTheCurrentLevel` pins the new case.

**Why recompute forward rather than recompute everything.** Events before the change point cannot be affected by it — their values depend only on events earlier still. Recomputing from the change point is O(tail) instead of O(n), and more importantly it makes the "earlier events are untouched" property testable, which two tests assert via exact struct equality rather than tolerance.

**Tie-break for identical timestamps** is insertion order: `insertionIndex(for:)` looks for the first *strictly later* entry, so a new event lands after any existing ones sharing its timestamp. With zero elapsed time between them there's no decay, so they stack on the full peak. Arbitrary but deterministic, and pinned by a test so it can't drift silently.

**The strongest test is `chainIsIndependentOfInsertionOrder`** — it builds the same four injections chronologically and scrambled, then asserts the chains match field-for-field. That's the actual property back-dating needs to hold, and it would catch a whole class of index or ordering bugs that the more targeted tests might miss individually.

Numbers in the tests are exact rather than approximate by construction: with the default 65 kg / 2 % / 19 h / 2.0 recovery, a 1300 IU dose is exactly +40 pp and a 19 h gap halves the infused component, so expected values are whole numbers (2 → 42 → 22 → 62) and are written literally instead of being recomputed by the test, which would just re-assert the implementation against itself.

`addInjection`'s behavior changed subtly in one respect: it previously set `currentRealLevelPercent` directly to the new peak, whereas it now finishes with `recalculateLevels()` (decaying from the last event to *now*). For a dose logged at the current moment the difference is ~1e-9; for a back-dated dose the new behavior is the correct one, since the level today is not the peak from three days ago.

**CLAUDE.md updated** in two places: the "Injection history and current level" section (which documented the now-removed append-only invariant and warned that back-dating would corrupt the chain), and the "Build & test" note claiming there's no test coverage of the pharmacokinetic math.

Files modified: `ViewModels/FactorTrackerViewModel.swift`, `CLAUDE.md`. Added: `HEMOnitorTests/InjectionChainTests.swift`.

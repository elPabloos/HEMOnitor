# Task: Persistence layer (PersistenceStore + AppRepository)

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

Injections, calibration, and (going forward) other app data survive a relaunch, persisted as JSON on disk through a small, testable `PersistenceStore`/`AppRepository` layer — without changing the pharmacokinetic formulas, the real-vs-display split, or the calibration mechanisms.

## Context

Phase 008 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`). Today the app has zero persistence — `FactorTrackerViewModel`'s state lives only in memory and is lost on relaunch (per CLAUDE.md). This phase adds the storage mechanism and wires `FactorTrackerViewModel` through it; later phases (010 patient-settings-plumbing, 013 stock-tab, 016 alerts-notifications) will use the same `AppRepository` instance for their own state.

Relevant existing code: `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` (owns `model`/`injections`/current levels), `HEMOnitor/Models/InjectionEvent.swift`, `HEMOnitor/HEMOnitorApp.swift` (previously trivial, `WindowGroup { ContentView() }`).

## Requirements

- [x] `PersistenceStore` protocol (`load()`/`save(_:)`).
- [x] `FileManagerPersistenceStore`: JSON under Application Support, atomic write (`Data.write(options: .atomic)`), silent fallback to `AppState()` defaults if the file is missing or corrupt.
- [x] `InMemoryPersistenceStore` for tests/previews.
- [x] `AppState` aggregate (`settings`, `injections`, `stockBatches`, `alertSettings`) — one JSON blob, not four separate files (simpler for this app's scale; revisit only if write-amplification becomes a real problem).
- [x] `AppSettings` (patient parameters + `hasCompletedOnboarding` + `displayStyle`), `StockBatch`, `AlertSettings` — new Codable structs, all fields already shaped for their eventual phases (013/015/016/019) so schema doesn't need to evolve later without a decode-time default.
- [x] `InjectionEvent` gains `Codable`, `Equatable`, `Hashable`.
- [x] `AppRepository`: holds the in-memory `AppState`, exposes scoped `update{Settings,Injections,StockBatches,AlertSettings}` mutators that mutate-then-save, so multiple ViewModels can share one repository without clobbering each other's slice.
- [x] `FactorTrackerViewModel` gets a new `init(repository:)` that loads `model`/`injections` from the repository and persists through it on every mutation (`addInjection`, `resetAll`, `calibrateRecovery`, `calibrateRecoveryParameter`); the existing `init(weightKg:baselinePercent:halfLifeHours:)` is unchanged, for previews/tests that don't need persistence.
- [x] `HEMOnitorApp` constructs one `AppRepository` (backed by `FileManagerPersistenceStore`) and passes a repository-backed `FactorTrackerViewModel` into `ContentView` — `ContentView`'s own init signature is untouched.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior (`calibrateRecovery`/`calibrateRecoveryParameter` still run in the same order, same math — only a persistence call was appended after each).
- Do not refactor the MVVM architecture: `FactorTrackerViewModel` is still the sole `@Published` source for its views; `AppRepository` is a Model-layer service, not something views bind to directly.
- Keep all user-facing strings and doc comments in Romanian (per CLAUDE.md as of this task — flips to English in phase 009).
- Do not hand-edit `project.pbxproj`.
- Phase 010 (not this one) is responsible for actually removing `ContentView.init`'s hardcoded 65/2/19 defaults — this phase only makes persistence exist and work; `AppSettings.defaultSettings` mirrors those same literals so behavior is identical either way on first launch.

## Acceptance Criteria

- [x] The app builds.
- [x] Unit tests cover: load-with-no-file returns defaults, save-then-load round-trips exactly, a corrupt file falls back to defaults, and `AppRepository` updates are visible to a fresh repository instance reading the same backing store.
- [x] Existing behavior (calculations, calibration ordering, UI) is unchanged — verified by inspection; `ContentView`/`CalibrationView` weren't touched.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **` — `HEMOnitorTests/example()` + 4 new `PersistenceTests` cases)
- Manual check: none beyond build/test.

## Notes

**Real bug caught by the round-trip test, fixed in this task:** `JSONEncoder`'s default `.iso8601` date strategy drops sub-second precision, so any `Date()`-derived timestamp didn't round-trip exactly through save/load — `saveThenLoadRoundTrips` failed on first run for exactly this reason. Switched both encoder/decoder to `.millisecondsSince1970`, which is precise enough for anything this app stores (dose times are logged to the minute via UI, never needs sub-millisecond precision) and simpler than configuring a fractional-seconds ISO8601 formatter.

`AppRepository` was initially written `@MainActor`, which doesn't compile: `FactorTrackerViewModel` (not actor-isolated) can't synchronously touch a `@MainActor`-isolated `state` property from its `init`. Since `AppRepository` doesn't touch UI — it's a small in-memory-state + file-I/O coordinator — the isolation wasn't needed; removed it rather than making the whole call chain async or isolating `FactorTrackerViewModel` too (which would be a bigger, out-of-scope change).

`AppSettings`/`StockBatch`/`AlertSettings` already carry fields (`hasCompletedOnboarding`, `displayStyle`, all of `AlertSettings`, all of `StockBatch`) that no UI reads yet — deliberate, so the schema is settled once rather than evolving across phases 010/013/016 (each addition to a Codable struct without a decode-time default breaks old saved JSON, a risk flagged in the plan).

Files added: `Models/{AppSettings,StockBatch,AlertSettings,AppState}.swift`, `Services/{PersistenceStore,FileManagerPersistenceStore,InMemoryPersistenceStore,AppRepository}.swift`, `HEMOnitorTests/PersistenceTests.swift`. Modified: `Models/InjectionEvent.swift` (conformances only), `ViewModels/FactorTrackerViewModel.swift` (new init + persist calls), `HEMOnitorApp.swift` (constructs repository, passes viewModel to `ContentView`).

Mid-task, the user decided to flip the whole app from Romanian to English (see phase 009, inserted right after this one) — this task's code was still written in Romanian since that was still the active convention when it was built.

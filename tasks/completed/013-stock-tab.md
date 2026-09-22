# Task: Stock tab screen and view model

**Status:** active
**Created:** 2026-09-22
**Completed:** —

## Objective

The Stock tab has a real screen — a hero card summarizing total inventory, one
card per lot, and an "Add a delivery" action — backed by a `StockViewModel`
that owns the `StockBatch` list, sorted by expiry, with safe consumption
bookkeeping.

## Context

Phase 013 of the full-rebuild plan, filling in the Stock tab that 012
(`AppShellView`) currently shows as `ComingSoonView(tab: .stock)`. `StockBatch`
(`HEMOnitor/Models/StockBatch.swift`) and `AppRepository.updateStockBatches`
(`HEMOnitor/Services/AppRepository.swift`) already exist from the persistence
phase, unused until now.

This task was scoped to run in parallel with sibling agents building other
tabs, under strict file ownership: only `HEMOnitor/Views/Stock/**`,
`HEMOnitor/ViewModels/StockViewModel.swift`, and
`HEMOnitorTests/StockViewModelTests.swift` were touched. `StockView` is
deliberately **not** wired into `AppShellView` — see Integration notes below.

## Requirements

- [x] `StockViewModel` (`HEMOnitor/ViewModels/StockViewModel.swift`): `init(repository:)` and an in-memory `init(batches:)`, mirroring `FactorTrackerViewModel`'s two-init pattern.
- [x] `@Published private(set) var batches: [StockBatch]`, kept sorted by `expiryDate` ascending through every mutation.
- [x] Computed `totalIU`, `totalVialCount`, `soonestExpiry`.
- [x] `addBatch(_:)`, `removeBatch(id:)`.
- [x] `consume(vials:fromBatchId:)` rejects (returns `false`) a consumption that would take a batch below zero, rather than clamping.
- [x] `StockView`: hero card (green gradient, total IU, vial count, coverage, soonest expiry), per-lot cards (vial size, product/lot, quantity, expiry badge, lot total IU), dashed-border "+ Add a delivery" button, and an empty state when there's no stock.
- [x] Expiry badge color changes by urgency: expired / expiring within 30 days / normal.
- [x] `StockView` takes a `StockViewModel` and an `onAddDelivery: () -> Void` closure; does not build the add-stock sheet.
- [x] Unit tests for `StockViewModel` logic only: totals, sort order, the reject-below-zero rule, empty-state totals, persistence round-trip.

## Architecture

**`daysOfCoverage` needed a consumption rate the view model doesn't otherwise have.** The design mock's hero card has a "Covers / N days" row, but nothing in scope for this task (`StockBatch`, `AppRepository`) carries a usage rate, and `StockView` is explicitly not given a `FactorTrackerViewModel` to derive one from injection history. Rather than invent a clinical assumption (e.g. a hardcoded IU/day), `StockViewModel` exposes a settable `averageDailyConsumptionIU: Double?` (default `nil`) and a `daysOfCoverage: Int?` computed from it; the view shows "—" when it's `nil`. This is a small, local, fully-tested addition — recorded here per the Architecture guidance rather than applied silently. Whoever wires the real consumption estimate in a later phase can just set that property.

**Expiry urgency lives in the view layer, not on `StockBatch`.** `StockExpiryUrgency` (in `ExpiryBadge.swift`) derives expired/soon/normal from `expiryDate` vs. the current date at render time — it's a presentation concern, and `Models/**` was off-limits for this task anyway. No behavior on `StockBatch` itself changed.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not drift away from MVVM as a side effect.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.
- File ownership: only `HEMOnitor/Views/Stock/**`, `HEMOnitor/ViewModels/StockViewModel.swift`, `HEMOnitorTests/StockViewModelTests.swift`, and this task file. `HEMOnitor/Views/Shell/**`, `HEMOnitor/HEMOnitorApp.swift`, `HEMOnitor/ViewModels/FactorTrackerViewModel.swift`, `HEMOnitor/Models/**` and the other tab directories were not touched.

## Acceptance Criteria

- [x] `StockViewModel`'s totals, sorting, and `consume` reject-below-zero rule are covered by passing unit tests.
- [x] `StockView` renders the hero card, per-lot rows, expiry badges, add-delivery button and empty state, using only design-token colors/fonts/spacing (no hardcoded hex).
- [x] Behavior unrelated to this task is unchanged (Home, shell, calibration, persistence of other state).
- [x] The app builds.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **`) — full `HEMOnitorTests` bundle, including the 15 new `StockViewModelTests` alongside the pre-existing persistence/settings/injection-chain suites.
- Manual check: not performed — this environment can't drive simulator taps/scrolls (same limitation noted in prior phases). `StockView` has two `#Preview`s ("With stock" and "Empty") covering both states; `StockHeroCard`, `StockLotRow` and `ExpiryBadge` each have their own preview too.

## Notes

**`StockView` is not wired into `AppShellView`.** Per the task's file-ownership rules, `HEMOnitor/Views/Shell/AppShellView.swift` was left untouched. See Integration notes below for the one-line change needed to swap it in for `ComingSoonView(tab: .stock)`.

**Old vs. new card styles.** The existing Home cards (`CurrentLevelCard`, `LastInjectionCard`, etc.) still use the pre-redesign `CardView` wrapper and system colors — they haven't been migrated to the design tokens yet (that's presumably a separate phase). `StockView` and its subviews were built entirely from `AppColor`/`Theme`/`AppTextStyle`/`Font.plexMono`/`.glassCard(...)`, matching the design spec for this task rather than the older Home style.

**Expiry badge date format.** Used `.dateTime.day().month(.abbreviated).year(.twoDigits)` (e.g. "12 Oct 27") to keep the pill compact; the hero card's "Soonest expiry" uses a fuller `.dateTime.day().month(.abbreviated).year()` since it has more room.

**Vial/day pluralization** ("1 vial" vs "N vials", "1 day" vs "N days") is handled inline rather than via `String(localized:)`/`AutomaticStringInterpolation` pluralization rules, consistent with how the rest of the codebase (e.g. `HomeView`'s duration formatting) does simple conditional pluralization rather than a full Stringsdict/String Catalog setup.

### Integration notes (for whoever wires this tab in)

1. In `AppShellView.content`, replace the `.stock` case:
   ```swift
   case .stock:
       StockView(viewModel: stockViewModel, onAddDelivery: { /* present add-stock sheet */ })
   ```
   (currently falls through to `ComingSoonView(tab: selectedTab)` alongside `.alerts, .you`).
2. `AppShellView` (or `HEMOnitorApp`) needs to own a `StockViewModel(repository: repository)` alongside the existing `FactorTrackerViewModel`, using the same shared `AppRepository` instance so both view models persist into the same `AppState`.
3. `onAddDelivery` is unimplemented by design (the add-stock sheet is a later phase) — wire it to whatever sheet-presentation state that phase introduces.
4. `StockViewModel.averageDailyConsumptionIU` is `nil` by default (hero card shows "Covers —"). If/when a real consumption estimate becomes available (e.g. derived from `FactorTrackerViewModel`'s injection history), set it after construction; no other wiring is required for `daysOfCoverage` to start reporting real numbers.

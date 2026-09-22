# Task: Rebuild Home with the design mock's level visualization, cover window and activity cards

**Status:** active
**Created:** 2026-09-22
**Completed:** —

## Objective

`HomeView` matches the design mock's Home screen: a custom header (no
`NavigationStack`/`navigationTitle`, so the shell's gradient shows through), a
user-selectable level visualization (ring/numeral/curve), a zone badge, a
cover-window projection card with a forward look-ahead slider, a conditional
no-stock prompt, two stat tiles, and a scrolling recent-activity list —
replacing the old plain cards and the view-local time-simulation buttons.

## Context

Phase 014 of the full-rebuild plan
(`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`), which depends on
006 (design tokens), 010 (settings plumbing) and 012 (nav shell, which moved
`ContentView` to `Views/Home/HomeView.swift` and switched it to
`@ObservedObject`). This phase only restyles/reshapes Home's content — the
view model (`FactorTrackerViewModel`), the PK model (`FactorVIIIModel`) and
the real/display level split (CLAUDE.md) are unchanged.

Built as a fresh `HomeView` plus new subviews under `Views/Home/Cards/`
(matching the plan's own listed file layout for this phase), on top of the
design tokens from `DesignSystem/{Colors,Theme,Typography,Modifiers}.swift`
and `Views/SafetyZone.swift` (read, not modified — its zone/color/label API
was enough).

Ran in an isolated worktree alongside three sibling agents building other
tabs in parallel; touched only `Views/Home/**`, `Views/CalibrationView.swift`
(visual-only) and `Views/Cards/**` (deletions), per the file-discipline rules
in the task brief.

## Requirements

- [x] Custom header: uppercase kicker greeting + ~23pt extraBold title + a
      tappable glass capsule chip showing calibration status. No
      `NavigationStack`/`navigationTitle`.
- [x] Level visualization with three styles driven by `viewModel.displayStyle`
      (`.ring` / `.numeral` / `.curve`), all display-space only, with a
      compact style switcher that writes back to `viewModel.displayStyle`
      (persisted automatically by the view model's existing `didSet`).
  - [x] `.ring`: 250×250 ring, 14pt stroke, starts at top, animated, integer
        percent (~82pt extraBold) + caption centered inside.
  - [x] `.numeral`: ~132pt extraBold number + caption.
  - [x] `.curve`: ~84pt number + a hand-rolled decay chart (dashed lines at
        40%/15%, filled area, "now" marker, "now"/"+2 days"/"+4 days" axis
        captions).
- [x] Zone badge capsule (dot + zone label in zone color + short note) below
      the visualization.
- [x] Cover-window glass card: header row ("Cover window" / "{halfLife}h
      half-life" in `Font.plexMono`), a headline projecting when the level
      crosses a fixed reference threshold with a relative-time mono caption,
      and a "Look ahead" 0...72h slider with mono tick labels and a
      "Previewing {date}" line when non-zero.
- [x] No-stock prompt card, shown only when `hasStock == false`, calling
      `onAddDelivery`.
- [x] Two stat tiles: "Last dose" (IU + relative time) and "Days of cover"
      (from `coverDaysText`, placeholder when nil).
- [x] Recent-activity glass card: 36×36 rounded-square mono badge + title +
      subtitle + right-aligned mono value per row, most-recent-first, capped
      height with internal scrolling.
- [x] Footnote disclaimer (estimates only, zones informational, not medical
      advice).
- [x] New `HomeView` parameters `hasStock: Bool = false`,
      `coverDaysText: String? = nil`, `onAddDelivery: () -> Void = {}`, no
      `AppRepository` access from Home.
- [x] Calibration sheet presentation and the reset-with-confirmation action
      preserved, restyled.
- [x] Old `Views/Cards/*` superseded cards removed.

## Architecture

No structural deviation from the existing pattern (small SwiftUI subviews fed
plain values/bindings by a parent that owns the `@ObservedObject`). Two small,
local decisions worth recording:

**A pure `DecayCurve.sample(...)` helper** (`Views/Home/Cards/DecayCurve.swift`)
factors the curve-style chart's sampling out of the view so it's independently
testable — it takes a `FactorVIIIModel` and the current real percent and
returns `[DecayCurvePoint]` (hours-from-now, display percent), with no SwiftUI
dependency. No test was added for it in this phase: the task's strict
file-discipline list (to avoid clobbering three sibling agents editing other
tabs concurrently in the same worktree family) scoped this agent to
`Views/Home/**`, `Views/CalibrationView.swift` and `Views/Cards/**` only —
`HEMOnitorTests/**` wasn't in that list. The function is a pure,
dependency-free candidate for a follow-up unit test (assert monotonic decay
toward baseline, and that display values track a known `calibrationFactor`).

**The cover-window headline's threshold is a fixed 5% (display), not
user-entered.** The old `NextDoseCard` took a free-text threshold; the design
mock's cover-window card has no such field, only the look-ahead slider (which
is a duration, not a threshold). 5% was picked as the "moderate"/"severe"
`SafetyZone` boundary — a reasonable default "losing meaningful coverage"
marker. This is a product/copy decision, not a PK change: it reuses
`FactorVIIIModel.hoursUntilLevelReaches` exactly as `NextDoseCard` did, just
with a constant instead of a text field. Flagged here since it's a visible
behavior change (no user-configurable threshold) versus before.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level
  split. (Followed: `LevelVisualization`, `DecayCurve`, `CoverWindowCard` and
  `RecentActivityCard` all take already-real values and convert exactly once,
  at render time, via `model.displayLevel(fromRealPercent:)` /
  `model.realPercent(fromDisplayPercent:)`.)
- Do not change calibration behavior (`calibrateRecovery`,
  `calibrateRecoveryParameter`, or their ordering). (Followed: `CalibrationView`'s
  action closure — dose/observed parsing, the A-then-B call order, the
  `dismiss()` — is untouched; only `Form`/button/background chrome changed.)
- Do not drift away from MVVM as a side effect. (Followed — no new state
  ownership, `HomeView` still just observes `FactorTrackerViewModel`.)
- Keep all user-facing strings and doc comments in English. (Followed.)
- Do not hand-edit `project.pbxproj`. (Followed — the target directories are
  synchronized groups; new files were picked up automatically.)
- Keep the change minimal and scoped to this task. (Followed — no changes to
  `FactorTrackerViewModel`, `FactorVIIIModel`, `AppSettings`, `SafetyZone`, or
  the shell.)
- File discipline (project-specific for this phase, not from `CLAUDE.md`):
  only `Views/Home/**`, `Views/CalibrationView.swift` (visual only) and
  `Views/Cards/**` (deletions) were touched — no edits to `Views/Shell/**`,
  `HEMOnitorApp.swift`, `ViewModels/**`, `Models/**`, `Views/Stock|You|Onboarding/**`,
  `DesignSystem/**`, `CLAUDE.md`, the task template, or any existing test file.

## Acceptance Criteria

- [x] The app builds.
- [x] Existing tests still pass.
- [x] Home shows no `navigationTitle`/nav bar; the shell's background gradient
      is visible above the content.
- [x] Switching visualization style persists (via `viewModel.displayStyle`'s
      existing `didSet`) and survives a relaunch through `AppRepository`.
- [x] The no-stock prompt shows/hides purely from the `hasStock` parameter,
      with no `AppRepository` reference in `Views/Home/**`.
- [x] Calibration sheet and reset-with-confirmation behave exactly as before,
      just restyled.
- [x] Behavior unrelated to this task (injection chain logic, calibration
      math, persistence) is unchanged.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`).
- Tests: PASS (`** TEST SUCCEEDED **`) — full existing `HEMOnitorTests`
  bundle (persistence, patient settings, injection chain), unchanged. No new
  tests: this phase is view-layer plus one pure helper (`DecayCurve.sample`)
  that fell outside this agent's file-scope allowlist (see Architecture); the
  chain/calibration math it feeds off already has coverage and was not
  touched.
- Manual check: none — this sandbox can't drive taps/scrolls in the simulator
  (same limitation recorded in tasks 003 and 012), so the layout was verified
  by code review against the design spec rather than a screenshot.

## Notes

**`Views/CardView.swift` is now dead code.** It backed the four deleted
`Views/Cards/*` views (`CurrentLevelCard`, `NextDoseCard`, `LastInjectionCard`,
`QuickActionsCard`) and has no remaining callers. It wasn't in this task's
allowed edit scope (`Views/Home/**` / `Views/CalibrationView.swift` /
`Views/Cards/**` — `CardView.swift` sits directly under `Views/`, not under
`Views/Cards/`), so it's left in place; a follow-up cleanup phase should
delete it.

**No settings-driven "look ahead" state persists.** `lookAheadHours` is
view-local `@State` (matching the old `simulatedOffsetHours` pattern it
replaces) and resets to 0 on `resetAll()`, on tab dismiss, and on each fresh
`HomeView` instantiation. Not persisted by design — it's a transient preview
control, not a setting.

**"View full history" no longer opens a separate sheet.** The old
`QuickActionsCard` had a "View full history" button opening a modal list. The
new `RecentActivityCard` shows every injection (most-recent-first) inside an
internally-scrolling, height-capped glass card, so the same information is
always on-screen — no separate sheet was added. If a full dedicated Timeline
view is wanted, that's phase 018 in the rebuild plan, not this one.

**Dose-entry text field removed from Home.** The old `QuickActionsCard`'s
inline "Doză (UI)"/dose text field and `addInjectionFromInput()` are gone —
the design mock's Home has no dose-entry field; logging happens through the
shell's floating "+" button (already wired to a placeholder sheet in
`AppShellView`/task 012, filled in by task 015's sheet system). `HomeView` no
longer calls `viewModel.addInjection` at all.

Files added: `Views/Home/Cards/{DecayCurve,DecayCurveChart,LevelVisualization,
ZoneBadge,CoverWindowCard,NoStockPromptCard,StatTile,RecentActivityCard,
HomeHeaderView}.swift`.
Files rewritten: `Views/Home/HomeView.swift`.
Files restyled (visual only, logic/ordering untouched):
`Views/CalibrationView.swift`.
Files deleted: `Views/Cards/{CurrentLevelCard,NextDoseCard,LastInjectionCard,
QuickActionsCard}.swift`.

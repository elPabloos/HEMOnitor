# Task: Tab shell with floating log button

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

The app root is a four-tab shell (Home / Stock / Alerts / You) styled as the design's glass pill bar, with a separate floating "+" button that opens the log sheet without changing the selected tab. The existing single screen becomes the Home tab.

## Context

Phase 012 of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`), depends on 006 (design tokens) and 010 (settings plumbing).

Until now the app root was a single `ContentView`. The design replaces it with a tab shell. This phase is the gate for most remaining work: 013 (Stock), 014 (Home rebuild), 017 (You) and 016 (Alerts) all fill in tabs this shell defines.

The three unbuilt tabs show a `ComingSoonView` placeholder, so the shell is complete and navigable now and each later phase swaps one case in `AppShellView.content`.

## Requirements

- [x] `AppTab` enum (home/stock/alerts/you) with titles and VoiceOver labels.
- [x] `CustomTabBar` — glass pill bar matching the design, selected item tinted.
- [x] `FloatingLogButton` — circular "+" beside the bar, not a tab item.
- [x] `AppShellView` — owns tab selection and log-sheet presentation, switches content.
- [x] `ContentView` renamed to `HomeView` and moved to `Views/Home/`.
- [x] `HEMOnitorApp` roots at `AppShellView`.
- [x] Accessibility: per-item labels, `.isSelected` trait, hit targets ≥44pt.
- [x] Scrolling content clears the floating bar.

## Architecture

Two ownership decisions, both small and local, applied and recorded here per the
Architecture rules in CLAUDE.md:

**Navigation state is plain `@State` on `AppShellView`, not a router object.** With four
destinations and one sheet, an observable router would add a layer of indirection and a
second source of truth without buying testability or decoupling. Screens that need to
steer navigation will be handed a closure — `HomeView`'s "no stock" prompt jumping to the
Stock tab in 014 — which is the pattern the existing card views already use
(`QuickActionsCard` takes `onAddInjection`/`onCalibrate`/`onViewHistory`). Revisit only if
deep linking or restorable navigation state is ever needed.

**`HomeView` switched from `@StateObject` to `@ObservedObject`.** It previously owned its
view model via `@StateObject` with a default-constructed fallback, which made sense when it
was the app root. Now `HEMOnitorApp` owns the view model and passes it down through the
shell, so `HomeView` must observe rather than own — `@StateObject` on a passed-in object
takes ownership on first init and would ignore a later substitution. The default argument
was removed along with it, so there is no longer a path that silently creates a second,
unpersisted view model.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not drift away from MVVM as a side effect.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.
- Do not restyle Home's contents — that is phase 014. This phase only relocates it into the shell.

## Acceptance Criteria

- [x] The app builds and launches.
- [x] All four tabs are reachable; Home shows the existing screen, the others show a placeholder.
- [x] The "+" button opens a sheet and leaves the selected tab unchanged.
- [x] Existing Home behavior (levels, calibration, history, reset) is unchanged.
- [x] Existing tests still pass.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (32 existing, unchanged). **No new tests** — this phase is pure view layer: an enum of titles, two stateless subviews, and a `switch`. There is no logic here that a unit test could fail on that the build wouldn't already catch, and SwiftUI layout/selection isn't reachable from the unit-test bundle. Tab switching and sheet presentation would need UI tests, which are out of scope for this phase.
- Manual check: installed and launched on the iPhone 17 Pro simulator (iOS 26.5); screenshot confirms the glass pill bar, the four labelled tabs with Home selected and tinted, and the floating green "+" rendering as designed.

## Notes

**The mock's tab bar uses a dot and a label, not icons.** Implemented as designed. When
the icon question was raised during planning the answer was "SF Symbols", but that was
about *sourcing* icons where the design needs them — the tab bar turns out not to need
any. SF Symbols are used elsewhere (the toast banner, the floating "+"). Flagging it in
case icons in the bar are actually wanted; it would be a small change.

**`NavigationView` → `NavigationStack`** in `HomeView` and `CalibrationView`. The old
`NavigationView` is deprecated and, being UIKit-backed, manages its own safe area in a way
that does not reliably accept an inset applied from outside. Since the shell relies on
`safeAreaInset` to keep scrolled content clear of the floating bar, the modern container is
the correct one. No behavior change beyond that.

**Bottom clearance is by construction, not by observation.** `AppShellView` applies
`.safeAreaInset(edge: .bottom)` with the bar's height to its content, so the bar floats
over scrolled content (preserving the design's translucency) while the scroll view still
insets its own content. This could not be confirmed by scrolling to the bottom in the
simulator — this environment can't drive taps or scrolls (same limitation recorded in task
003) — so it is verified by mechanism rather than by eye.

**Home looks transitional.** It still carries its own `navigationTitle` and opaque
background, so it covers the shell's gradient and shows a large "Factor Tracker" title
above the cards. That is expected: phase 014 replaces Home's chrome with the design's
custom header, at which point the gradient shows through.

Files added: `Views/Shell/{AppTab,CustomTabBar,FloatingLogButton,AppShellView,ComingSoonView}.swift`.
Moved: `Views/ContentView.swift` → `Views/Home/HomeView.swift` (renamed type).
Modified: `HEMOnitorApp.swift`, `Views/CalibrationView.swift` (navigation container only).

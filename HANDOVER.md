# HEMOnitor — session handover (2026-09-23 → 2026-09-24)

Paste this into the next session.

## Where the project stands

The 14-phase redesign (plan: `~/.claude/plans/woolly-stargazing-lynx.md`) is **complete**.
Phases 006–020 all landed, plus four follow-up bug/task items. `tasks/active/` is empty.
`main` is pushed to `github.com/elPabloos/HEMOnitor`.

Current build: **`Version 1.0 (6) · 024-timeline-chart-scrolling`**, shown at the foot of
the You screen.

## Read these first (they hold the real context)

- `CLAUDE.md` — architecture, build/test commands, and three policies added this session
  (see below). It is accurate as of now; stale sections were corrected.
- `tasks/completed/018-timeline.md`, `020-polish-qa.md`, `022`, `023`, `024` — these carry
  the *reasoning*, including approaches that were tried and reversed. 024 in particular
  documents four passes over the same screen.

## Policies established this session — follow these

1. **Never merge to `main` or push without explicit approval.** Committing on a
   task/bug branch unprompted is fine. Approval does not carry from one task to the
   next. (Also in memory: `feedback_task_workflow.md`.)
2. **Never write tests that simulate touch** — tap, drag, swipe, scroll, pinch. The agent
   cannot perform them and a simulated one is worse than the user's thumb. Test pure
   logic, view-model state, persistence, parsing, formatting. Appearance is checked with
   a screenshot or `RenderPreview`. See "Never write tests for physical interaction" in
   CLAUDE.md.
3. **Report tests honestly.** A test of a formula verifies the formula, never the
   feature. This session had a fully-passing test suite over a scroll coupling that did
   nothing at all on screen.
4. **Versioning:** every task merged to `main` bumps `CURRENT_PROJECT_VERSION` (via the
   Xcode MCP `UpdateTargetBuildSetting`, never by hand-editing `project.pbxproj`) and
   updates `AppVersion.latestTask`.

## Hard-won environment facts

- **Do not name a simulator model or OS version.** CLAUDE.md's old `iPhone 17 Pro` /
  iOS 26.5 pin was dead; the test command now resolves a UDID at run time. The failure
  looks like a project fault and isn't.
- **There is no working drag/swipe/scroll command** in the device-interaction tooling.
  `t <x> <y>` taps; every spelling of a drag is rejected. Two sessions burned tokens
  rediscovering this. Consequence: sliders and scroll views cannot be agent-verified.
- **Xcode's device list differs from `simctl`'s** — `DeviceInteractionStartSession` only
  offers iOS 27.0 devices. Pick from the list it returns on failure, then
  `simctl install`/`launch` onto that same UUID.
- `RenderPreview` is the cheap way to check appearance, including Dynamic Type variants
  (`previewVariantOverrides: {"Dynamic Type": "AX 5"}`) and specific `#Preview` indexes.
- Seeding state: write `Library/Application Support/app_state.json` in the app's data
  container. **Every non-optional key must be present** — Swift's synthesised decoder
  ignores property defaults, so `"alertSettings": {}` silently fails the whole load and
  falls back to defaults (this cost real time).

## The design mock

Claude Design project `05f89777-4f32-4616-8ea0-646bd9b4700b`, file
`HEMOnitor App.dc.html`, reachable via the `claude-design` MCP tools. It is the source of
truth for the Timeline screen's geometry and for the scroll coupling
(`timelineVals()` / `onTlListScroll`). Unchanged as of 2026-09-24.

## Outstanding — nothing is blocked, but these are unverified

The agent cannot perform gestures, so these need the user on a device:

1. **Timeline chart** — hand-drag works? List scroll pans it? Does it feel smooth or
   stepped (anchor spacing is 8pt — that's the knob)? Overscroll at both ends should
   show empty gridded chart, not white.
2. **Home look-ahead slider** — dragging should move the big number with no lag
   (animation is now dropped for the duration of a drag).
3. **Dynamic Type** — phase 020's work was verified via rendered previews, not on device.
   The user has said this is low priority.

## Open questions the user may want to revisit

- The "today" outline ring on the Timeline day strip when today isn't the centred day —
  an addition beyond the reference video, easily dropped.
- `TimelineCurve.projectedFutureDays` — the user questioned whether it was needed and
  **decided to keep it**. It only chooses the projection window length; a fixed +14 days
  would also work.

## Architecture notes most likely to bite

- **Real vs display levels**: all maths in real space, `displayLevel(fromRealPercent:)`
  only at render. Never invert this.
- **The injection chain**: `recomputeChain(fromIndex:)` is private; edits go through
  `addInjection`/`updateInjection`/`deleteInjection`, which splice and recompute. Any
  new field on `InjectionEvent` must be carried through all three plus the chain rebuild,
  or it is silently dropped on edit.
- **`Text("\(Int(x)) IU")` is a trap** — it is a `LocalizedStringKey`, so the integer is
  locale-formatted and 3000 IU renders as "3.000 IU". Use `wholeNumberText`.
- **`ForEach(0..<n, id: \.self)` inside a `ScrollView`** publishes Int-identified scroll
  targets that collide with any other Int ids — this caused a real bug in 024.

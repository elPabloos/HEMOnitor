# Task: Polish & QA pass

**Status:** complete
**Created:** 2026-09-23
**Completed:** 2026-09-23

## Objective

The app holds together at accessibility text sizes and on iPad, meets the 44pt hit
target minimum throughout, and renders doses unambiguously in every locale.

## Context

Final phase of the redesign plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`),
after 018 landed. Cross-cutting rather than feature work: the plan's brief is an
accessibility pass on the hand-rolled chrome, a Dynamic Type check, an iPad layout, and
a full regression run.

The custom tab bar was already in good shape from 012 (explicit labels, `.isSelected`
traits, 54pt targets), so this phase's findings were mostly elsewhere.

## Findings and fixes

**1. Dose amounts were rendered with locale grouping — the most serious one.**
`Text("\(Int(dose)) IU")` reads as harmless string interpolation, but the literal is a
`LocalizedStringKey`, so SwiftUI formats the integer through the current locale. On a
device grouping with ".", **a 3000 IU dose rendered as "3.000 IU"** — three. Caught on
an iPad screenshot where "Last dose 3000 IU" (mono, hand-formatted) sat directly above
"Recent activity 3.000 IU" for the same dose.

13 call sites across Home, Stock, Alerts, Onboarding, Timeline and the sheets. Fixed by
adding `Double.wholeNumberText`/`Int.wholeNumberText`
(`HEMOnitor/DesignSystem/NumberFormatting.swift`), which format explicitly with
`.grouping(.never)` *and* return a `String` — a `String` interpolated into a
`LocalizedStringKey` is left alone. The doc comment names the trap so it isn't
reintroduced; `NumberFormattingTests` asserts no grouping separator ever appears.

**2. Home broke badly at accessibility text sizes.** At AX5 the title wrapped mid-word
("Fact / or / Track / er"), the calibration chip truncated to "No…", the numeral burst
out of the 250pt ring, the caption truncated and the style switcher was overlapped.

- `HomeHeaderView` stacks the title and chip vertically at accessibility sizes instead
  of fighting for one row; the chip's fixed 40pt height became a minimum.
- `LevelVisualization` caps Dynamic Type at `.xxxLarge` inside the ring and the large
  numeral — both are fixed-geometry display elements that cannot scale without bound —
  plus `minimumScaleFactor`/`lineLimit`. VoiceOver is unaffected: the combined
  accessibility label doesn't go through the visual cap.
- `ZoneBadge` stacks its note under the label at accessibility sizes rather than
  overflowing its capsule and hyphenating ("Low protecti / ve").
- `CustomTabBar` caps at `.xxLarge` — a fixed-height pill with four labels side by side
  cannot absorb the accessibility steps, and each item's accessibility label carries the
  text for VoiceOver at any size.

**3. Hit target below the minimum.** The level-style switcher buttons were 40×32pt. The
visual pill stays 40×32 for the design; the tappable area is now padded to 44×44 via
`.frame(minWidth:minHeight:)` + `.contentShape`.

**4. No iPad handling at all.** Content stretched edge to edge on a 13" display, turning
label/value rows into metre-long pairs. Added `.readableWidth()`
(`HEMOnitor/DesignSystem/ReadableWidth.swift`), which caps content at 480pt and centres
it on regular width, and applied it to the shell content, the floating bar, onboarding
and the full-screen Timeline. It is a no-op on compact width, so no iPhone layout
changes.

## Checked and found correct (no change)

- **Content behind the floating tab bar.** An iPad screenshot appeared to show the
  disclaimer trapped under the bar. Measured from the UI hierarchy instead: disclaimer
  ends at y=1271, bar begins at y=1284 — a 13pt gap. The bar floating over *scrolled*
  content is deliberate (see `AppShellView`), and `barClearance` does its job.
- **"Days of cover: 0 days" with no stock on record.** Accurate rather than wrong: no
  stock is zero days of cover. `daysOfCoverage` returns nil only when no consumption
  rate is known, which is a different state.
- **You screen at AX3** — rows wrap gracefully, values stay right-aligned, the
  segmented control stays legible. No fix needed.
- **Wheel date/time picker** — native `DatePicker(.wheel)`, so VoiceOver support and
  target sizes come from the system.

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Keep all user-facing strings and doc comments in English.
- Do not hand-edit `project.pbxproj`.

## Acceptance Criteria

- [x] Home is legible and uncollided at AX5.
- [x] Doses never render with a locale grouping separator.
- [x] All interactive controls meet 44pt.
- [x] iPad content is constrained and centred; iPhone layout unchanged.
- [x] Build and the full unit suite pass.

## Verification

- Build: `** BUILD SUCCEEDED **` (iPhone and iPad destinations).
- Tests: `** TEST SUCCEEDED **`, full suite, with 6 new `NumberFormattingTests`.
- Screenshots: Home at AX5 before/after; iPad Pro 13" before/after; You at AX3.
- Interactive check: **left to the user.** Worth trying with a large text size set in
  Settings, and on a real iPad if you have one. Note the agent still cannot drag, so
  the look-ahead slider remains unverified by gesture.

## Notes

- The Dynamic Type caps are deliberate and narrow: they apply only to fixed-geometry
  chrome (the ring, the large numeral, the tab pill). Body content everywhere else
  scales freely to AX5.
- 480pt for `readableWidth` is a judgement call — wide enough that nothing re-wraps
  relative to the phone layout, narrow enough that rows stay scannable. A real
  split-view iPad layout would be a redesign, not a polish pass, and is out of scope.
- An early note in this session claimed the custom fonts ignored Dynamic Type entirely.
  That was wrong — `Font.custom(_:size:)` scales relative to body by default. The fonts
  scale; the layouts were what broke.

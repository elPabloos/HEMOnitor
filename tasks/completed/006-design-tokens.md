# Task: Design tokens — palette, typography, spacing, glass modifiers

**Status:** completed
**Created:** 2026-09-22
**Completed:** 2026-09-22

## Objective

The app has a reusable design-system layer (colors, fonts, spacing/radius/shadow constants, glass-card and pill-button styling) matching the new design mock, ready for later phases to build screens against. No existing screen's business logic changes.

## Context

Part of the full-rebuild plan (`/Users/pciudin/.claude/plans/woolly-stargazing-lynx.md`) translating a claude.ai/design mock ("Mobile app design project") into HEMOnitor. This is phase 006 of 14 (006–019), the foundation every later phase depends on.

The mock uses Plus Jakarta Sans (UI/body) + IBM Plex Mono (numerics), a light-only palette (bg gradient `#eaf1e7→#dceade→#cfe2d9`, ink `#16231b`, primary green `#2f5c3f`/accent `#4c8058`, four zone colors), pill radii (99px), 20-24px card radii, glass-translucent cards. Per user decision: bundle the real fonts (not system-font substitutes), and add a dark palette (today's app gets dark mode for free via Material; the mock doesn't, so a dark counterpart was designed here — derived for contrast, not pulled from the mock).

Relevant existing code: `HEMOnitor/Views/SafetyZone.swift` (5-case zone enum, `.color`/`.label`), `HEMOnitor/Views/CardView.swift` (current Material-based card, untouched by this task — home-rebuild phase 013 adopts the new `.glassCard()`).

## Requirements

- [x] Light + dark color tokens (`AppColor` enum) covering background gradient, ink/text, brand greens, 5 zone colors (added a `critical` shade beyond the mock's 4, to keep `SafetyZone`'s existing 5 tiers distinct), glass-card fill/border, warning/danger states.
- [x] Spacing/radius/shadow constants (`Theme` enum) matching the mock's values.
- [x] `.glassCard()` and `PrimaryPillButtonStyle`/`SecondaryPillButtonStyle` view modifiers.
- [x] Bundle Plus Jakarta Sans (variable font, named instances Regular/Medium/SemiBold/Bold/ExtraBold) + IBM Plex Mono (Regular/Medium) as app resources, with a `FontRegistrar` that registers them at runtime via `CTFontManagerRegisterFontsForURL` — avoids needing an Info.plist `UIAppFonts` array entry, which this project's generated-Info.plist build setup can't express without a `project.pbxproj` change.
- [x] `Font.jakarta(_:weight:)` / `Font.plexMono(_:weight:)` helpers with a safe fallback to the system font if a custom font isn't registered (e.g. in previews/tests).
- [x] Re-map `SafetyZone.color` onto the new zone tokens (visual only — thresholds/labels/logic unchanged).

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split.
- Do not change calibration behavior.
- Do not refactor the MVVM architecture.
- Keep all user-facing strings and doc comments in Romanian.
- Do not hand-edit `project.pbxproj`.
- Do not adopt the new design system into `ContentView`/existing cards yet — that's phase 011/013. This phase only adds the design-system layer and recolors `SafetyZone`, which is a pure color swap already covered by the existing card/enum contract.

## Acceptance Criteria

- [x] The app builds.
- [x] Font files are present in the built app bundle (verified: `IBMPlexMono-Medium.ttf`, `IBMPlexMono-Regular.ttf`, `PlusJakartaSans[wght].ttf` under `HEMOnitor.app/`).
- [x] Existing behavior (calculations, calibration, card layout/colors via `SafetyZone`) is otherwise unchanged — `SafetyZone` still has the same 5 cases/thresholds/labels, only `.color` values changed.

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test -only-testing:HEMOnitorTests
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **`, `HEMOnitorTests/example()` — this run also exercises `HEMOnitorApp.init()` → `FontRegistrar.registerBundledFontsIfNeeded()` since the test bundle hosts the real app process; no crash/assertion, confirming font registration succeeds at runtime)
- Manual check: confirmed via `find` that the three `.ttf` files are copied into the built `.app` bundle (fileSystemSynchronizedGroups auto-includes non-Swift resources, so no pbxproj edit was needed for bundling — only the runtime-registration approach was needed to avoid the Info.plist array-key limitation)

## Notes

Font source: Plus Jakarta Sans and IBM Plex Mono, both OFL-licensed, pulled from `google/fonts` (`ofl/plusjakartasans/PlusJakartaSans[wght].ttf`, `ofl/ibmplexmono/IBMPlexMono-{Regular,Medium}.ttf`), with their `OFL.txt` license files kept alongside in `HEMOnitor/Resources/Fonts/`. Plus Jakarta Sans ships only as a variable font upstream (no static per-weight files in the OFL repo) — its named instances were inspected directly via CoreText (`CTFontManagerCreateFontDescriptorsFromURL`) to get the real PostScript names (`PlusJakartaSans-Regular`, `_Medium`, `_SemiBold`, `_Bold`, `_ExtraBold`), since Google's naming convention for named instances isn't guessable from the family name alone.

`SafetyZone` has 5 tiers (critical/severe/moderate/safe/high) but the mock only defines 4 zone colors (low/partial/well-covered/above-normal). Added a `zoneCritical` (a darker red) beyond the mock so `critical` and `severe` stay visually distinct, since removing a tier wasn't part of this task's scope.

Dark palette is a judgment call (brightened/desaturated variants of the light hues for contrast on a dark background), not part of the source mock — flagged in the plan as a deliberate addition per user request, revisit if the look needs tuning once real screens use it.

Out of scope for this task (later phases): adopting `.glassCard()`/pill styles into `ContentView` or the card views, SF Symbols icon set, dark-mode visual QA on a real screen.

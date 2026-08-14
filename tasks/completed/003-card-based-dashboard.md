# Task: Redesign main screen with card-based dashboard layout

**Status:** completed
**Created:** 2026-08-14
**Completed:** 2026-08-14

## Objective

The main screen presents critical health information in a clear, scannable card-based layout with visual hierarchy, color-coded safety indicators, and logical grouping of related functions, making it faster for users to assess their current status and take action.

## Context

`ContentView` currently uses a simple vertical layout with controls and information mixed together. The current level is displayed prominently, but there's no visual distinction between simulation controls, real data, quick actions, and historical information. Users must scan through the entire screen to find what they need.

Modern health apps (Apple Health, fitness trackers, medical monitoring apps) use card-based layouts to separate concerns and create visual hierarchy. This pattern makes critical information immediately scannable.

Relevant code:
- `HEMOnitor/Views/ContentView.swift` — the main interface that needs restructuring
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — provides data for the cards

## Requirements

- [x] Create reusable `CardView` component for consistent styling
- [x] Design "Current Level" card showing:
  - Large, prominent Factor VIII level percentage
  - Color-coded background based on safety zone (red/orange/yellow/green/blue)
  - Timestamp of calculation
  - Indicator showing if in simulation mode vs. real data
- [x] Design "Next Dose" card — **reframed as a user-entered threshold projection**, see Notes
- [x] Design "Last Injection" card showing:
  - Dose amount (IU)
  - Time elapsed since injection
  - Before/after levels if available
- [x] Create "Quick Actions" card with:
  - Add Injection button
  - Calibration button
  - View Full History button
- [x] Add clear visual separator/indicator when in simulation mode
- [x] Maintain existing functionality (all buttons and controls work the same)
- [x] Ensure cards are properly spaced and use consistent styling

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split
- Do not change calibration behavior
- Do not refactor the MVVM architecture beyond adding computed properties for card data
- Keep the change scoped to UI layout and presentation
- All existing functionality must remain accessible

## Acceptance Criteria

- [x] Main screen uses card-based layout with visual hierarchy
- [x] Current level is color-coded based on safety zone
- [x] Critical information is visible without scrolling on standard iPhone (full history moved to a sheet)
- [x] Simulation mode has clear visual indicator
- [x] All existing buttons and controls remain functional
- [x] Cards have consistent styling (rounded corners, shadows, spacing)
- [x] Layout adapts to different device sizes (standard SwiftUI layout, no hardcoded sizing)
- [x] VoiceOver can navigate cards logically (`.accessibilityElement(children: .combine)` per card)
- [x] Supports light and dark mode (SwiftUI Material-based backgrounds)
- [x] The app builds
- [x] Existing behavior (calculations, history, calibration) is unchanged

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme HEMOnitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

- Build: PASS (`** BUILD SUCCEEDED **`)
- Tests: PASS (`** TEST SUCCEEDED **`, existing HEMOnitorTests/HEMOnitorUITests bundles — no PK-math coverage yet, unchanged from before this task)
- Manual check: Installed and launched on iPhone 17 Pro simulator (18.5/26.5 runtime), screenshot confirmed all 5 sections render correctly (simulation controls, Current Level card color-coded orange/"Sever" at 2%, Proiecție prag, Ultima injecție empty state, Acțiuni rapide). Full tap-through interaction wasn't possible — `osascript`/System Events lacks Accessibility permission in this environment — so injection-add/calibration/history-sheet flows were verified by code review and the unchanged underlying logic rather than live taps.

## Notes

Design decisions:
- Cards provide visual grouping and make information scannable
- Color-coding uses established medical app patterns (red=danger, green=safe)
- Most important information (current level) is largest and first
- Simulation mode needs clear distinction to prevent confusion with real data

**"Next Dose" card reframed:** the original spec asked for "time until recommended next injection," which conflicts with CLAUDE.md's explicit stance that HEMOnitor "explicitly disclaims dosing decisions." Per user decision during planning, this became a **user-entered threshold projection** ("Proiecție prag"): the patient types a target %, and the card shows a pure math projection of when the current decay curve reaches it — no app-suggested target, no recommendation language. Implemented via two new additive, read-only functions in `FactorVIIIModel`: `realPercent(fromDisplayPercent:)` and `hoursUntilLevelReaches(targetRealPercent:fromRealPercent:)`.

Files added: `HEMOnitor/Views/CardView.swift`, `HEMOnitor/Views/SafetyZone.swift`, `HEMOnitor/Views/Cards/{CurrentLevelCard,NextDoseCard,LastInjectionCard,QuickActionsCard}.swift`. `ContentView.swift` restructured to compose these; `FactorVIIIModel.swift` got the two additive helpers above. No changes to `FactorTrackerViewModel`.

Out of scope for this task:
- Advanced animations or transitions
- Collapsible/expandable cards
- Customizable card order
- Pull-to-refresh

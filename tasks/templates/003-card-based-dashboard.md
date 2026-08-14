# Task: Redesign main screen with card-based dashboard layout

**Status:** active
**Created:** 2026-08-14
**Completed:** —

## Objective

The main screen presents critical health information in a clear, scannable card-based layout with visual hierarchy, color-coded safety indicators, and logical grouping of related functions, making it faster for users to assess their current status and take action.

## Context

`ContentView` currently uses a simple vertical layout with controls and information mixed together. The current level is displayed prominently, but there's no visual distinction between simulation controls, real data, quick actions, and historical information. Users must scan through the entire screen to find what they need.

Modern health apps (Apple Health, fitness trackers, medical monitoring apps) use card-based layouts to separate concerns and create visual hierarchy. This pattern makes critical information immediately scannable.

Relevant code:
- `HEMOnitor/Views/ContentView.swift` — the main interface that needs restructuring
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — provides data for the cards

## Requirements

- [ ] Create reusable `CardView` component for consistent styling
- [ ] Design "Current Level" card showing:
  - Large, prominent Factor VIII level percentage
  - Color-coded background based on safety zone (red/orange/yellow/green/blue)
  - Timestamp of calculation
  - Indicator showing if in simulation mode vs. real data
- [ ] Design "Next Dose" card showing:
  - Time until recommended next injection
  - Estimated level at that time
  - Quick action button to log injection
- [ ] Design "Last Injection" card showing:
  - Dose amount (IU)
  - Time elapsed since injection
  - Before/after levels if available
- [ ] Create "Quick Actions" card with:
  - Add Injection button
  - Calibration button
  - View Full History button
- [ ] Add clear visual separator/indicator when in simulation mode
- [ ] Maintain existing functionality (all buttons and controls work the same)
- [ ] Ensure cards are properly spaced and use consistent styling

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split
- Do not change calibration behavior
- Do not refactor the MVVM architecture beyond adding computed properties for card data
- Keep the change scoped to UI layout and presentation
- All existing functionality must remain accessible

## Acceptance Criteria

- [ ] Main screen uses card-based layout with visual hierarchy
- [ ] Current level is color-coded based on safety zone
- [ ] Critical information is visible without scrolling on standard iPhone
- [ ] Simulation mode has clear visual indicator
- [ ] All existing buttons and controls remain functional
- [ ] Cards have consistent styling (rounded corners, shadows, spacing)
- [ ] Layout adapts to different device sizes
- [ ] VoiceOver can navigate cards logically
- [ ] Supports light and dark mode
- [ ] The app builds
- [ ] Existing behavior (calculations, history, calibration) is unchanged

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
```

- Build: 
- Tests: 
- Manual check: 

## Notes

Design decisions:
- Cards provide visual grouping and make information scannable
- Color-coding uses established medical app patterns (red=danger, green=safe)
- Most important information (current level) is largest and first
- Simulation mode needs clear distinction to prevent confusion with real data

Out of scope for this task:
- Advanced animations or transitions
- Collapsible/expandable cards
- Customizable card order
- Pull-to-refresh

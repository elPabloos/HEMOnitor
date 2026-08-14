# Task: Add Swift Charts for Factor VIII level visualization

**Status:** active
**Created:** 2026-08-14
**Completed:** —

## Objective

Users can see a graphical representation of their Factor VIII levels over time, including historical data, predicted future levels, injection markers, and color-coded safety zones, providing better insight into their treatment patterns.

## Context

Currently, users only see their current estimated level as a percentage and a text-based injection history list. There's no visual representation of how their levels change over time or how injections affect the decay curve. This makes it harder to understand treatment patterns and predict when the next dose is needed.

Swift Charts (available iOS 16+) provides native charting capabilities that can visualize the pharmacokinetic model predictions from `FactorVIIIModel`.

Relevant code:
- `HEMOnitor/Views/ContentView.swift` — where the chart view will be integrated
- `HEMOnitor/Models/FactorVIIIModel.swift` — provides level calculations at any point in time
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — holds injection history and current model state

## Requirements

- [ ] Create a line chart showing predicted Factor VIII level decline over time
- [ ] Display historical levels over a selectable time range (default: 7 days)
- [ ] Mark injection events on the chart with visual indicators (points or vertical lines)
- [ ] Show predicted future levels based on current pharmacokinetic model
- [ ] Add color-coded background zones indicating safety levels:
  - Critical (< 1%) - Red
  - Severe (1-5%) - Orange  
  - Moderate (5-40%) - Yellow
  - Safe (40-100%) - Green
  - High (> 100%) - Blue
- [ ] Support time range selection (24h, 7d, 30d views)
- [ ] Update chart automatically when new injections are added
- [ ] Provide accessibility labels for VoiceOver
- [ ] Support both light and dark mode

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split
- Do not change calibration behavior
- Do not refactor the MVVM architecture
- Keep the change minimal and scoped to chart visualization
- Chart data must use the same `FactorVIIIModel` calculations as the rest of the app

## Acceptance Criteria

- [ ] Chart displays on the main screen showing level trends
- [ ] Injection events are visible as markers on the timeline
- [ ] Safety zones are color-coded and clearly visible
- [ ] Chart updates when user adds a new injection
- [ ] Chart is accessible with VoiceOver
- [ ] Existing functionality (level calculation, injection logging) is unchanged
- [ ] The app builds

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
```

- Build: 
- Tests: 
- Manual check: 

## Notes

Future enhancements could include:
- Interactive chart with tap-to-see-details
- Export chart as image for sharing with healthcare providers
- Comparison view showing multiple weeks overlaid
- Statistical overlays (average level, time in range, etc.)

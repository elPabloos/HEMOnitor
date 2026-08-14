# Task: Create timeline view for injection history

**Status:** active
**Created:** 2026-08-14
**Completed:** —

## Objective

Users can view their injection history as a visual timeline with date groupings, see detailed information about each injection, and delete incorrect entries via swipe gesture, making it easier to track treatment patterns and manage their data.

## Context

`ContentView` currently displays injection history as a simple `ForEach` list showing dose and timestamp. There's no way to delete entries, no visual grouping by date, and no detailed view of individual injections. Users cannot correct mistakes or see the full context of an injection.

The injection history is stored in `FactorTrackerViewModel.injectionHistory` as an array of `InjectionEvent` objects. Each event has `timestamp`, `doseIU`, `levelBeforePercent`, and `levelAfterPercent`.

Relevant code:
- `HEMOnitor/Views/ContentView.swift` — current history display
- `HEMOnitor/Models/InjectionEvent.swift` — the data model
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — manages injection history array

## Requirements

- [ ] Replace simple list with vertical timeline visualization
- [ ] Add visual timeline connecting line between injection events
- [ ] Group injections by date with section headers (Today, Yesterday, This Week, Earlier)
- [ ] Show for each injection:
  - Relative time (e.g., "2 hours ago") and absolute timestamp
  - Dose amount (IU)
  - Before and after levels if available
  - Visual indicator on timeline
- [ ] Implement swipe-to-delete gesture
- [ ] Add confirmation dialog before deletion with injection details
- [ ] Create detail view showing full injection information when tapped
- [ ] Update `FactorTrackerViewModel` to support removing injections
- [ ] Ensure timeline updates immediately when injection is deleted

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split
- Do not change calibration behavior
- Deleting an injection should not recalculate historical predictions (only affects current state going forward)
- Do not refactor the MVVM architecture
- Keep the change scoped to history display and deletion
- Maintain chronological order (oldest to newest or vice versa)

## Acceptance Criteria

- [ ] Injection history displays as a visual timeline
- [ ] Injections are grouped by date with clear section headers
- [ ] User can swipe left on any injection to delete it
- [ ] Confirmation dialog appears before deletion showing injection details
- [ ] After deletion, timeline updates and current level recalculates correctly
- [ ] User can tap an injection to see full details
- [ ] Timeline shows relative times ("2 hours ago") alongside absolute timestamps
- [ ] Empty state shows helpful message when no injections exist
- [ ] VoiceOver provides alternative to swipe gesture
- [ ] The app builds
- [ ] Existing functionality (adding injections, calibration) is unchanged

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
```

- Build: 
- Tests: 
- Manual check: 

## Notes

Design decisions:
- Timeline visual pattern is familiar from messaging and activity apps
- Swipe-to-delete is iOS standard for list management
- Confirmation dialog prevents accidental deletion of medical data
- Grouping by date makes it easier to find specific injections

Implementation considerations:
- Deleting an injection requires recalculating the current state from remaining injections
- `FactorTrackerViewModel` likely needs a `deleteInjection(at:)` method
- Consider whether deletion should rebuild the entire model state or just adjust forward

Out of scope:
- Editing injection details (dose, timestamp)
- Adding notes/photos to injections
- Filtering or searching history
- Export/sharing functionality

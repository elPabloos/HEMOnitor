# Task: Improve injection input with quick-select and presets

**Status:** active
**Created:** 2026-08-14
**Completed:** —

## Objective

Users can log injections faster and more accurately using quick-select dose buttons for common amounts, save frequently-used doses as presets, and benefit from an optimized number entry experience with proper validation and feedback.

## Context

Currently, users must type their dose into a text field every time. This works but is slower than necessary for users who regularly inject the same dose (e.g., 2000 IU every other day). Common doses could be one-tap selections. Frequently-used personal doses could be saved as favorites.

The dose entry is in `ContentView` with validation logic. The `addInjection(doseIU:)` method in `FactorTrackerViewModel` already accepts any valid dose value.

Relevant code:
- `HEMOnitor/Views/ContentView.swift` — dose input field and validation
- `HEMOnitor/ViewModels/FactorTrackerViewModel.swift` — `addInjection(doseIU:)`

## Requirements

- [ ] Add quick-select buttons for common Factor VIII doses:
  - 500 IU, 1000 IU, 1500 IU, 2000 IU, 2500 IU, 3000 IU
  - Tapping a button populates the dose field
  - Buttons displayed as scrollable horizontal row
- [ ] Implement dose favorites/presets:
  - User can save current dose as a favorite
  - Favorites appear as quick-select buttons above or below common doses
  - User can remove saved favorites
  - Favorites persist across app launches (UserDefaults or similar)
- [ ] Optimize number entry keyboard:
  - Use `.decimalPad` or `.numberPad` keyboard type
  - Add toolbar with "Done" button to dismiss keyboard
  - Add "Clear" button to reset input
- [ ] Enhance input validation feedback:
  - Real-time validation as user types
  - Visual indicator (checkmark/warning/error) for input state
  - Warning for unusually high doses with confirmation
- [ ] Add timestamp adjustment option:
  - Default to "now" but allow backdating
  - Quick presets: Now, 1 hour ago, 2 hours ago, Custom
- [ ] Show expected peak level preview based on entered dose

## Constraints

- Do not change the pharmacokinetic formulas or the real vs. display level split
- Do not change calibration behavior
- Do not refactor the MVVM architecture
- All quick-select and preset doses must go through the same `addInjection(doseIU:)` path
- Manual text entry must remain available (quick-select is a shortcut, not a replacement)
- Keep the change scoped to dose entry UX

## Acceptance Criteria

- [ ] Quick-select buttons for common doses populate the input field
- [ ] User can save and remove favorite doses
- [ ] Favorites persist across app launches
- [ ] Keyboard has toolbar with Done and Clear buttons
- [ ] Input validation provides immediate visual feedback
- [ ] Unusually high doses trigger confirmation dialog
- [ ] User can adjust injection timestamp
- [ ] Expected level impact is previewed before adding injection
- [ ] Manual text entry still works for custom doses
- [ ] All dose entry paths (quick-select, favorites, manual) produce correct injections
- [ ] The app builds
- [ ] Existing behavior (calculations, history) is unchanged

## Verification

```bash
xcodebuild -scheme HEMOnitor -destination 'generic/platform=iOS Simulator' build
```

- Build: 
- Tests: 
- Manual check: 

## Notes

Design decisions:
- Quick-select reduces taps for common doses (many users take same dose repeatedly)
- Favorites accommodate individual treatment plans
- Keyboard toolbar follows iOS patterns for dismissing numeric keyboards
- Timestamp adjustment allows logging forgotten injections
- Preview helps users verify dose before committing

Implementation considerations:
- Store favorites as array of Double in UserDefaults with `@AppStorage`
- Consider maximum number of favorites (3-5 to avoid clutter)
- Validation thresholds: what's "unusually high"? (maybe > 5000 IU?)
- Preview calculation uses same `FactorVIIIModel` logic as actual injection

Out of scope:
- Dose calculator (weight-based or target-level-based suggestions)
- Barcode scanning for vial tracking
- Integration with smart injection devices
- Dose reminders/scheduling
- Statistical analysis of dosing patterns

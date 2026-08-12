# Task: User-entered injection dose

Replace the hardcoded "Injecție 3000 UI (test)" button with a user input
that allows entering an injection dose in IU.

Requirements:
- Preserve all existing pharmacokinetic calculations and formulas.
- Do not change calibration behavior.
- Do not refactor the architecture.
- Keep the existing Romanian UI language.
- Reuse the existing addInjection() flow where possible.
- Validate the input appropriately.
- Keep the implementation focused and minimal.

Acceptance criteria:
- The user can enter a dose in IU.
- The dose is validated before an injection is created.
- The existing calculation logic receives the entered dose.
- The app builds successfully.
- Existing behavior unrelated to dose entry remains unchanged.
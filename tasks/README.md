# Tasks

Every non-trivial change to HEMOnitor starts as a task file. The file is the
specification, the working agreement, and afterwards the record of what was done — so
the reasoning behind a change survives outside the chat that produced it.

## Layout

```
tasks/
├── README.md              this file
├── active/                tasks currently specified or in progress
├── completed/             finished tasks, kept as a historical record
└── templates/task.md      the template every task is copied from
```

## Lifecycle

**1. Create.** Copy `templates/task.md` to `active/<NNN>-<kebab-case-title>.md`, using
the next free three-digit number (`001`, `002`, …). Fill in Objective, Context,
Requirements, Constraints, and Acceptance Criteria. Leave Verification and Notes empty
for now.

**2. Agree.** The task is reviewed before any code is written. Scope is settled here —
if the work turns out to need something outside the agreed Requirements, update the
task file and say so, rather than silently widening the change.

**3. Work.** Implement against the file. Tick Requirements as they land. If a
constraint has to be broken, stop and raise it instead of working around it.

**4. Verify.** Fill in the Verification section with the commands actually run and
their real outcome. If something could not be verified — for example the simulator
blockers in CLAUDE.md's "Build & test" — record that honestly instead of leaving it
implied.

**5. Complete.** When every Acceptance Criterion is met and verified: set
`**Status:** completed`, fill `**Completed:**` with the date, write the Notes section,
and move the file to `completed/` (`git mv tasks/active/007-x.md tasks/completed/`).

A task that is abandoned also moves to `completed/`, with `**Status:** abandoned` and a
Notes entry explaining why. Nothing is deleted — the history is the point.

## Rules

- One task, one concern. If a file grows a second objective, split it.
- `active/` is the current work queue; if it isn't in `active/`, it isn't being worked
  on.
- Anything discovered but out of scope goes into Notes, or becomes a new task in
  `active/` — never an unannounced extra change in the same diff.
- The Constraints block in the template holds this project's standing "do not touch"
  list. Keep it in the task unless the task is explicitly about changing one of those
  things.

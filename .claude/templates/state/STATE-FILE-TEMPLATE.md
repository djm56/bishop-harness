# State File Schemas

This file defines what the operational state files **look like**. For when and how often they get written, see `.claude/skills/task-lifecycle/SKILL.md`.

## Files Covered

- `.claude/memory/state/ACTIVE-TASK.md`
- `.claude/memory/state/EVENT-LOG.md`
- `.claude/memory/state/DONE-LOG.md`

## What May Live In `state/` (Hard Rule)

`.claude/memory/state/` is a **closed directory**. A file belongs there only if it is one of two things:

- one of the three canonical state files — `ACTIVE-TASK.md`, `EVENT-LOG.md`, `DONE-LOG.md` — maintained through the state-sync contract; or
- machine-written live harness state, produced by a hook registered in `.claude/settings.json` and read by a registered reader.

Nothing else goes in there. Not checkpoints, not session notes, not scratch files, drafts, or reports. A file an agent wrote by hand, or that no registered hook produces, doesn't qualify under the second class — and an agent cannot bring a file into scope just by writing it there.

Working artifacts — session checkpoints, handoff notes, analysis — belong in `.claude/memory/agent-documents/`, and are worth referencing from the active task's `CONTEXT.md` so resume can find them. Durable task artifacts — progress, context, completion report — belong in `.claude/memory/tasks/task-[id]/`. Any agent that finds a file in `state/` fitting neither class flags it to Bishop for moving or removal rather than working around it.

## Rules That Apply To All Three

1. Filenames are uppercase and exactly as listed above.
2. Markdown field lists. No YAML frontmatter.
3. One blank line between a heading and the first field or list item.
4. Required fields are never added to or removed.
5. Timestamps are `YYYY-MM-DD HH:MM UTC`, 24-hour, UTC. That covers `Last Updated`, EVENT-LOG rows, and DONE-LOG rows.
6. Only values change. Heading text, field names, and field order stay put.
7. `state/` is closed — see the rule above. Three canonical files plus registered machine-written state, nothing more.

## ACTIVE-TASK.md

```markdown
# Active Task

- Task ID: task-[id] | none
- Status: not-started | in-progress | blocked | complete
- Owner: @[agent-name]
- Next Action: [single actionable next step] | none
- Last Updated: YYYY-MM-DD HH:MM UTC
- Blockers: none | [short blocker summary]
```

Task IDs are `task-YYYYMMDD-NN` — see the Task IDs section of `.claude/skills/task-lifecycle/SKILL.md`.

## EVENT-LOG.md

```markdown
# Event Log

| Timestamp | Task ID | Step | Agent | Event | Note |
|-----------|---------|------|-------|-------|------|
| 2026-08-14 09:20 UTC | task-20260814-01 | 1 | @lambert | step-sync | CONTEXT and PROGRESS initialized |
| 2026-08-14 09:52 UTC | task-20260814-01 | 2 | @hicks | step-sync | Search filter implemented |
| 2026-08-14 10:15 UTC | task-20260814-01 | 3 | @apone | step-sync | Approved, no critical findings |
| 2026-08-14 10:31 UTC | task-20260814-01 | — | task-20260814-01 | complete | All steps done, DONE-REPORT written |
```

### EVENT-LOG Rules

- **Append-only.** Existing rows are never edited, reordered, or deleted.
- **The header and separator rows are never rewritten.**
- **Timestamps** are `YYYY-MM-DD HH:MM UTC`, 24-hour, UTC. A time is never invented. If the wall-clock time genuinely isn't known, that's a defect to name in the row's Note — not a field to fill with a plausible-looking guess. A fabricated timestamp in an audit journal does more damage than a visible gap.
- **Time moves forward.** A new row's timestamp is greater than or equal to the row above it. Always append at the end; never insert into the middle.
- **Event values**: `step-sync` (a per-step sync), `complete` (task closed), `blocked` (task blocked).
- **One row per event.** Each sync adds one. Completion or blocking adds one.
- **Escape every pipe in the Note.** A literal `|` anywhere in the Note is written `\|`. Unescaped, it reads as a column separator, splits the row into surplus cells, and corrupts the table with no error and no warning. Not optional.
- **Note** carries brief context — what the step did, or why it blocked. Keep it short; anything needing a real explanation belongs in a document in `agent-documents/`.
- **Read the row back.** After appending, re-read it and confirm: it begins with `|` and ends with `|` (a row missing either isn't a table row, and counting cells won't reveal it); splitting on `|` yields exactly six cells; the timestamp is a full `YYYY-MM-DD HH:MM UTC`; and it is not earlier than the row above. That single check catches missing delimiters, unescaped pipes, half-written timestamps, and mid-file insertions.

Full enforcement lives in `.claude/skills/task-lifecycle/SKILL.md`, which is authoritative on EVENT-LOG.

## DONE-LOG.md

```markdown
# Done Log

| Task ID          | Completed            | Outcome | Summary                                                              |
|------------------|----------------------|---------|----------------------------------------------------------------------|
| task-20260811-01 | 2026-08-11 16:05 UTC | done    | Added CSV export to the reports screen, with tests and docs           |
| task-20260813-01 | 2026-08-13 12:40 UTC | done    | Patched capability check on the settings endpoint; rollback verified  |
| task-20260814-01 | 2026-08-14 10:31 UTC | failed  | Index migration halted on duplicate keys — escalated to the operator  |
```

### DONE-LOG Rules

- **Append-only.** Existing rows are never edited, reordered, or deleted.
- **The header and separator rows are never rewritten.**
- **Column order** is Task ID | Completed | Outcome | Summary. Exactly that.
- **Timestamps** are `YYYY-MM-DD HH:MM UTC`, 24-hour, UTC.
- **Outcome** is `done` (finished) or `failed` (didn't get there).
- **One row per task**, appended at the end.
- **Summary** says concisely what got done, or why it didn't — enough context to be useful later.

Full enforcement lives in `.claude/skills/task-lifecycle/SKILL.md`. DONE-LOG is the append-only index of finished tasks.

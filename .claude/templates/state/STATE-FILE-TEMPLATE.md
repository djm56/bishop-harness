# State File Schemas

This file defines what the operational state files **look like**. For when and how often they get written, see `.claude/skills/task-lifecycle/SKILL.md`.

## Files Covered

- `.claude/memory/state/ACTIVE-TASK.md`
- `.claude/memory/state/EVENT-LOG.md`
- `.claude/memory/state/DONE-LOG.md`

## Rules That Apply To All Three

1. Filenames are uppercase and exactly as listed above.
2. Markdown field lists. No YAML frontmatter.
3. One blank line between a heading and the first field or list item.
4. Required fields are never added to or removed.
5. `Last Updated` is `YYYY-MM-DD HH:MM`, 24-hour.
6. Only values change. Heading text, field names, and field order stay put.

## ACTIVE-TASK.md

```markdown
# Active Task

- Task ID: task-[id] | none
- Status: not-started | in-progress | blocked | complete
- Owner: @[agent-name]
- Next Action: [single actionable next step] | none
- Last Updated: YYYY-MM-DD HH:MM
- Blockers: none | [short blocker summary]
```

## EVENT-LOG.md

```markdown
# Event Log

| Timestamp | Task ID | Step | Agent | Event | Note |
|-----------|---------|------|-------|-------|------|
| 2026-08-14 09:20 | task-021 | 1 | @doc-writer | step-sync | CONTEXT and PROGRESS initialized |
| 2026-08-14 09:52 | task-021 | 2 | @jnr-developer | step-sync | Search filter implemented |
| 2026-08-14 10:15 | task-021 | 3 | @code-reviewer | step-sync | Approved, no critical findings |
| 2026-08-14 10:31 | task-021 | — | task-021 | complete | All steps done, DONE-REPORT written |
```

### EVENT-LOG Rules

- **Append-only.** Existing rows are never edited, reordered, or deleted.
- **The header and separator rows are never rewritten.**
- **Timestamps** are `YYYY-MM-DD HH:MM`, 24-hour.
- **Event values**: `step-sync` (a per-step sync), `complete` (task closed), `blocked` (task blocked).
- **One row per event.** Each sync adds one. Completion or blocking adds one.
- **Note** carries brief context — what the step did, or why it blocked.

Full enforcement lives in `.claude/skills/task-lifecycle/SKILL.md`, which is authoritative on EVENT-LOG.

## DONE-LOG.md

```markdown
# Done Log

| Task ID  | Completed        | Outcome | Summary                                                              |
|----------|------------------|---------|----------------------------------------------------------------------|
| task-019 | 2026-08-11 16:05 | done    | Added CSV export to the reports screen, with tests and docs           |
| task-020 | 2026-08-13 12:40 | done    | Patched capability check on the settings endpoint; rollback verified  |
| task-021 | 2026-08-14 10:31 | failed  | Index migration halted on duplicate keys — escalated to the operator  |
```

### DONE-LOG Rules

- **Append-only.** Existing rows are never edited, reordered, or deleted.
- **The header and separator rows are never rewritten.**
- **Column order** is Task ID | Completed | Outcome | Summary. Exactly that.
- **Timestamps** are `YYYY-MM-DD HH:MM`, 24-hour.
- **Outcome** is `done` (finished) or `failed` (didn't get there).
- **One row per task**, appended at the end.
- **Summary** says concisely what got done, or why it didn't — enough context to be useful later.

Full enforcement lives in `.claude/skills/task-lifecycle/SKILL.md`. DONE-LOG is the append-only index of finished tasks.

# Task Folder Scaffold

Creating `.claude/memory/tasks/task-[id]/` means creating these two files, exactly as laid out below.

The `[id]` is always `task-YYYYMMDD-NN` — the UTC creation date, then a counter that resets each day and starts at `01`. Bishop derives the ID and hands it over; the full derivation is in `.claude/skills/task-lifecycle/SKILL.md`. Nobody invents their own scheme.

## CONTEXT.md

```markdown
# Context — task-[id]

## Goal
[one-line restatement from the Bishop brief]

## Acceptance Criteria
[bullet list]

## Key Files
[paths relevant to this task]

## Notes
[constraints, prior attempts, or cross-agent context]
```

**Every path in `Key Files` is confirmed as it's written** — listed or read, not assumed. A path that doesn't exist yet gets an explicit `— to be created at step N` marker rather than being written bare. A wrong path in canonical task state is invisible guidance: later agents take the documented structure as correct and nobody thinks to question it.

## DONE-REPORT.md

Written at completion, never at task start.

- Path: `.claude/memory/tasks/task-[id]/DONE-REPORT.md`
- Format comes from: `.claude/templates/task/DONE-REPORT-TEMPLATE.md`
- What it's for: the end-to-end outcome, the assumptions that turned out wrong, the mistakes agents made, and whatever a similar task later would want to know.

## PROGRESS.md

```markdown
# Progress — task-[id]

| Step | Phase | Agent | Status | Notes |
|------|-------|-------|--------|-------|

<!-- Update row status after each sub-agent completes: pending → in-progress → done/failed -->
```

**Worth being clear about**: PROGRESS.md is both the canonical plan and the live step status. At task start every planned step goes in as `pending`. A step becomes `in-progress` **the moment its brief is delegated** — not afterwards — and the state-sync that follows the step moves it to `done` (or `failed`). By the time a sync runs, the next step is already `in-progress`; the sync doesn't set it.

**The Phase column** groups steps under a phase or sub-phase label (`1.2`, `2.4 Part 3`, and so on). Unphased or single-phase tasks use `—`. It's a required column either way, so a plan reads the same whether it has two steps or forty.

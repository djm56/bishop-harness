# Task Folder Scaffold

Creating `.claude/memory/tasks/task-[id]/` means creating these two files, exactly as laid out below.

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

## DONE-REPORT.md

Written at completion, never at task start.

- Path: `.claude/memory/tasks/task-[id]/DONE-REPORT.md`
- Format comes from: `.claude/templates/task/DONE-REPORT-TEMPLATE.md`
- What it's for: the end-to-end outcome, the assumptions that turned out wrong, the mistakes agents made, and whatever a similar task later would want to know.

## PROGRESS.md

```markdown
# Progress — task-[id]

| Step | Agent | Status | Notes |
|------|-------|--------|-------|

<!-- Update row status after each sub-agent completes: pending → in-progress → done/failed -->
```

**Worth being clear about**: PROGRESS.md is both the canonical plan and the live step status. At task start every planned step goes in as `pending`. As each sub-agent finishes, its step moves to `done` (or `failed`) and the next one moves to `in-progress`.

# The Done Report

Written to `.claude/memory/tasks/task-[id]/DONE-REPORT.md` when a task closes.

- Written once, at the closing gate. It's a single-write artifact.
- Not a rolling log — don't keep adding to it across sessions.
- Not a replacement for `DONE-LOG.md`, which stays the append-only index.

## DONE-REPORT.md

```markdown
# Done Report — task-[id]

## Task Summary
- Goal: [one-line goal from CONTEXT.md]
- Outcome: done | failed
- Completed: YYYY-MM-DD HH:MM UTC

## Acceptance Criteria Outcome
- [ ] [criterion 1] — pass | fail | partial
- [ ] [criterion 2] — pass | fail | partial

## Logical Step Recap
| Step | Phase | Agent | Status | Notes |
|------|-------|-------|--------|-------|
| 1 | [phase or —] | @agent-name | done | [summary from PROGRESS.md] |
| 2 | [phase or —] | @agent-name | done | [summary from PROGRESS.md] |

## Deliverables Changed
- `path/to/file.ext` — [what changed and why]
- `path/to/another.ext` — [what changed and why]

## Tracker And Reality
- Trackers checked: [project progress.md, README status table, …] | none touched
- Drift found: none | [what disagreed with the disk]
- Resolution: tracker synced before closing | drift recorded here as
  not done / done but untracked / never in plan

## Wrong Assumptions (Mandatory)
| Assumption | Why It Was Wrong | Correction Applied |
|------------|------------------|--------------------|
| [assumption] | [evidence/outcome] | [fix/process change] |

## Sub-Agent Mistakes and Corrections (Mandatory)
| Agent | Mistake | Impact | Corrective Action | Prevention Next Time |
|-------|---------|--------|-------------------|----------------------|
| @agent-name | [what went wrong] | [low/med/high + brief note] | [what was done] | [specific safeguard] |

## Improvements and Patterns Linked
- Improvements entry refs: [IMPROVEMENTS.md heading] | none
- Pattern entry refs: [PATTERNS.md heading] | none
- Agent notes refs: [agent-notes/<name>.md heading] | none

## Similar Future Tasks
- Trigger to reuse this report: [when a future task is similar]
- Reuse checklist:
  1. [step]
  2. [step]
  3. [step]
```

**On Tracker And Reality**: the three drift labels are the ones defined in `.claude/skills/task-lifecycle/SKILL.md` under Three Kinds Of Not Done. Use them as written — they carry different fixes, and collapsing them into "not started" loses the only information that says which fix applies.

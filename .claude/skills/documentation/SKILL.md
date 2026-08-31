---
name: documentation
description: "Technical documentation writing skill covering README structure, changelog maintenance, architecture decision records (ADRs), user-facing docs, and state file management. Used by doc-writer sub-agent."
---

# Writing Documentation

## README Shape

```markdown
# Project Name

Brief one-line description.

## Requirements

- PHP version
- WordPress version
- Dependencies

## Installation

Step-by-step install instructions.

## Usage

How to use the plugin/theme with examples.

## Configuration

Available settings and their defaults.

## Hooks

### Actions
- `prefix_action_name` — Description. Params: `$param1`, `$param2`.

### Filters
- `prefix_filter_name` — Description. Params: `$value`, `$context`.

## Changelog

See CHANGELOG.md.
```

## Changelog Shape

```markdown
## [1.2.0] - YYYY-MM-DD
### Added
- New feature description.

### Changed
- Modified behavior description.

### Fixed
- Bug fix description.

### Removed
- Removed feature description.
```

Follow the [Keep a Changelog](https://keepachangelog.com/) conventions.

## Writing State Files

When Bishop hands you a state update:

- `.claude/skills/task-lifecycle/SKILL.md` is the authority on when and how state changes.
- `.claude/templates/state/STATE-FILE-TEMPLATE.md` is the canonical schema.
- **ACTIVE-TASK.md** — update the values: Task ID, Status, Owner, Next Action, Last Updated, Blockers.
- **EVENT-LOG.md** — one appended row per state-sync (the primary audit record), plus one on completion or blocking. Timestamps are `YYYY-MM-DD HH:MM UTC` and are never invented. Escape every literal `|` in the Note as `\|`, append with Write or Edit rather than a heredoc, and read the row back afterwards — six cells, both outer pipes, a whole timestamp, no earlier than the row above. Schema in the state template.
- **PROGRESS.md** (task-local) — the plan plus live step status, in the `Step | Phase | Agent | Status | Notes` table. Mark the finished step `done`; leave the next one alone, because Bishop set it to `in-progress` when its brief went out.
- **DONE-LOG.md** — append the completed task's row. Append-only: existing rows and the header are never touched.

`DONE-LOG.md` uses exactly this schema:

```markdown
| Task ID  | Completed        | Outcome | Summary                                                              |
|----------|------------------|---------|----------------------------------------------------------------------|
| task-[id] | YYYY-MM-DD HH:MM UTC | done|failed | [concise summary]                                                   |
```

State files live in `.claude/memory/state/`. Never delete one. Heading text, field names, and field order stay exactly as they are — only values move.

`state/` is a **closed directory**: those three files plus machine-written state from a registered hook, and nothing else. Checkpoints, handoff notes, drafts, and reports go in `.claude/memory/agent-documents/` instead — referenced from the active task's `CONTEXT.md` so resume finds them. The full allowlist is in the state template.

An ACTIVE-TASK.md update rewrites what has stopped being true. Any sentence calling something outstanding, pending, awaiting a decision, or blocked gets checked against what the intervening steps did and rewritten or dropped where they closed it — never copied forward. A stale sentence in a state file reads as authoritative while being wrong.

## Writing Improvement Entries

When Bishop hands you improvement entries to append:

- `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md` is the only format authority, covering all three types: `IMPROVEMENTS.md`, `PATTERNS.md`, and `agent-notes/<agent-name>.md`.
- All three are **append-only**. Existing entries are never edited, reordered, or removed.
- Every improvement file carries `<!-- Append new entries below this line -->` just under its header. The marker never moves. Every new entry goes **below it and below everything already there** — at the very bottom of the file. Read the file first, find the last existing entry, and append after it: nothing gets inserted between entries, nothing above the insertion point is touched, and nothing is removed to make room.
- For `agent-notes/<agent-name>.md`: create it from the template's new-file header if it isn't there, then append.
- Agent-notes entries always carry a `Source` — `self-reported` or `bishop-observed`.
- Never set or move the `Status` field. It starts at `proposed` and only the human operator changes it — and the same goes for `Approver` and `Date approved`.
- An IMPROVEMENTS.md entry may carry amendment lines after `Date approved`, so an entry ends at the next `### [` heading or at the end of the file — not at whichever field you recognise last.
- Given several entries across several files, write them all in one response.

## House Style

- Active voice.
- Short, direct sentences.
- Code in code blocks, always.
- Link to a file rather than copying its content.
- Tables when you're comparing structured things.

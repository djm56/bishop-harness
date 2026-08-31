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
- **EVENT-LOG.md** — one appended row per state-sync (the primary audit record), plus one on completion or blocking. Schema in the state template.
- **PROGRESS.md** (task-local) — the plan plus live step status. Mark the finished step `done` and the next one `in-progress`.
- **DONE-LOG.md** — append the completed task's row. Append-only: existing rows and the header are never touched.

`DONE-LOG.md` uses exactly this schema:

```markdown
| Task ID  | Completed        | Outcome | Summary                                                              |
|----------|------------------|---------|----------------------------------------------------------------------|
| task-[id] | YYYY-MM-DD HH:MM | done|failed | [concise summary]                                                   |
```

State files live in `.claude/memory/state/`. Never delete one. Heading text, field names, and field order stay exactly as they are — only values move.

## Writing Improvement Entries

When Bishop hands you improvement entries to append:

- `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md` is the only format authority, covering all three types: `IMPROVEMENTS.md`, `PATTERNS.md`, and `agent-notes/<agent-name>.md`.
- All three are **append-only**. Existing entries are never edited, reordered, or removed.
- Append below the `<!-- Append new entries below this line -->` marker in `IMPROVEMENTS.md` and `PATTERNS.md`.
- For `agent-notes/<agent-name>.md`: create it from the template's new-file header if it isn't there, then append.
- Agent-notes entries always carry a `Source` — `self-reported` or `bishop-observed`.
- Never set or move the `Status` field. It starts at `proposed` and only the human operator changes it.
- Given several entries across several files, write them all in one response.

## House Style

- Active voice.
- Short, direct sentences.
- Code in code blocks, always.
- Link to a file rather than copying its content.
- Tables when you're comparing structured things.

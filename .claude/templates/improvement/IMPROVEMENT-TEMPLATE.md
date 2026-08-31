# Improvement Entry Formats

The reference for appending to the files in `.claude/memory/improvements/`.

**Append-only.** Existing entries are never modified, reordered, or deleted. New entries go on the end.

**Status.** Every new entry starts at `Status: proposed`. Only the human operator moves it along (`proposed → approved → applied → rejected`). No agent — doc-writer included — ever changes the status on an existing entry.

---

## IMPROVEMENTS.md

File: `.claude/memory/improvements/IMPROVEMENTS.md`

Append below the `<!-- Append new entries below this line -->` marker.

```
### [YYYY-MM-DD] — [Agent/Skill/Tool Target]
**Suggestion**: [concrete, actionable change to an agent prompt, skill, or tool]
**Rationale**: [why this improves future task outcomes]
**Status**: proposed
**Approver**: —
**Date approved**: —
```

**Rules:**

- The target is a named agent (`@jnr-developer`), a skill (`task-lifecycle`), or a tool concept. Not a vague area.
- The suggestion has to be implementable without anyone coming back to ask what it means.
- Status is `proposed` on creation. Never anything else.
- **Approver** and **Date approved** belong to the human. No agent fills them in — they're recorded when a human moves status to `approved`.
- This file is for agent, skill, and tool behaviour. Code patterns go in PATTERNS.md.

---

## PATTERNS.md

File: `.claude/memory/improvements/PATTERNS.md`

Append below the `<!-- Append new entries below this line -->` marker.

```
### [Pattern Name]
**Context**: [when to use this pattern — specific trigger or situation]
**Solution**: [what to do]
**Example**: [brief code or reference, or "n/a" if not applicable]
**Discovered**: [YYYY-MM-DD, task-id]
```

**Rules:**

- Give it a short, descriptive name — something like `Bootstrap 4.3 SCSS Module Pattern`.
- Context is a concrete trigger, not a broad category.
- This file is for reusable code conventions, architecture decisions, and technical solutions.
- Agent and skill behaviour goes in IMPROVEMENTS.md, not here.

---

## agent-notes/[agent-name].md

File: `.claude/memory/improvements/agent-notes/[agent-name].md`

Create it if it isn't there yet, using the header below.

**Header for a new file — only when creating it, never repeated in an existing one:**

```markdown
# Agent Notes — [agent-name]

Calibration notes about this agent's performance, context needs, and framing.
Append only. Never modify existing entries.

<!-- Append new entries below this line -->
```

**Entry format** — append after the last entry, or after the marker:

```
### [YYYY-MM-DD] — [Observation Title]
**Note**: [what was observed — behavior, gap, missed step, or strength]
**Adjustment**: [what to change in future delegations or the agent's own file]
**Source**: self-reported | bishop-observed
```

**Rules:**

- `Source` is either `self-reported` (the agent wrote it about itself) or `bishop-observed` (Bishop added it from watching the delegation land).
- Write only when something is genuinely worth noting. No "no issues" or "performed as expected" entries — they're noise.
- The adjustment has to be specific enough to act on. "Add X to the pre-flight checklist in the agent file", not "be more careful".

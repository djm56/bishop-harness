---
name: self-improvement
description: "Framework for capturing high-quality improvements and learnings discovered during task execution. Covers identifying valuable patterns, edge cases, architecture insights, and conventions that should update agent prompts or skills. Used by Bishop to suggest enhancements without creating excessive noise."
---

# Learning From Finished Work

## When It Runs

The learning pass is **mandatory at the end of every task**. Bishop runs it whether or not it produces anything. Entries get written only where there's something concrete and actionable — never to prove the pass happened.

- Sub-agents attach findings to their step completion report, **only when they actually found something**. Saying nothing is a valid outcome.
- Bishop gathers those reports plus its own observations once the task is done.
- Where something concrete exists, Bishop hands the writes to `@doc-writer`, pointing at `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md` for format.
- `@doc-writer` does the appending. Bishop never writes these files directly.

## How It Flows

```
Sub-agent finishes a step
  └─ Attaches an improvement note to its completion report (only if it found something)
       └─ Bishop collects reports as the task runs
            └─ At completion, Bishop reviews everything collected plus its own observations
                 └─ Anything concrete?
                      └─ Bishop delegates the writes to @doc-writer
                           └─ @doc-writer appends, using IMPROVEMENT-TEMPLATE.md
```

- A sub-agent with nothing to report says nothing. No "no issues here" message needed.
- Bishop decides what qualifies before delegating anything.
- `@doc-writer` gets named files and exact content. It doesn't decide what's worth recording.
- Everything is created as `proposed`. Only the human operator moves it on.

## The Bar An Entry Has To Clear

Before writing anything, ask:

1. Is it specific enough to act on? If not, drop it.
2. Is it worth doing, even if the payoff is small? Vague or hypothetical, drop it.
3. Is it already covered by an agent prompt or a skill? If yes, drop it.
4. Could someone implement it without coming back to ask questions? If not, sharpen it first.

## Where Things Go

Everything lands under `.claude/memory/improvements/`, sorted by what kind of insight it is:

| Kind of insight | Goes to |
|---|---|
| Reusable pattern (WordPress practice, theme architecture) | `.claude/memory/improvements/PATTERNS.md` |
| A change to an agent or skill | `.claude/memory/improvements/IMPROVEMENTS.md` |
| How a particular agent is performing | `.claude/memory/improvements/agent-notes/<agent-name>.md` |

**Format authority**: `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md` governs all three. Every file is append-only.

> **A convention is not an improvement.** `.claude/memory/reference/CONVENTIONS.md` holds binding rules a human ratified, and it sits OUTSIDE this framework — no agent writes to it. If an insight ought to become a hard rule, file it here as an `IMPROVEMENTS.md` suggestion (status `proposed`) and let a human ratify it across. On conflict, `CONVENTIONS.md` (binding) beats `PATTERNS.md` (advisory).

### IMPROVEMENTS.md

Proposed changes to an agent prompt or a skill file.

```
### [Date] — [Agent/Skill Target]
**Suggestion**: [concrete change]
**Rationale**: [why this improves outcomes]
**Status**: proposed | approved | applied | rejected
```

### PATTERNS.md

Architectural patterns, conventions, or solutions worth reusing.

```
### [Pattern Name]
**Context**: [when to use this]
**Solution**: [what to do]
**Example**: [brief code or reference]
**Discovered**: [date, task-id]
```

### agent-notes/[agent-name].md

How a given agent is doing — performance, the context it needs, how briefs land. Written by the agent about itself (self-reported) or by Bishop from observation. Both count.

```
### [Date] — [Observation]
**Note**: [what was observed]
**Adjustment**: [what to change in future delegations]
**Source**: self-reported | bishop-observed
```

## Worked Examples

**IMPROVEMENTS.md**

```
### 2026-05-04 — snr-developer
**Suggestion**: Add a pre-flight checklist to the agent file: before starting block development, verify ACF config, check component lifecycle, confirm Bootstrap 4.3 constraints.
**Rationale**: These constraints tend to surface halfway through implementation. Checking first moves the discovery earlier and cuts rework.
**Status**: approved
```

**PATTERNS.md**

```
### Bootstrap 4.3 SCSS Module Pattern
**Context**: Styling responsive layouts with Bootstrap 4.3, where inline @media queries spread quickly.
**Solution**: Use the media-breakpoint-up() mixin. One .scss module per component, BEM naming: .b-[component]__[element]--[modifier].
**Example**: .b-hero__content { font-size: 1rem; @include media-breakpoint-up(lg) { font-size: 1.5rem; } }
**Discovered**: 2026-04-25, task-014
```

---

## How Status Moves

1. **proposed** — newly raised, nobody has looked yet.
2. **approved** — reviewed and accepted.
3. **applied** — actually implemented in the target agent prompt or skill file.
4. **rejected** — reviewed and turned down, with the reason written down.

## What Not To Write

- Nothing vague. "Agent did well" and "could be better" help no one.
- Nothing already sitting in an agent prompt or skill.
- Nothing hollow. No "no learnings this task" entries. If nothing clears the bar, write nothing at all — that's the correct outcome, not a gap.

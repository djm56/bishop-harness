---
name: task-lifecycle
description: "Single canonical source of truth for how tasks flow through the system. Covers agent delegation rules, state-update contract, code-quality pipeline, and improvements/learning. Referenced by Bishop, commands, and doc-writer."
---

# The Task Lifecycle

This is the **one canonical reference** for how tasks run. Where any other document disagrees with this file, this file wins.

Every agent and command that does work follows what's below.

---

## What This Covers

The full lifecycle — the `/start-task` path that `@bishop` drives. It applies to every task the harness runs: durable session state (`ACTIVE-TASK.md`, `EVENT-LOG.md`, `DONE-LOG.md`, `tasks/task-[id]/`), a sync after every step, and the learning pass at the end. The **Delegation Contract** below rides along with it: junior starts all implementation, reviewer checks every step, senior stays in reserve.

---

## Terms

- **Logical plan step** — a numbered step in Bishop's plan. One step is one delegation to one sub-agent (e.g. "Step 2: @jnr-developer — implement feature X").
- **State-sync delegation** — the required checkpoint handed to @doc-writer right after each logical step. It may go unnumbered in the written plan, but it is never optional at runtime.
- **Code-producing step** — any step that creates or changes files outside `.claude/`.

---

## The State-Sync Contract

### Who Does What

- **Bishop** decides what changed and what happens next.
- **@doc-writer** does the writing, on Bishop's delegation.
- @doc-writer updates all three state files (PROGRESS.md, ACTIVE-TASK.md, EVENT-LOG.md) in **one delegation**, never three separate ones.

### The Three Targets

Every sync touches all three:

| File | What changes |
|------|--------------|
| `.claude/memory/state/EVENT-LOG.md` | One appended row — the primary continuity record: Timestamp \| Task ID \| Step \| Agent \| Event \| Note. Event is `step-sync`. This row is the authoritative record that the sync happened. |
| `.claude/memory/state/ACTIVE-TASK.md` | The live pointer: task id, status, owner, next action, last-updated timestamp, blockers. |
| `.claude/memory/tasks/task-[id]/PROGRESS.md` | The finished step marked done. The plan and its live status live here. |

### The Audit Journal

`.claude/memory/state/EVENT-LOG.md` is the primary continuity record and the source of truth for a task's history. One row per state-sync delegation. Schema is in `.claude/templates/state/STATE-FILE-TEMPLATE.md` — Timestamp | Task ID | Step | Agent | Event | Note. Event is `step-sync`, timestamp is the moment of the sync, Note carries brief context. It isn't a side note; it's the record.

### Timing

| Trigger | What happens |
|---------|--------------|
| **Task start** — before step 1 of a genuinely new task | Build `tasks/task-[id]/CONTEXT.md` and `PROGRESS.md` from `.claude/templates/task/TASK-TEMPLATE.md`, copied exactly — same headings, order, structure. Fill in the planned-step rows in `PROGRESS.md`; the plan lives there. Initialize `ACTIVE-TASK.md` with the new task id and status `in-progress`. Confirm `EVENT-LOG.md` exists. Clear `.claude/memory/agent-documents/*.md` (keep `.gitkeep`) — but only once you've confirmed the previous task is complete or deliberately replaced. |
| **After EVERY numbered step** | Hand a state-sync to @doc-writer: append the EVENT-LOG.md row, update the ACTIVE-TASK.md pointer, mark the step done in PROGRESS.md. All three, one delegation. Mandatory. |
| **Task completion** — after the final step | Run the learning pass (BLOCKING). Only then set `ACTIVE-TASK.md` to complete. Only then append to `DONE-LOG.md`. |

### The Scratch Workspace

- During a task, any agent may create, update, edit, delete, and organise files under `.claude/memory/agent-documents/`.
- The structure inside it is deliberately unconstrained.
- It's temporary and scoped to the task: drafts, checklists, scratch notes, analysis, review write-ups while work is in flight.
- When the active task is `in-progress` or `blocked`, everything in there survives across sessions and counts as valid context on resume.
- The canonical files stay canonical regardless: `PROGRESS.md` (plan and step status), `ACTIVE-TASK.md` (live pointer), `EVENT-LOG.md` (continuity record).
- Clearing it happens only at confirmed new-task initialization, as above — `*.md` goes, `.gitkeep` stays.

### The Rule

> When a numbered step finishes, Bishop delegates a state-sync to @doc-writer BEFORE calling the next sub-agent. No exceptions, no batching, no skipping, no saving it for the end.

If Bishop can't open a state file and see the current position in the plan, the contract is already broken.

### The Blocking Gate

- Bishop does not delegate the next step until the sync has succeeded.
- A sync that's missing, partial, malformed, or stale sets the task to `blocked` and stops execution until it's fixed.
- One catch-up write at the end does not retroactively satisfy the syncs that were skipped.

### Validating A Sync

All of this has to hold before execution continues:

1. EVENT-LOG.md row appended (event=step-sync), matching the STATE-FILE-TEMPLATE schema: Timestamp | Task ID | Step | Agent | Event | Note.
2. ACTIVE-TASK.md updated — task id, status, owner, next action, last-updated (YYYY-MM-DD HH:MM), blockers.
3. PROGRESS.md step table — finished step `done`, next step `in-progress`.
4. All three conform to `.claude/templates/state/STATE-FILE-TEMPLATE.md` and `.claude/templates/task/TASK-TEMPLATE.md`.
5. The sync describes the step immediately preceding it, and nothing else.

### The Completion Gate

- Closing actions (`ACTIVE-TASK complete`, `DONE-LOG`) are only permitted once every logical step has sync evidence behind it.
- A step without that evidence makes completion invalid. The task stays `in-progress` or `blocked`.

### Appending To DONE-LOG

- Append-only.
- One new row at the end for the finished task.
- Existing rows are never modified.
- The header and separator rows are never rewritten.
- Exactly this shape and column order:

```markdown
| Task ID  | Completed        | Outcome | Summary                                                              |
|----------|------------------|---------|----------------------------------------------------------------------|
| task-[id] | YYYY-MM-DD HH:MM | done|failed | [concise summary]                                                   |
```

---

## Where The Schemas Live

State files follow `.claude/templates/state/STATE-FILE-TEMPLATE.md`. That's the schema reference. This skill says *when* and *why* to write; the template says *what the file looks like*.

Task files follow `.claude/templates/task/TASK-TEMPLATE.md` for `CONTEXT.md` and `PROGRESS.md`.

Human-ratified conventions live in `.claude/memory/reference/CONVENTIONS.md`, scaffolded by `.claude/templates/reference/CONVENTIONS-TEMPLATE.md`. Binding, and human-edited only — see the Conventions Contract below.

---

## The Delegation Contract — Not Negotiable

Who gets coding work. Applies while planning *and* while executing. Bishop enforces it.

### Rule 1 — @jnr-developer starts everything

- Every coding implementation step in the plan goes to `@jnr-developer`.
- `@snr-developer` gets no step in the initial plan.
- True regardless of how complex, architectural, performance-critical, or difficult the task looks.
- No exceptions. Complexity is handled by scoping the task, not by picking a different agent.

### Rule 2 — @code-reviewer follows every coding step

- Wherever `@jnr-developer` or `@snr-developer` writes or changes code, the **very next numbered step** is `@code-reviewer`.
- "Very next" means nothing in between. The review sits directly behind the code.
- Fix rounds included — every fix attempt by any developer gets its own review step.

### Rule 3 — @snr-developer only by escalation

- `@snr-developer` arrives through the Code-Quality Pipeline below, and no other way.
- The single trigger: `@jnr-developer` fails 2 fix rounds on the same CRITICAL issue, with 2 separate `@code-reviewer` reviews confirming it's still open.
- Bishop never pre-plans that step. It appears during execution or not at all.

### Breaking Them

| What happened | What it costs |
|---------------|---------------|
| `@snr-developer` given a step in the initial plan | Plan INVALID. Rewrite before executing. |
| A coding step without `@code-reviewer` immediately after | Plan INVALID. Rewrite before executing. |
| Escalating to `@snr-developer` before 2 confirmed junior rounds | Escalation INVALID. Finish the junior rounds. |
| Code shipped without a `@code-reviewer` pass | Quality contract broken. Task BLOCKED. |
| "It's complex" / "it's architectural" used to justify `@snr-developer` up front | Not a valid reason. Rule 1 has no exceptions. |

---

## The Code-Quality Pipeline

Any step where `@jnr-developer` or `@snr-developer` creates or changes files outside `.claude/` is followed **immediately** by `@code-reviewer`. Mandatory — a coding step without a review behind it doesn't exist in a valid plan.

1. `@code-reviewer` reviews the output. Always. There is no "too trivial to review".
2. **CRITICAL** findings → fix goes to `@jnr-developer` → `@code-reviewer` reviews again. That's a new numbered pair of steps.
3. Junior gets **2 fix rounds** (each round = one fix step plus one review step). Same CRITICAL issue still open after both → escalate to `@snr-developer`.
4. `@snr-developer` remediates → `@code-reviewer` reviews again. Senior gets **2 rounds**.
5. Still failing after 2 senior rounds → stop and escalate to the operator. Do not keep going.
6. `@doc-writer` updates docs only where it's warranted: a public API changed, new files appeared, or something README-relevant moved.

The review step is a numbered plan step like any other, and it gets its own state-sync afterwards.

---

## Improvements And Learning

### The Chain

Every improvement write follows this path:

1. **Sub-agents** attach findings to their step completion report — only when there's something concrete. Silence is valid.
2. **Bishop** gathers those reports plus its own observations, and reviews at completion.
3. **Bishop delegates** anything concrete to `@doc-writer`, naming the file targets and the entry content, per `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md`.
4. **`@doc-writer`** appends. It executes; it doesn't decide what's worth recording.

### Agent Notes (`improvements/agent-notes/<agent-name>.md`)

- Written only when something noteworthy happened — good or bad.
- Nothing notable means nothing written. No "no issues" entries.
- Either self-reported (the agent noting its own behaviour) or bishop-observed (Bishop noting it). Both valid — set `Source` accordingly.
- Written at completion, during the learning pass delegation.

### IMPROVEMENTS.md

- Written at **completion only**.
- Concrete, actionable changes to a prompt or a skill. Nothing else.
- Has to clear the Quality Gate in `.claude/skills/self-improvement/SKILL.md`.
- A single occurrence is enough. You don't need to see something twice before recording it.
- Nothing to report means no write. No empty entries, no placeholders.

### PATTERNS.md

- Written at **completion only**.
- Reusable conventions, architecture decisions, and technical solutions.
- Has to clear the Quality Gate.
- Nothing to report means no write.

### The Rule

> The learning pass runs at the end of every task, without exception. Files get written only where findings are concrete, actionable, and clear the Quality Gate. Empty, vague, or placeholder entries are forbidden.

---

## The Conventions Contract

`.claude/memory/reference/CONVENTIONS.md` holds binding coding conventions that a human ratified. It is deliberately separate from the improvement loop:

- **Read before acting.** `@jnr-developer`, `@snr-developer`, and `@code-reviewer` read every entry whose `Scope` covers the files in play — before writing or reviewing — and comply.
- **Binding beats advisory.** On any conflict, `CONVENTIONS.md` (ratified) overrides `PATTERNS.md` (observed).
- **Agents never write to it.** A discovered convention is proposed through `IMPROVEMENTS.md` as `proposed`; a human ratifies it across. That is the only path, under any circumstances.
- **Reviewer enforces it.** `@code-reviewer` tests each changed file against the `Reviewer check` of every matching `active` entry. A violation is CRITICAL.
- **Not an improvement.** Ratified conventions aren't logged as rules in `IMPROVEMENTS.md` or `PATTERNS.md`. Only the human-ratification path adds to `CONVENTIONS.md`.

---

## Starting A Task — Checklist

Bishop confirms all of this, via delegation to @doc-writer:

1. [ ] `.claude/memory/agent-documents/*.md` cleared, `.gitkeep` preserved
2. [ ] `.claude/memory/tasks/task-[id]/CONTEXT.md` built from `.claude/templates/task/TASK-TEMPLATE.md`, exactly
3. [ ] `.claude/memory/tasks/task-[id]/PROGRESS.md` built from the same template, exactly, with the step table filled in for every planned step
4. [ ] `state/ACTIVE-TASK.md` initialized — new task id, status `in-progress`, owner, next action
5. [ ] `state/EVENT-LOG.md` present and ready for the first append

All five confirmed before the first numbered step runs.

---

## Closing A Task — Checklist

Once every step is done, in this exact order:

1. [ ] Final state-sync (last step marked done, EVENT-LOG row appended with event=step-sync)
2. [ ] Closing summary written for the operator
3. [ ] **Learning pass run (BLOCKING — must finish before anything closes):**
   - 3a. [ ] Bishop gathers improvement reports from every sub-agent that contributed
   - 3b. [ ] Bishop reviews its own observations — Bishop-level patterns, agent behaviour
   - 3c. [ ] Anything concrete? Delegate the writes to `@doc-writer` with named file targets and entry content, per `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md`
   - 3d. [ ] `@doc-writer` appends to `IMPROVEMENTS.md`, `PATTERNS.md`, and/or `agent-notes/[name].md` as applicable
   - Nothing found? The pass is complete. No delegation, no writes.
4. [ ] `tasks/task-[id]/DONE-REPORT.md` written by `@doc-writer` from `.claude/templates/task/DONE-REPORT-TEMPLATE.md`
   - Mandatory sections: wrong assumptions, and per-agent mistakes with corrective actions
   - Written once at completion — not maintained as a rolling log
   - Applies to active and newly finished tasks only. No retroactive backfill unless asked.
5. [ ] `state/ACTIVE-TASK.md` set to `complete`, Next Action set to `none` (the completion-gate hook checks DONE-REPORT.md exists)
6. [ ] EVENT-LOG row appended with event=complete (schema in STATE-FILE-TEMPLATE.md)
7. [ ] Row appended to `state/DONE-LOG.md`
   - Append-only, columns exactly `Task ID | Completed | Outcome | Summary`
8. [ ] Every logical step confirmed to have sync evidence before the task closes

### The Closing Gate

Bishop does not mark `ACTIVE-TASK.md` complete or append to `DONE-LOG.md` until the learning pass (3) and `DONE-REPORT.md` (4) have both run. Skip or defer either and the task stays `in-progress` and cannot close. This is as serious as skipping a per-step sync.

### The Hooks

Two POSIX-sh hooks in `.claude/hooks/`, wired up in `.claude/settings.json`, enforce continuity mechanically:

- **completion-gate.sh** (PreToolUse, HARD BLOCK) — refuses to let `ACTIVE-TASK.md` go to `complete` unless the task's `DONE-REPORT.md` exists. The mechanical backstop to the closing checklist, and the only hook that blocks a close.
- **state-continuity.sh** (PostToolUse, WARN ONLY) — warns when `EVENT-LOG.md` hasn't advanced for the active task. Advisory. Never blocks.

Both are reversible. They back up the written rules; they don't replace them.

---

## What A Plan Looks Like

```
Plan for task-003:
1. @jnr-developer — Create authentication module
   → [state-sync delegation to @doc-writer]
2. @code-reviewer — Review authentication module
   → [state-sync delegation to @doc-writer]
3. @jnr-developer — Fix any CRITICAL issues from review
   → [state-sync delegation to @doc-writer]
4. @doc-writer — Update README with auth docs
   → [state-sync delegation to @doc-writer]
Close: summary → learning pass (BLOCKING) → DONE-REPORT (BLOCKING) → ACTIVE-TASK complete → DONE-LOG
```

Every `→ [state-sync delegation]` is required at runtime and cannot be put off.

---

## The Whole Thing, End To End

```
OPERATOR REQUEST
    │
    ▼
┌─────────────────────────────────────────┐
│ PLANNING                                │
│ Goal → Criteria → Risks → Plan          │
│ ⚠️ Every code step → @jnr-developer     │
│ ⚠️ Every code step → @code-reviewer     │
│ ⚠️ @snr-developer NEVER in the plan     │
└─────────────────────┬───────────────────┘
                      │ plan settled
                      ▼
┌─────────────────────────────────────────┐
│ INITIALIZATION                          │
│ Clear scratch → CONTEXT → PROGRESS →    │
│ ACTIVE-TASK → EVENT-LOG                 │
│ ⚠️ All 5 confirmed before step 1        │
└─────────────────────┬───────────────────┘
                      │ confirmed
                      ▼
┌─────────────────────────────────────────┐
│ EXECUTION LOOP (every step)             │
│ A.Hand out → B.Read → C.Sync →          │
│ D.Confirm → E.Continue                  │
│ ⚠️ The sync blocks the next step        │
│                                         │
│ Code step? → CODE-QUALITY PIPELINE      │
└─────────────────────┬───────────────────┘
                      │ all steps done
                      ▼
┌─────────────────────────────────────────┐
│ CLOSING GATE                            │
│ A.Summary → B.Learning pass →           │
│ C.DONE-REPORT → D.Mark complete →       │
│ E.Append DONE-LOG                       │
│ ⚠️ B and C both block the close         │
└─────────────────────────────────────────┘
```

---

## Everything That Blocks

| Checkpoint | Kind | What it stops |
|------------|------|---------------|
| @jnr-developer on every initial code step | Hard rule | Plan INVALID otherwise |
| @code-reviewer directly after every code step | Hard rule | Plan INVALID otherwise |
| @snr-developer absent from the initial plan | Hard rule | Plan INVALID otherwise |
| All 5 initialization items confirmed | Blocking gate | Step 1 can't start |
| State-sync after each step | Blocking gate | Next step can't start |
| 3-target sync validation (EVENT-LOG + ACTIVE-TASK + PROGRESS) | Blocking gate | Execution can't continue |
| 2 junior fix rounds maximum | Escalation rule | Must go to @snr-developer |
| 2 senior fix rounds maximum | Escalation rule | Must go to the operator |
| Learning pass at completion | Blocking gate | Task can't close |
| DONE-REPORT written at completion | Blocking gate | Task can't close |
| ACTIVE-TASK marked complete before DONE-LOG | Sequencing | DONE-LOG can't be appended |

---

## Templates

| For | File |
|-----|------|
| State file schemas | `.claude/templates/state/STATE-FILE-TEMPLATE.md` |
| Task files (CONTEXT.md, PROGRESS.md) | `.claude/templates/task/TASK-TEMPLATE.md` |
| Completion report (DONE-REPORT.md) | `.claude/templates/task/DONE-REPORT-TEMPLATE.md` |
| Improvement entries | `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md` |

---
name: task-lifecycle
description: "Single canonical source of truth for how tasks flow through the system. Covers task IDs, the state-update contract, agent delegation rules, the code-quality pipeline, and improvements/learning. Referenced by Bishop, commands, and doc-writer."
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

### Three Kinds Of Not Done

When you check a tracker against what's actually on disk, three different things look identical if you file them all as "not started". Name them apart:

- **not done** — planned, then deferred or never begun.
- **done but untracked** — the step finished and the code is there, but its state-sync never happened. A gap in the ceremony, not in the work.
- **never in plan** — code on disk with no step in `PROGRESS.md` or `CONTEXT.md` that accounts for it. Delivery nobody recorded.

The three have different fixes. Collapsing them into one label loses the only information that tells you which fix applies.

---

## Task IDs

Every `/start-task` run gets its own ID, shaped **`task-YYYYMMDD-NN`**:

- `YYYYMMDD` — the day the task was created, in **UTC**. Same clock as the timestamps in `EVENT-LOG.md` and `DONE-LOG.md`, so nothing has to be converted to work out the sequence.
- `NN` — a zero-padded counter **scoped to that UTC day**. Starts at `01`, goes up by one per task created that day, and resets to `01` when the UTC date rolls over.

So: `task-20260711-01` → `task-20260711-02` (same UTC day) → `task-20260712-01` (next day, reset).

### Working Out The Next One

Bishop derives the ID before delegating anything, and does it deterministically:

1. `date` = today's UTC date as `YYYYMMDD`.
2. Find the highest `NN` already taken for `date`, looking at **both**:
   - folders matching `.claude/memory/tasks/task-<date>-*`, and
   - rows mentioning `task-<date>-*` in `.claude/memory/state/EVENT-LOG.md` and `.claude/memory/state/DONE-LOG.md`.
3. `NN` = highest found + 1. Nothing found for `date` means `NN` = `01`. Zero-pad to two digits.

**Why both places.** Stale-task cleanup deletes finished task folders, but `EVENT-LOG.md` and `DONE-LOG.md` are append-only and keep the record. Checking the logs as well as the folders is what guarantees a retired ID never comes back around — a reused ID makes the audit trail ambiguous, which is the one thing the journal exists to prevent. On a day that somehow passes 99 tasks, carry on with three digits (`100`, `101`, …).

The ID belongs to Bishop, not to the agent creating the folder. Nobody invents their own scheme.

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

`.claude/memory/state/EVENT-LOG.md` is the primary continuity record and the source of truth for a task's history. One row per state-sync delegation. Schema is in `.claude/templates/state/STATE-FILE-TEMPLATE.md` — Timestamp | Task ID | Step | Agent | Event | Note. Event is `step-sync`, timestamp is the moment of the sync in `YYYY-MM-DD HH:MM UTC`, Note carries brief context. It isn't a side note; it's the record.

### Checking The Row You Just Wrote

A corrupt journal row is worse than a missing one — it reads as history. So after appending to `EVENT-LOG.md`, @doc-writer re-reads the row it just wrote and confirms four things:

1. **Both pipes are there.** The row starts with `|` and ends with `|`. A row missing its leading or trailing pipe isn't a table row at all, and counting cells will not catch it.
2. **Exactly six cells.** Split on `|` and count: Timestamp, Task ID, Step, Agent, Event, Note. More than six means an unescaped `|` got into the Note and split the cell. Fix it now.
3. **The timestamp is whole.** Exactly `YYYY-MM-DD HH:MM UTC`, 24-hour. A bare date with no time (`2026-07-24 UTC`) is invalid. Never invent a time, never estimate one, never carry one forward from earlier in the conversation — a fabricated timestamp in an audit journal does more damage than a visible gap.
4. **Time moves forward.** The new row's timestamp is greater than or equal to the row above it. If it's earlier, the row was inserted into the middle of the file rather than appended, and the journal's ordering — the only thing making it a journal — is broken.

That check is reported as part of the sync confirmation. A failed check gets corrected and re-verified before the sync is called done.

**One tool constraint.** Append the row with Write or Edit — never a shell heredoc. A heredoc writes `\|` as a literal backslash followed by a pipe, which defeats the escape, splits the cell, and produces exactly the corruption the escape existed to stop.

### Timing

| Trigger | What happens |
|---------|--------------|
| **Task start** — before step 1 of a genuinely new task | Build `tasks/task-[id]/CONTEXT.md` and `PROGRESS.md` from `.claude/templates/task/TASK-TEMPLATE.md`, copied exactly — same headings, order, structure. Fill in the planned-step rows in `PROGRESS.md`; the plan lives there. Initialize `ACTIVE-TASK.md` with the new task id and status `in-progress`. Confirm `EVENT-LOG.md` exists. Clear `.claude/memory/agent-documents/` — but only once you've confirmed the previous task is complete or deliberately replaced, and clear it in the sense defined under The Scratch Workspace below: archive, don't delete. That item needs a shell, so it only goes to an agent whose `tools:` allowlist grants Bash. |
| **After EVERY numbered step** | Hand a state-sync to @doc-writer: append the EVENT-LOG.md row, update the ACTIVE-TASK.md pointer, mark the step done in PROGRESS.md. All three, one delegation. Mandatory — and handed over **in the same turn as the step report that triggered it**. A sync mentioned in a closing sentence and left for the next turn has been skipped, not started. The step went to `in-progress` when its brief was delegated; the sync is what marks it `done`. |
| **Operator-injected step** — scope the operator adds mid-task | The PROGRESS.md row goes in **before** the work is delegated: status `in-progress`, note `(operator-directed, injected HH:MM UTC)`. From there it takes the same per-step sync as anything else. A row backfilled afterwards is a record repaired rather than a record kept — for the whole time the work was in flight, the state on disk didn't mention it. Urgency is the reason to write the row, not the excuse for skipping it; it costs one delegation. |
| **Step resumed mid-flight** — picked up from an agent's transcript rather than restarted | The resuming agent opens with a state report saying what it had and hadn't written to disk before the interruption. The step isn't synced done until that report exists, or the next step has to work it out from scratch. |
| **Task completion** — after the final step | Run the learning pass (BLOCKING). Only then set `ACTIVE-TASK.md` to complete. Only then append to `DONE-LOG.md`. |

### The Sync Rewrites; It Doesn't Copy

The ACTIVE-TASK.md update is a rewrite of what has stopped being true, not a transcription of the previous version with a new timestamp.

Any sentence anywhere in the file describing something as outstanding, pending, awaiting a decision, or blocked gets re-checked against what the intervening steps actually did, and rewritten or removed where they closed it. Finishing the work does not update the sentence calling it unfinished. A sentence carried forward unchanged invites the next reader to re-decide something already settled — and because it sits in the state file, it reads as authoritative while being wrong. Say so in the sync delegation, so the receiver performs the re-check instead of copying the text.

### The Scratch Workspace

- During a task, any agent may create, update, edit, delete, and organise files under `.claude/memory/agent-documents/`.
- The structure inside it is deliberately unconstrained.
- It's temporary and scoped to the task: drafts, checklists, scratch notes, analysis, review write-ups while work is in flight.
- When the active task is `in-progress` or `blocked`, everything in there survives across sessions and counts as valid context on resume.
- The canonical files stay canonical regardless: `PROGRESS.md` (plan and step status), `ACTIVE-TASK.md` (live pointer), `EVENT-LOG.md` (continuity record).
- Clearing happens only at confirmed new-task initialization, and **clearing means archiving**: keep `.gitkeep` and `README.md` in place, **move** every other `.md` file into `.claude/memory/agent-documents/archive-task-[id]/`, then recreate `improvement-scratch.md` with a fresh header. Nothing is deleted — a workspace file is sometimes the only copy of a deliverable that never shipped. The evidence that this ran is the `ls -la` of the directory afterwards, returned with the confirmation. A claim on its own doesn't satisfy it.

### Where Things Live

Putting a file in the wrong directory breaks the contract. The mapping:

| Artifact | Where it goes |
|----------|---------------|
| Session checkpoints, handoff notes, scratch analysis, review drafts, `improvement-scratch.md` | `.claude/memory/agent-documents/` — temporary, archived at new-task init |
| Live pointer, audit journal, finished-task index | `.claude/memory/state/` — **only** `ACTIVE-TASK.md`, `EVENT-LOG.md`, `DONE-LOG.md` |
| Task plan and status, context, completion report | `.claude/memory/tasks/task-[id]/` — `PROGRESS.md`, `CONTEXT.md`, `DONE-REPORT.md` |
| Improvement findings, patterns, agent calibration notes | `.claude/memory/improvements/` — `IMPROVEMENTS.md`, `PATTERNS.md`, `agent-notes/<name>.md` |
| Binding human-ratified conventions | `.claude/memory/reference/CONVENTIONS.md` — human-edited only |

- **`state/` is a closed directory.** The three canonical state files, plus machine-written harness state produced by a hook registered in `.claude/settings.json`. Nothing else, ever — no checkpoints, session notes, drafts, or reports. An agent cannot bring a file into scope simply by writing it there. The full allowlist is in `.claude/templates/state/STATE-FILE-TEMPLATE.md`. A checkpoint or handoff note belongs in `agent-documents/`, referenced from the active task's `CONTEXT.md` so resume can find it.
- **Rules never live inside the folder they describe.** How the system works belongs in agents, skills, and templates. A doctrine file written into `memory/` — `agent-documents/` especially — gets archived at the next task init, and the rule goes with it.

### The Rule

> When a numbered step finishes, Bishop delegates a state-sync to @doc-writer in the same turn as the step report, and before calling the next sub-agent. No exceptions, no batching, no skipping, no saving it for the end, and no leaving it for the next turn.

If Bishop can't open a state file and see the current position in the plan, the contract is already broken.

### The Blocking Gate

- Bishop does not delegate the next step until the sync has succeeded.
- A sync that's missing, partial, malformed, or stale sets the task to `blocked` and stops execution until it's fixed.
- One catch-up write at the end does not retroactively satisfy the syncs that were skipped.

### Validating A Sync

All of this has to hold before execution continues:

1. EVENT-LOG.md row appended (event=step-sync), matching the STATE-FILE-TEMPLATE schema: Timestamp | Task ID | Step | Agent | Event | Note — and passing the four post-write checks above.
2. ACTIVE-TASK.md updated — task id, status, owner, next action, last-updated (`YYYY-MM-DD HH:MM UTC`), blockers — with stale prose rewritten rather than carried forward.
3. PROGRESS.md step table — the finished step marked `done`. The next step is already `in-progress`; it was set that way when its brief went out.
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
| task-[id] | YYYY-MM-DD HH:MM UTC | done|failed | [concise summary]                                                   |
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

**Sync the findings before the fix round starts.** When a review turns up a CRITICAL and triggers a fix round, the review's *full* findings — the non-blocking WARNINGs and the reasoning behind the decisions, not just the CRITICAL — go into `EVENT-LOG.md` before the fix begins, not afterwards with the re-review. An interruption between the review and the fix otherwise takes the WARNINGs and the context with it, and the re-review has to rediscover them.

---

## Improvements And Learning

### The Chain

Every improvement write follows this path. It's built so the pass can't be quietly skipped — collection forces it, rather than memory being asked to.

1. **Sub-agents** end **every** step-completion report with an `IMPROVEMENT-NOTE:` line, sitting immediately above the `STEP N COMPLETE` line. The value is `none` when there was nothing — valid and expected — or one concrete, actionable observation. A report missing the line is malformed, and Bishop asks for it before syncing.
2. **Bishop** appends each non-`none` note to `.claude/memory/agent-documents/improvement-scratch.md` as the steps land — one line per finding: step, agent, note. `none` values aren't recorded.
3. **Bishop** at completion reads that scratch list, adds its own Bishop-level observations, and applies the Quality Gate in `.claude/skills/self-improvement/SKILL.md` to decide what qualifies.
4. **Bishop delegates** whatever qualifies to `@doc-writer`, naming the file targets and the entry content, per `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md`.
5. **`@doc-writer`** appends. It executes; it doesn't decide what's worth recording.

> **The pass always runs; the writes are conditional.** An empty scratch list — every step reported `none` — means the pass finishes with no file writes, and that's a complete outcome. What's not allowed is skipping the collection or the pass. `improvement-scratch.md` is scratch: it's archived at the next new-task init like anything else in `agent-documents/`.

**A process observation that would change the next brief goes into that brief now.** It doesn't wait for the pass at the end. Ask review and verification steps for process observations mid-task, not only at completion; where one is actionable — a bundled acceptance criterion that should have been two questions, a question phrased so it can't fail — rewrite the next brief and say in it that you did. It still gets appended to the scratch file; the two aren't alternatives. The completion pass can't change an outcome. The next brief can.

### Agent Notes (`improvements/agent-notes/<agent-name>.md`)

- Written only when something noteworthy happened — good or bad.
- Nothing notable means nothing written. No "no issues" entries.
- Either self-reported (the agent noting its own behaviour) or bishop-observed (Bishop noting it). Both valid — set `Source` accordingly.
- Written at completion, during the learning pass delegation.

### IMPROVEMENTS.md

- Written at **completion only**.
- The findings ledger: specific, observed findings, one entry per observation. May cite code, paths, and symbols.
- Concrete and actionable — a change to a prompt, a skill, a tool, or a candidate convention. Nothing vague.
- Has to clear the Quality Gate in `.claude/skills/self-improvement/SKILL.md`.
- A single occurrence is enough. You don't need to see something twice before recording it.
- Nothing to report means no write. No empty entries, no placeholders.
- `Status` belongs to the human operator (`proposed` → `approved` → `applied`, with `rejected`, `retired`, and `superseded` as terminal branches). No agent sets it, changes it, or touches `Approver`/`Date approved`.

### PATTERNS.md

- Written at **completion only**.
- Reusable solutions, architecture decisions, and technical approaches. Advisory and non-binding — `CONVENTIONS.md` wins on any conflict.
- Has to clear the Quality Gate.
- Nothing to report means no write.

### When The Same Finding Keeps Coming Back

A finding logged three or more times is telling you something the ledger can't fix. It means an agent or skill definition has a hole in it, not that a convention is missing. Fix the definition — don't log the finding a fourth time.

That fix is a **proposal, not an edit**. Agent and skill definitions are human-ratified, exactly like `CONVENTIONS.md`. An agent that spots a definition-level hole records the proposal and puts it in front of the operator; it does not amend the definition mid-task.

### The Rule

> The learning pass runs at the end of every task, without exception. Files get written only where findings are concrete, actionable, and clear the Quality Gate. Empty, vague, or placeholder entries are forbidden.

---

## The Conventions Contract

`.claude/memory/reference/CONVENTIONS.md` holds binding conventions that a human ratified — generalised practices and methodologies, not only coding rules. Every entry exists to prevent a **class** of problem, never the single instance that prompted it. It sits deliberately outside the improvement loop:

- **Read before acting.** `@jnr-developer`, `@snr-developer`, and `@code-reviewer` read every entry whose **Applies when** trigger their change satisfies — before writing or reviewing — and comply.
- **Binding beats advisory.** On any conflict, `CONVENTIONS.md` (ratified) overrides `PATTERNS.md` (observed).
- **Agents never write to it.** A discovered convention is proposed through `IMPROVEMENTS.md` as `proposed`; a human ratifies it across. That is the only path, under any circumstances.
- **Reviewer enforces it.** `@code-reviewer` tests the change against the `Reviewer check` of every triggered `active` entry. A violation is CRITICAL.
- **No match gets reported too.** When a change triggers **no** `active` entry, `@code-reviewer` says so explicitly — describing the change and stating that nothing covered it. That's a coverage gap, not a violation: never CRITICAL, never blocking. It exists so "passed because nothing applied" reads differently from "passed because it complied". An unmatched change is a candidate for a new convention through the proposal path, and silence is how that candidate disappears into an apparently clean review.
- **Not an improvement.** Ratified conventions aren't logged as rules in `IMPROVEMENTS.md` or `PATTERNS.md`. Only the human-ratification path adds to `CONVENTIONS.md`.

---

## Starting A Task — Checklist

Bishop derives the task ID first (see Task IDs above), then confirms all of this, via delegation to @doc-writer:

1. [ ] `.claude/memory/agent-documents/` cleared in the archive sense — `.gitkeep` and `README.md` kept, every other `.md` moved to `archive-task-[id]/`, `improvement-scratch.md` recreated with a fresh header — and proven by a returned `ls -la` of the directory. A stated claim without the listing doesn't satisfy this item, and it only goes to an agent whose `tools:` allowlist grants Bash.
2. [ ] `.claude/memory/tasks/task-[id]/CONTEXT.md` built from `.claude/templates/task/TASK-TEMPLATE.md`, exactly. Every path written into `Key Files` confirmed to exist as it's written; a path that doesn't exist yet is marked `— to be created at step N`, never left bare. A wrong path in canonical task state is invisible guidance — later agents assume the documented structure is right and nobody questions it.
3. [ ] `.claude/memory/tasks/task-[id]/PROGRESS.md` built from the same template, exactly, with the step table filled in for every planned step
4. [ ] `state/ACTIVE-TASK.md` initialized — new task id, status `in-progress`, owner, next action
5. [ ] `state/EVENT-LOG.md` present and ready for the first append

All five confirmed before the first numbered step runs.

---

## Closing A Task — Checklist

Once every step is done, in this exact order:

1. [ ] Final state-sync (last step marked done, EVENT-LOG row appended with event=step-sync)
2. [ ] Closing summary written for the operator
3. [ ] **Tracker-and-reality check (BLOCKING):** diff every canonical tracker the task touched — a project `progress.md`, a README status table, anything that claims what's done — against what's actually on disk. Drift either way is a blocking discovery: code present with no completed step, or a tracker claiming completion with the code missing. Sync the tracker before closing, or record the drift explicitly in `DONE-REPORT.md` using the three kinds of not done from Terms above.
4. [ ] **Learning pass run (BLOCKING — you cannot skip it):**
   - 4a. [ ] Bishop reads `.claude/memory/agent-documents/improvement-scratch.md` — the notes collected as the steps ran. That list *is* the input; the pass consolidates it rather than recalling it.
   - 4b. [ ] Bishop reviews its own observations — Bishop-level patterns, agent behaviour, delegation and skill gaps
   - 4c. [ ] Anything concrete? Delegate the writes to `@doc-writer` with named file targets and entry content, per `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md`, all applicable files in one delegation
   - 4d. [ ] `@doc-writer` appends to `IMPROVEMENTS.md`, `PATTERNS.md`, and/or `agent-notes/[name].md` as applicable
   - Nothing found? The pass is complete. No delegation, no writes.
5. [ ] `tasks/task-[id]/DONE-REPORT.md` written by `@doc-writer` from `.claude/templates/task/DONE-REPORT-TEMPLATE.md`
   - Mandatory sections: wrong assumptions, and per-agent mistakes with corrective actions
   - Written once at completion — not maintained as a rolling log
   - Applies to active and newly finished tasks only. No retroactive backfill unless asked.
6. [ ] `state/ACTIVE-TASK.md` set to `complete`, Next Action set to `none` (the completion-gate hook checks DONE-REPORT.md exists)
7. [ ] EVENT-LOG row appended with event=complete (schema in STATE-FILE-TEMPLATE.md)
8. [ ] Row appended to `state/DONE-LOG.md`
   - Append-only, columns exactly `Task ID | Completed | Outcome | Summary`
9. [ ] Every logical step confirmed to have sync evidence before the task closes

### The Closing Gate

Bishop does not mark `ACTIVE-TASK.md` complete or append to `DONE-LOG.md` until the tracker-and-reality check (3), the learning pass (4), and `DONE-REPORT.md` (5) have all run. Skip or defer any of the three and the task stays `in-progress` and cannot close. This is as serious as skipping a per-step sync.

### The Hooks

Two POSIX-sh hooks in `.claude/hooks/`, wired up in `.claude/settings.json`, enforce continuity mechanically:

- **completion-gate.sh** (PreToolUse, HARD BLOCK) — refuses to let `ACTIVE-TASK.md` go to `complete` unless the task's `DONE-REPORT.md` exists. The mechanical backstop to the closing checklist, and the only hook that blocks a close.
- **state-continuity.sh** (PostToolUse, WARN ONLY) — warns when `EVENT-LOG.md` hasn't advanced for the active task. Advisory. Never blocks.

Both are reversible. They back up the written rules; they don't replace them.

---

## What A Plan Looks Like

```
Plan for task-20260711-01:
1. @jnr-developer — Create authentication module
   → [state-sync delegation to @doc-writer]
2. @code-reviewer — Review authentication module
   → [state-sync delegation to @doc-writer]
3. @jnr-developer — Fix any CRITICAL issues from review
   → [state-sync delegation to @doc-writer]
4. @doc-writer — Update README with auth docs
   → [state-sync delegation to @doc-writer]
Close: summary → tracker check → learning pass (BLOCKING) → DONE-REPORT (BLOCKING) → ACTIVE-TASK complete → DONE-LOG
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
│ Task ID → archive scratch → CONTEXT →   │
│ PROGRESS → ACTIVE-TASK → EVENT-LOG      │
│ ⚠️ All 5 confirmed before step 1        │
└─────────────────────┬───────────────────┘
                      │ confirmed
                      ▼
┌─────────────────────────────────────────┐
│ EXECUTION LOOP (every step)             │
│ A.Hand out → B.Read → C.Sync →          │
│ D.Confirm → E.Continue                  │
│ ⚠️ The sync blocks the next step        │
│ ⚠️ Same turn as the step report         │
│                                         │
│ Code step? → CODE-QUALITY PIPELINE      │
└─────────────────────┬───────────────────┘
                      │ all steps done
                      ▼
┌─────────────────────────────────────────┐
│ CLOSING GATE                            │
│ A.Summary → B.Tracker check →           │
│ C.Learning pass → D.DONE-REPORT →       │
│ E.Mark complete → F.Append DONE-LOG     │
│ ⚠️ B, C and D all block the close       │
└─────────────────────────────────────────┘
```

---

## Everything That Blocks

| Checkpoint | Kind | What it stops |
|------------|------|---------------|
| @jnr-developer on every initial code step | Hard rule | Plan INVALID otherwise |
| @code-reviewer directly after every code step | Hard rule | Plan INVALID otherwise |
| @snr-developer absent from the initial plan | Hard rule | Plan INVALID otherwise |
| Task ID derived as `task-YYYYMMDD-NN` from folders *and* logs | Hard rule | A reused ID makes the audit trail ambiguous |
| All 5 initialization items confirmed | Blocking gate | Step 1 can't start |
| State-sync after each step, in the same turn | Blocking gate | Next step can't start |
| 3-target sync validation (EVENT-LOG + ACTIVE-TASK + PROGRESS) | Blocking gate | Execution can't continue |
| EVENT-LOG row re-read and verified after append | Blocking gate | Sync can't be reported complete |
| 2 junior fix rounds maximum | Escalation rule | Must go to @snr-developer |
| 2 senior fix rounds maximum | Escalation rule | Must go to the operator |
| Tracker-and-reality check at completion | Blocking gate | Task can't close |
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
| Convention entries (format scaffold) | `.claude/templates/reference/CONVENTIONS-TEMPLATE.md` |

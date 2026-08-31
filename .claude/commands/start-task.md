---
description: Start a structured task with scope, plan, and assignments
argument-hint: <task request>
---

> **You are running as Bishop.** The primary agent executes this under `.claude/agents/bishop.md`. Every piece of implementation goes out to a specialist through the Task tool.

> **Full rules**: `.claude/skills/task-lifecycle/SKILL.md` covers every phase below in detail.

## ⚠️ THE EXECUTION LOOP — MANDATORY ⚠️

Every logical step in the plan runs through this exact sequence:

```
A. HAND the step to the named sub-agent.
   Set the step to `in-progress` in PROGRESS.md as part of handing it out.
   In the brief: "When done, end output with two lines:
   IMPROVEMENT-NOTE: none | <one concrete, actionable observation>
   STEP [N] COMPLETE — state-sync required."

B. READ what comes back. Satisfy yourself the step is done.
   Non-`none` IMPROVEMENT-NOTE → append it (step, agent, note) to
   `.claude/memory/agent-documents/improvement-scratch.md` before moving on.

C. HAND state-sync to @doc-writer straight away — in the SAME TURN as the
   step report. A sync promised in a closing sentence and left for the next
   turn counts as skipped.
   "State-sync for step [N]. Update PROGRESS.md (mark step [N] done),
   ACTIVE-TASK.md (Next Action — rewriting any sentence the intervening steps
   made untrue, not copying it forward), and append one EVENT-LOG.md row
   (event=step-sync, timestamp YYYY-MM-DD HH:MM UTC, read back and verified).
   Confirm all three sync targets + step number."

D. READ the confirmation — all three targets, the step number, and the
   EVENT-LOG row read-back.
   Missing or partial means the task is BLOCKED. STOP.

E. ONLY THEN move to step N+1.
```

Nothing batched. Nothing deferred. No "I'll write it up at the end." Every step gets its own sync.

A step the operator injects mid-task gets its PROGRESS.md row — `in-progress`, noted `(operator-directed, injected HH:MM UTC)` — **before** the work goes out, then runs A–E unchanged.

---

## PROGRESS.md Shape

At initialization, build both `CONTEXT.md` and `PROGRESS.md` from `.claude/templates/task/TASK-TEMPLATE.md`, copied exactly. Then fill `PROGRESS.md` with a row per planned step.

```markdown
# Progress — task-[id]

| Step | Phase | Agent | Status | Notes |
|------|-------|-------|--------|-------|
| 1 | [phase or —] | @agent-name | pending | [description] |
| 2 | [phase or —] | @agent-name | pending | [description] |
```

Statuses run `pending` → `in-progress` → `done` | `failed`. A step becomes `in-progress` when its brief is delegated, not afterwards. `Phase` groups steps under a phase label; unphased tasks use `—`.

---

## Running The Task

1. Restate the goal and set out what "done" actually means.
2. Name the risks, dependencies, and assumptions you're working under.
3. Write a numbered plan. Every step names the sub-agent who owns it.
4. **Delegation constraint (mandatory):** every coding step goes to `@jnr-developer`. `@snr-developer` never appears in an initial plan — it's reached only through the Code-Quality Pipeline, after 2 failed junior fix rounds. A plan that puts `@snr-developer` on a coding step is INVALID; rewrite it.
5. Any step that writes or changes code is followed immediately by `@code-reviewer`. No exceptions.
6. Derive the task ID yourself: `task-YYYYMMDD-NN` — today's UTC date, plus a counter that resets daily. Take the highest `NN` already used for that date across both the `tasks/task-<date>-*` folders and the rows mentioning them in `EVENT-LOG.md` and `DONE-LOG.md`, and add one; `01` if there are none. Folders get cleaned up, the logs don't — check both so an ID never comes back around.
7. Hand task initialization to `@doc-writer`, passing the derived ID: archive agent-documents (keep `.gitkeep` and `README.md`, move the rest to `archive-task-[id]/`, recreate `improvement-scratch.md`, return `ls -la` as evidence), build CONTEXT.md and PROGRESS.md from TASK-TEMPLATE.md exactly, initialize ACTIVE-TASK, confirm EVENT-LOG.md is present. **All five confirmed before step 1 runs.**
8. Agents may use `.claude/memory/agent-documents/` as scratch space during execution. Preserve it when resuming an unfinished task; clear it only on confirmed new-task bootstrap, and clearing means archiving — nothing there is deleted.
9. Work the plan through the execution loop above.
10. Closing the task — **in this exact order**. The tracker check, the learning pass, and DONE-REPORT are prerequisites, not formalities:
   - Write a closing summary of what changed, for the operator.
   - **Tracker check (BLOCKING)**: diff every canonical tracker the task touched against what's actually on disk. Drift either way — code with no completed step, or a tracker claiming work the disk doesn't have — is either synced before closing or recorded in DONE-REPORT.md as not done / done but untracked / never in plan.
   - **Learning pass (BLOCKING)**: read `.claude/memory/agent-documents/improvement-scratch.md` — the notes collected as the steps ran — and add your own Bishop-level observations. Something concrete? Hand it to `@doc-writer` with named file targets and entry content, formatted per `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md`. Nothing concrete? The pass is done; write nothing.
   - **Then, and only then, create `tasks/task-[id]/DONE-REPORT.md` (BLOCKING)** via `@doc-writer`, from `.claude/templates/task/DONE-REPORT-TEMPLATE.md`. Get confirmation that the mandatory sections are there — "Wrong Assumptions" and "Sub-Agent Mistakes and Corrections". The completion-gate hook refuses to let the task close without this file.
   - Only after the report exists: mark `ACTIVE-TASK.md` complete.
   - Only after that: append one `DONE-LOG.md` row at the end (append-only, columns exactly `Task ID | Completed | Outcome | Summary`, outcome `done|failed`) and one `EVENT-LOG.md` row with event `complete`. Enforcement detail is in `.claude/skills/task-lifecycle/SKILL.md`.
   - **If you break the order** — marking complete, appending DONE-LOG, or skipping the report before the tracker check, the learning pass, and DONE-REPORT have run — the task is not done. Go back and run them.

Keep the output tight and ready to act on.

Start a new task for this project from the following request:
$ARGUMENTS

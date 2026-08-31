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
   In the brief: "When done, end output with: STEP [N] COMPLETE — state-sync required."

B. READ what comes back. Satisfy yourself the step is done.

C. HAND state-sync to @doc-writer straight away:
   "State-sync for step [N]. Update PROGRESS.md (mark step [N] done),
   ACTIVE-TASK.md (Next Action), and append one EVENT-LOG.md row (event=step-sync).
   Confirm all three sync targets + step number."

D. READ the confirmation — all three targets plus the step number.
   Missing or partial means the task is BLOCKED. STOP.

E. ONLY THEN move to step N+1.
```

Nothing batched. Nothing deferred. No "I'll write it up at the end." Every step gets its own sync.

---

## PROGRESS.md Shape

At initialization, build both `CONTEXT.md` and `PROGRESS.md` from `.claude/templates/task/TASK-TEMPLATE.md`, copied exactly. Then fill `PROGRESS.md` with a row per planned step.

```markdown
# Progress — task-[id]

| Step | Agent | Status | Notes |
|------|-------|--------|-------|
| 1 | @agent-name | pending | [description] |
| 2 | @agent-name | pending | [description] |
```

Statuses run `pending` → `in-progress` → `done` | `failed`.

---

## Running The Task

1. Restate the goal and set out what "done" actually means.
2. Name the risks, dependencies, and assumptions you're working under.
3. Write a numbered plan. Every step names the sub-agent who owns it.
4. **Delegation constraint (mandatory):** every coding step goes to `@jnr-developer`. `@snr-developer` never appears in an initial plan — it's reached only through the Code-Quality Pipeline, after 2 failed junior fix rounds. A plan that puts `@snr-developer` on a coding step is INVALID; rewrite it.
5. Any step that writes or changes code is followed immediately by `@code-reviewer`. No exceptions.
6. Hand task initialization to `@doc-writer`: clear agent-documents, build CONTEXT.md and PROGRESS.md from TASK-TEMPLATE.md exactly, initialize ACTIVE-TASK, confirm EVENT-LOG.md is present. **All five confirmed before step 1 runs.**
7. Agents may use `.claude/memory/agent-documents/` as scratch space during execution. Preserve it when resuming an unfinished task; clear it only on confirmed new-task bootstrap.
8. Work the plan through the execution loop above.
9. Closing the task — **in this exact order**. The learning pass and DONE-REPORT are prerequisites, not formalities:
   - Write a closing summary of what changed, for the operator.
   - **Learning pass (BLOCKING)**: gather improvement reports from the sub-agents — they attach findings to their step reports when they have something and stay quiet otherwise — and add your own Bishop-level observations. Something concrete? Hand it to `@doc-writer` with named file targets and entry content, formatted per `.claude/templates/improvement/IMPROVEMENT-TEMPLATE.md`. Nothing concrete? The pass is done; write nothing.
   - **Then, and only then, create `tasks/task-[id]/DONE-REPORT.md` (BLOCKING)** via `@doc-writer`, from `.claude/templates/task/DONE-REPORT-TEMPLATE.md`. Get confirmation that the mandatory sections are there — "Wrong Assumptions" and "Sub-Agent Mistakes and Corrections". The completion-gate hook refuses to let the task close without this file.
   - Only after the report exists: mark `ACTIVE-TASK.md` complete.
   - Only after that: append one `DONE-LOG.md` row at the end (append-only, columns exactly `Task ID | Completed | Outcome | Summary`, outcome `done|failed`) and one `EVENT-LOG.md` row with event `complete`. Enforcement detail is in `.claude/skills/task-lifecycle/SKILL.md`.
   - **If you break the order** — marking complete, appending DONE-LOG, or skipping the report before the learning pass and DONE-REPORT have run — the task is not done. Go back and run them.

Keep the output tight and ready to act on.

Start a new task for this project from the following request:
$ARGUMENTS

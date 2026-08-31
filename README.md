# Bishop Harness

A small crew of AI agents with a chain of command, for Claude Code.

One agent is in charge. **Bishop** plans the work, hands each piece to whoever should own it, checks what comes back, and closes the loop — and never writes a line of code. Everything else is done by specialists: a junior who builds, a reviewer who checks, a senior held in reserve, and a writer who keeps the docs and the state files straight.

The point is not the roleplay. It's that work gets planned before it gets built, reviewed before it ships, and written down as it goes — so a session can be interrupted and picked up later without anyone reconstructing what was happening.

Bishop's character and rules live in [`.claude/SOUL.md`](.claude/SOUL.md). The operating instructions are in [`.claude/agents/bishop.md`](.claude/agents/bishop.md).

> Installing the harness into your other repos is covered separately in [INSTALL.md](INSTALL.md).

## Contents

- [The Crew](#the-crew)
- [Getting Set Up](#getting-set-up)
  - [What you need](#what-you-need)
  - [Install Claude Code](#install-claude-code)
  - [Start it here](#start-it-here)
  - [Log in](#log-in)
  - [Check the crew loaded](#check-the-crew-loaded)
- [Using It From VS Code](#using-it-from-vs-code)
- [Running Work Through It](#running-work-through-it)
- [Memory](#memory)
  - [Rebuilding it from memory.zip](#rebuilding-it-from-memoryzip)
  - [What lives where](#what-lives-where)
  - [The three state files](#the-three-state-files)
  - [Inside a task folder](#inside-a-task-folder)
  - [Finding your way around mid-task](#finding-your-way-around-mid-task)
  - [Current, failed, and finished work](#current-failed-and-finished-work)
  - [What sticks around](#what-sticks-around)
  - [Project conventions](#project-conventions)
- [When Things Don't Work](#when-things-dont-work)

## The Crew

| Agent | Job |
|-------|-----|
| **Bishop** (`@bishop`) | In command. Frames the work, delegates it, checks it, closes it. Writes no code. |
| `@jnr-developer` | Builds. Every coding step starts here, whatever the task looks like. |
| `@code-reviewer` | Reads every diff. Reports findings, never rewrites. Runs after each coding step. |
| `@snr-developer` | In reserve. Steps in only after the junior has failed two fix rounds on the same critical issue. |
| `@doc-writer` | Documentation, plus every update to the state files. |

Bishop loads automatically from [`CLAUDE.md`](CLAUDE.md) at the repo root. The rest sit in [`.claude/agents/`](.claude/agents/) and get called through the Task tool.

That third row is the one people query. The senior developer is deliberately not available for planning — you can't assign work to it, and neither can Bishop. It only appears when the normal path has demonstrably failed twice. That constraint is what stops "this looks hard" turning into an excuse to skip the pipeline.

## Getting Set Up

### What you need

- Node.js 18+ if you're installing through npm
- A Claude account (Pro or Max), or an Anthropic API key
- The Claude Code CLI

### Install Claude Code

**npm, any platform**

```bash
npm install -g @anthropic-ai/claude-code
```

**macOS and Linux**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows, PowerShell**

```powershell
irm https://claude.ai/install.ps1 | iex
```

Then check it took:

```bash
claude --version
claude doctor
```

`claude doctor` runs a full health check and is worth knowing about — it's the first thing to reach for when something's off.

### Start it here

```bash
cd /path/to/bishop-harness
claude
```

### Log in

Inside Claude Code:

1. `/login`
2. Sign in with your Claude account, or paste an API key
3. Done

Once per machine. After that the session comes back on its own.

### Check the crew loaded

```text
/agents
```

You're looking for `bishop`, `jnr-developer`, `code-reviewer`, `snr-developer`, and `doc-writer`. Or just ask:

```text
@bishop report crew status
```

## Using It From VS Code

1. Install the Claude Code extension from the Marketplace.
2. Open this repo.
3. Run `claude` in the integrated terminal from the repo root, or use the Claude Code panel.
4. Carry on as normal — Bishop is already running things.

## Running Work Through It

There's one way in:

```text
/start-task <what you want done>
```

Bishop restates the goal, writes a numbered plan, sends every coding step to `@jnr-developer` with a `@code-reviewer` step directly behind it, and syncs state to disk after **every** step. Stop halfway through and the next session picks up exactly where you left off.

The rules are written down once, in [`.claude/skills/task-lifecycle/SKILL.md`](.claude/skills/task-lifecycle/SKILL.md). If anything else in the repo contradicts that file, that file wins.

Three constraints don't bend:

1. Every coding step goes to `@jnr-developer`, no matter how the task looks.
2. Every coding step is followed immediately by `@code-reviewer`.
3. `@snr-developer` never appears in an initial plan. It arrives by escalation or not at all.

## Memory

`.claude/memory/` is what makes a task resumable. `CLAUDE.md` is the entry point; it pulls in `.claude/SOUL.md`, `.claude/AGENT-INDEX.md`, and `.claude/agents/bishop.md`. Two hooks in `.claude/hooks/` (`completion-gate.sh`, `state-continuity.sh`) enforce the continuity rules mechanically, so it isn't purely a matter of the model remembering to.

### Rebuilding it from memory.zip

If `.claude/memory/` goes missing, or you want it back to a clean state:

```bash
cd .claude
unzip -o memory.zip
```

### What lives where

| Folder | What it's for | How long it lasts | Contents |
|--------|---------------|-------------------|----------|
| `.claude/memory/state/` | The canonical state used to resume exactly where work stopped | Permanent | `ACTIVE-TASK.md`, `EVENT-LOG.md`, `DONE-LOG.md` |
| `.claude/memory/tasks/` | One folder per task | Permanent, though Bishop prunes stale ones | `task-[id]/CONTEXT.md`, `PROGRESS.md`, `DONE-REPORT.md` |
| `.claude/memory/agent-documents/` | Scratch space the crew uses mid-task | Temporary — survives across sessions while a task is unfinished, cleared when a new one starts | drafts, review notes, working docs |
| `.claude/memory/improvements/` | What the crew learned, and patterns worth reusing | Permanent | `IMPROVEMENTS.md`, `PATTERNS.md`, `agent-notes/` |
| `.claude/memory/reference/` | Binding coding conventions, ratified by a human | Permanent | `CONVENTIONS.md` |

### The three state files

- `ACTIVE-TASK.md` — the single answer to "what's happening right now": task id, status (`not-started` / `in-progress` / `blocked` / `complete`), next action, blockers.
- `EVENT-LOG.md` — an append-only journal, one row per sync. This is the record that matters for continuity.
- `DONE-LOG.md` — append-only history of finished work: `Task ID | Completed | Outcome | Summary`.

### Inside a task folder

Every `.claude/memory/tasks/task-[id]/` holds:

- `CONTEXT.md` — the goal, the acceptance criteria, the relevant files, and any notes.
- `PROGRESS.md` — step by step status per agent: `pending` → `in-progress` → `done` / `failed`.
- `DONE-REPORT.md` — written at the end: what shipped, what was assumed wrongly, what the crew got wrong and how it was corrected.

### Finding your way around mid-task

```bash
# What's happening right now
cat .claude/memory/state/ACTIVE-TASK.md

# The journal
cat .claude/memory/state/EVENT-LOG.md

# The active task itself
ls .claude/memory/tasks
cat .claude/memory/tasks/task-007/CONTEXT.md
cat .claude/memory/tasks/task-007/PROGRESS.md

# If it's in-progress or blocked, look at the scratch space before anything else
ls .claude/memory/agent-documents

# What's been finished
cat .claude/memory/state/DONE-LOG.md
```

### Current, failed, and finished work

- **Current** — `ACTIVE-TASK.md`, the `Task ID` and `Status` fields.
- **Blocked or failed** — `ACTIVE-TASK.md` showing `blocked`, with the blocker written out, plus the failed rows in that task's `PROGRESS.md`.
- **Finished** — the rows in `DONE-LOG.md`, each with an `Outcome` of `done` or `failed`.

### What sticks around

- `state/` and `tasks/` are the durable trail. That's the audit record.
- `agent-documents/` is scratch by design, but it survives across sessions while a task is unfinished.
- `improvements/` is long-term. Don't treat it as somewhere to dump notes.

### Project conventions

`.claude/memory/reference/CONVENTIONS.md` is the **binding, human-ratified** set of coding rules for the project. Every developer and reviewer has to comply with it, and it deliberately sits outside the crew's own learning loop.

| File | Who writes it | How much weight it carries |
|------|---------------|----------------------------|
| `reference/CONVENTIONS.md` | Humans only — agents can read it, nothing more | **Binding.** Agents comply. |
| `improvements/PATTERNS.md` | Agents, from observation | Advisory |
| `improvements/IMPROVEMENTS.md` | Agents propose, a human approves | Suggestions |

Where two disagree, `CONVENTIONS.md` wins.

- **Adding a rule** is a human job. Copy the entry template from [`.claude/templates/reference/CONVENTIONS-TEMPLATE.md`](.claude/templates/reference/CONVENTIONS-TEMPLATE.md), fill in every field, take the next `CONV-NNN`, add an index row, set `Status: active`.
- **Agents read it and comply.** Developers read every entry whose `Scope` covers a file they're touching, before writing anything. The reviewer checks each changed file against that entry's `Reviewer check` — breaking an `active` rule is always a CRITICAL finding.
- **Agents never edit it.** A missing or wrong convention gets proposed through `IMPROVEMENTS.md` as `proposed`, and a human ratifies it across. That's the only route in.
- **Retire, don't delete.** Withdrawing a rule means setting `Status: deprecated`. The `CONV-NNN` ids are permanent and never reused.

It ships empty, seeded from `memory.zip`. Fill it in as conventions actually emerge — an empty file is better than one full of rules nobody agreed to.

## When Things Don't Work

### `claude` isn't found

Open a new terminal first, then:

```bash
claude --version
```

Still nothing?

- **npm install** — check your npm global bin directory is on your `PATH`.
- **Native installer** — reinstall with the one for your platform.
- Either way, `claude doctor` will tell you what's wrong.

### Login problems

Start Claude Code, run `/login`, and go through it again. `claude doctor` also diagnoses auth and config issues.

### The crew isn't there

Make sure you started from the repo root:

```bash
pwd   # should end with /bishop-harness
```

Then restart and look again:

```bash
claude
/agents
```

If they're still missing:

1. Check `.claude/agents/` exists and has all five files in it.
2. Run `claude doctor`.
3. Restart and try `/agents` once more.

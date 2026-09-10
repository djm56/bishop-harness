# Bishop Harness

A small crew of AI agents with a chain of command, for Claude Code.

> "Is this gonna be a stand-up fight, sir, or another bug hunt?" — Private Hudson, *Aliens*

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
  - [Inside a mission folder](#inside-a-mission-folder)
  - [Finding your way around mid-mission](#finding-your-way-around-mid-mission)
  - [Current, failed, and finished work](#current-failed-and-finished-work)
  - [What sticks around](#what-sticks-around)
  - [Project directives](#project-directives)
- [Shared Memory (bishop-memory)](#shared-memory-bishop-memory)
- [When Things Don't Work](#when-things-dont-work)

## The Crew

| Agent | Role | Job | Calling Card |
|-------|------|-----|--------------|
| **Bishop** (`@bishop`) | commander | In command. Frames the work, delegates it, checks it, closes it. Writes no code. | "I keep the record and the sequence honest." |
| `@hicks` | junior developer | Builds. Every coding step starts here, whatever the mission looks like. | "Understood. I'll take it as far as it goes, then tell you where it stopped." |
| `@apone` | code reviewer | Reads every diff. Reports findings, never rewrites. Runs after each coding step. | "I'm not here to make you feel good about it. I'm here to tell you what's wrong with it." |
| `@vasquez` | senior developer | In reserve. Arrives only by escalation, never in the plan. | "You called me. So it's already gone wrong twice." |
| `@lambert` | doc writer | Documentation, plus every update to the state files. | "If it isn't written down, it didn't happen." |

Bishop loads automatically from [`CLAUDE.md`](CLAUDE.md) at the repo root. The rest sit in [`.claude/agents/`](.claude/agents/) and get called through the subagent tool — named `Task` or `Agent` depending on the Claude Code build.

The senior developer (`@vasquez`) is the one people query. The senior developer is deliberately not available for planning — you can't assign work to it, and neither can Bishop. It only appears when either the junior has completed two fix rounds on the mission, or a CRITICAL finding survives two separate junior fix rounds — whichever comes first. That constraint is what stops "this looks hard" turning into an excuse to skip the pipeline.

## Aboard the Sulaco

The crew are drawn from the *Sulaco*, the ship from *Aliens* — Bishop its synthetic executive officer, Apone its sergeant, Hicks its corporal, and Vasquez its smartgunner. Lambert is the exception, arriving from the *Nostromo* of the earlier film *Alien*: she brings the discipline of keeping the ship's log and knowing exactly where you are, which is what the doc writer does — carries the record forward, keeps the continuity honest.

- **Apone** — "Look into my eye." — *Aliens*
- **Hicks** — "Stay frosty." — *Aliens*
- **Vasquez** — "Let's rock." — *Aliens*
- **Bishop** — "I may be synthetic, but I'm not stupid." — *Aliens*

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

You're looking for `bishop`, `hicks`, `apone`, `vasquez`, and `lambert`. Or just ask:

```text
@bishop report crew status
```

If you edit an agent definition and the change does not appear in `/agents`, restart Claude Code — the agent registry is read at session start. Skills and commands take effect immediately when edited.

## Using It From VS Code

1. Install the Claude Code extension from the Marketplace.
2. Open this repo.
3. Run `claude` in the integrated terminal from the repo root, or use the Claude Code panel.
4. Carry on as normal — Bishop is already running things.

## Running Work Through It

There's one way in:

```text
/mission <what you want done>
```

Bishop restates the goal, writes a numbered plan, sends every coding step to `@hicks` with an `@apone` step directly behind it, and syncs state to disk after **every** step. Stop halfway through and the next session picks up exactly where you left off.

[`.claude/skills/mission-lifecycle/SKILL.md`](.claude/skills/mission-lifecycle/SKILL.md) is the canonical statement of the rules: if anything else in the repo contradicts that file, that file wins. It is not the only place they appear — most are also summarised in `CLAUDE.md`, [`.claude/CREW-MANIFEST.md`](.claude/CREW-MANIFEST.md), [`.claude/agents/bishop.md`](.claude/agents/bishop.md) and [`.claude/commands/mission.md`](.claude/commands/mission.md). So when you change a rule, change it in the canonical file first, then check every place that restates it.

Three constraints don't bend:

1. Every coding step goes to `@hicks`, no matter how the mission looks.
2. Every coding step is followed immediately by `@apone`.
3. `@vasquez` never appears in an initial plan. It arrives by escalation or not at all.

## Memory

`.claude/memory/` is what makes a mission resumable. `CLAUDE.md` is the entry point; it pulls in `.claude/SOUL.md`, `.claude/CREW-MANIFEST.md`, and `.claude/agents/bishop.md`. Two hooks in `.claude/hooks/` (`completion-gate.sh`, `state-continuity.sh`) enforce the continuity rules mechanically, so it isn't purely a matter of the model remembering to.

### Rebuilding it from memory.zip

If `.claude/memory/` goes missing, or you want it back to a clean state:

```bash
cd .claude
unzip -o memory.zip
```

### What lives where

| Folder | What it's for | How long it lasts | Contents |
|--------|---------------|-------------------|----------|
| `.claude/memory/state/` | The canonical state used to resume exactly where work stopped | Permanent | `CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`, `MISSION-ARCHIVE.md` |
| `.claude/memory/missions/` | One folder per mission, named `mission-YYYYMMDD-NN` | Permanent, though Bishop prunes stale ones | `mission-[id]/BRIEF.md`, `PROGRESS.md`, `DEBRIEF.md` |
| `.claude/memory/workspace/` | Scratch space the crew uses mid-mission | Temporary — survives across sessions while a mission is unfinished, archived when a new one starts | drafts, review notes, `findings-scratch.md` |
| `.claude/memory/findings/` | What the crew learned, and patterns worth reusing | Permanent | `FINDINGS.md`, `PATTERNS.md`, `service-records/` |
| `.claude/memory/reference/` | Binding directives, ratified by a human | Permanent | `DIRECTIVES.md` |

`state/` is a **closed directory**: those three canonical files plus machine-written state from a registered hook, and nothing else. Checkpoints, handoff notes, and drafts belong in `workspace/`.

### The three state files

- `CURRENT-MISSION.md` — the single answer to "what's happening right now": mission id, status (`not-started` / `in-progress` / `blocked` / `complete`), next action, blockers. Each sync rewrites what has stopped being true rather than carrying it forward.
- `FLIGHT-RECORDER.md` — an append-only journal, one row per sync. This is the record that matters for continuity. Timestamps are `YYYY-MM-DD HH:MM UTC`, never invented, and every appended row is read back and verified before the sync is reported done.
- `MISSION-ARCHIVE.md` — append-only history of finished work: `Mission ID | Completed | Outcome | Summary`.

### Mission IDs

Every mission gets `mission-YYYYMMDD-NN` — the UTC creation date, then a counter that resets each day and starts at `01`. So `mission-20260711-01`, then `mission-20260711-02`, then `mission-20260712-01` the next day.

Bishop derives it before anything is delegated, taking the highest `NN` already used for that date across **both** the existing `missions/mission-<date>-*` folders and the rows mentioning them in `FLIGHT-RECORDER.md` and `MISSION-ARCHIVE.md`. Folders get pruned; the logs don't — checking both is what stops a retired ID coming back around and making the audit trail ambiguous.

### Inside a mission folder

Every `.claude/memory/missions/mission-[id]/` holds:

- `BRIEF.md` — the goal, the acceptance criteria, the relevant files, and any notes. Every path in `Key Files` is confirmed as it's written, or marked `— to be created at step N`.
- `PROGRESS.md` — step by step status per agent, in a `Step | Phase | Agent | Status | Notes` table: `pending` → `in-progress` → `done` / `failed`. A step becomes `in-progress` when its brief is delegated, not afterwards.
- `DEBRIEF.md` — written at the end: what shipped, what was assumed wrongly, what the crew got wrong and how it was corrected.

### Finding your way around mid-mission

```bash
# What's happening right now
cat .claude/memory/state/CURRENT-MISSION.md

# The journal
cat .claude/memory/state/FLIGHT-RECORDER.md

# The active mission itself
ls .claude/memory/missions
cat .claude/memory/missions/mission-20260711-01/BRIEF.md
cat .claude/memory/missions/mission-20260711-01/PROGRESS.md

# If it's in-progress or blocked, look at the scratch space before anything else
ls .claude/memory/workspace

# What's been finished
cat .claude/memory/state/MISSION-ARCHIVE.md
```

### Current, failed, and finished work

- **Current** — `CURRENT-MISSION.md`, the `Mission ID` and `Status` fields.
- **Blocked or failed** — `CURRENT-MISSION.md` showing `blocked`, with the blocker written out, plus the failed rows in that mission's `PROGRESS.md`.
- **Finished** — the rows in `MISSION-ARCHIVE.md`, each with an `Outcome` of `done` or `failed`.

### What sticks around

- `state/` and `missions/` are the durable trail. That's the audit record.
- `workspace/` is scratch by design, but it survives across sessions while a mission is unfinished — and when a new mission starts it is **archived into `archive-mission-[id]/`, never deleted**. A scratch file is sometimes the only copy of a deliverable that never shipped.
- `findings/` is long-term. Don't treat it as somewhere to dump notes.

### Project directives

`.claude/memory/reference/DIRECTIVES.md` is the **binding, human-ratified** set of coding rules for the project. Every developer and reviewer has to comply with it, and it deliberately sits outside the crew's own learning loop.

| File | Who writes it | How much weight it carries |
|------|---------------|----------------------------|
| `reference/DIRECTIVES.md` | Humans only — agents can read it, nothing more | **Binding.** Agents comply. |
| `findings/PATTERNS.md` | Agents, from observation | Advisory |
| `findings/FINDINGS.md` | Agents propose, a human approves | Suggestions |

Where two disagree, `DIRECTIVES.md` wins.

- **Adding a rule** is a human job. Copy the entry template from [`.claude/templates/reference/DIRECTIVES-TEMPLATE.md`](.claude/templates/reference/DIRECTIVES-TEMPLATE.md), fill in every field, take the next `DIR-NNN`, add an index row, set `Status: active`.
- **Agents read it and comply.** Developers read every entry whose **Applies when** trigger their change satisfies — a property of the change, readable off the brief or the diff, not a path — before writing anything. The reviewer tests the change against each triggered entry's `Reviewer check`; breaking an `active` rule is always a CRITICAL finding. Where a change triggers no entry at all, the reviewer says so explicitly: that's a coverage gap worth a proposal, not a violation.
- **Agents never edit it.** A missing or wrong directive gets proposed through `FINDINGS.md` as `proposed`, and a human ratifies it across. That's the only route in.
- **Retire, don't delete.** Withdrawing a rule means setting `Status: deprecated`. The `DIR-NNN` ids are permanent and never reused.

It ships empty, seeded from `memory.zip`. Fill it in as conventions actually emerge — an empty file is better than one full of rules nobody agreed to.

## Shared Memory (bishop-memory)

bishop-memory is an optional local HTTP service that several harnesses can share. It holds missions, steps, findings, patterns, and the audit journal in one place, with an FTS5 search index. If you don't use it, you're not missing anything — the harness owns its memory entirely and derives mission IDs locally by default. With no configuration needed and no external service required, this is how the system works right now.

Central mode is for when you want mission IDs that are unique across every harness, plus a shared audit trail. You get this by running bishop-memory and telling the harness to talk to it.

**To use central mode:**

1. Install bishop-memory from its own repository:
   - Clone [bishop-memory](https://github.com/djm56/bishop-memory) (or your copy of it).
   - Follow `docs/INSTALL.md` for your platform. The installer builds the daemon, stages it, and confirms it's running.

2. Set up the harness integration:
   - Copy `.claude/bishop-memory.conf.example` to `.claude/bishop-memory.conf`.
   - Edit the new file:
     - Set `BISHOP_MEMORY_MODE=central`.
     - Set `BISHOP_HARNESS` to a name unique to this harness (e.g., `harness-client-sdk`, `harness-docs`). This stops two harnesses colliding on a mission ID.
     - Set `BISHOP_MEMORY_HOME` to the path where you cloned bishop-memory (e.g., `/Users/you/bishop-memory`).

3. Generate the MCP registration:
   - Run `.claude/connect-bishop-memory.sh`.

4. Restart Claude Code and approve the project-scope MCP server when prompted.

Once it's set up, Bishop uses `mission_allocate` to get IDs from the service instead of deriving them locally, and flight-recorder rows and mission steps are mirrored continuously with the reconciler at mission close acting as a backstop. The harness memory tree still lives on disk — it's always the source of truth.

**Why project scope, not user scope?** A user-scoped MCP server is one global setting shared by every project. If two harnesses in different projects both use the same user-scope registration, they'd both appear to bishop-memory under the same name and collide on mission IDs. Project scope ties the registration to this harness, so each one is distinct.

**To turn it off:** Delete `.claude/bishop-memory.conf`. Everything that depends on it goes inert and the harness is back to standalone mode.

For more: see bishop-memory's `docs/HARNESS-INTEGRATION.md` for the tool surface and `docs/api-contract.md` for the HTTP API.

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

If an agent file exists in `.claude/agents/` but does not appear in `/agents`, or an edit to an agent definition has not taken effect, restart Claude Code — the agent registry is read at session start.

If the restart does not resolve it:

1. Check `.claude/agents/` exists and has all five files in it.
2. Run `claude doctor`.

---

## A Note On The Crew

This is a crew assembled across the franchise rather than any one ship's roster — affectionate fan work, and deliberately not strict canon. Nobody in the films served together in these combinations, and the roles here are the harness's, not the films'. A sibling project by the same operator uses MU/TH/UR, the *Nostromo*'s computer, as its memory system — the same franchise affection running across repositories. It is a bit of fun on top of a serious tool.

## Attribution

Bishop, Hicks, Apone, Vasquez and Lambert are characters from the *Alien* films, the property of 20th Century Studios. This document contains short quotations from those films, used for identification and flavour. This is unofficial fan work with no affiliation with or endorsement by the rights holders. All trademarks and copyrights remain with their owners.

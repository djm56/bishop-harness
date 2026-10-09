# Installing Bishop Into Another Repo

The harness is built to travel. This covers getting it into your other repositories and keeping it up to date across all of them.

> "Stay frosty." — Corporal Hicks, *Aliens*

It comes apart into three layers, and the split is the whole trick: a **portable layer** that's identical everywhere, a **per-repo layer** that has to be generated fresh each time, and a **runtime layer** that's created locally and never committed. Keep those separate and one repo's local state can't leak into another.

A critical point: if the portable layer lands incomplete, everything downstream breaks silently. Reading through the hook files proves nothing — they're enforcement, not output. Confirm the copy worked by checking that `.claude/hooks/*.sh` are present and executable, and that `.claude/agents/` contains six files: `bishop.md`, `hicks.md`, `apone.md`, `vasquez.md`, `lambert.md`, and `ripley.md`.

## The Three Layers

### Portable — copy this into every repo

Identical wherever it lands:

```
CLAUDE.md                           # Entry point
.claude/SOUL.md                     # Bishop's identity and values
.claude/CREW-MANIFEST.md            # Crew index and runtime layout
.claude/agents/                     # Bishop plus five specialists
  ├── bishop.md                     # Primary agent
  ├── hicks.md
  ├── apone.md
  ├── vasquez.md
  ├── lambert.md
  └── ripley.md
.claude/commands/                   # Slash commands
  ├── mission.md
  ├── qa.md
  └── about-setup.md
.claude/skills/                     # Reusable skills
  ├── mission-lifecycle/SKILL.md
  ├── documentation/SKILL.md
  ├── code-documentation/SKILL.md
  ├── code-review/SKILL.md
  ├── jnr-coding/SKILL.md
  ├── self-improvement/SKILL.md
  ├── snr-architecture/SKILL.md
  ├── git-workflow/SKILL.md
  └── visual-qa/
      ├── SKILL.md
      ├── technical-integrity.md
      ├── accessibility.md
      └── design-comparison.md
.claude/templates/                  # Canonical file formats
  ├── state/STATE-FILE-TEMPLATE.md
  ├── mission/MISSION-TEMPLATE.md
  ├── mission/DEBRIEF-TEMPLATE.md
  ├── findings/FINDINGS-TEMPLATE.md
  └── reference/DIRECTIVES-TEMPLATE.md
.claude/hooks/                      # Enforcement
  ├── completion-gate.sh
  ├── state-continuity.sh
  └── qa-guard.sh
.claude/settings.json               # Hook wiring — portable, uses ${CLAUDE_PROJECT_DIR}
.claude/memory.zip                  # Seed for the runtime memory folders
.claude/.gitignore                  # Keeps memory and local settings out of git — install-harness.sh doesn't copy it (a hand copy does); target repos keep .claude/ out of git via .git/info/exclude
.claude/qa.conf.example            # Template for the per-repo QA allowlist
```

`.deployignore` belongs to this repo specifically and doesn't travel.

### Per-repo — generate this fresh, never copy it

`.claude/settings.local.json` has to be written for each target. Copying it from another repo points Claude Code at a directory that doesn't exist in this one — a quiet failure that's annoying to track down later.

```json
{
  "additionalDirectories": ["/absolute/path/to/target-repo"],
  "tools": {
    "edit": {"allow": true},
    "read": {"allow": true},
    "write": {"allow": true},
    "bash": {"allow": true},
    "glob": {"allow": true},
    "grep": {"allow": true},
    "webfetch": {"allow": true},
    "websearch": {"allow": true},
    "task": {"allow": true},
    "skill": {"allow": true}
  },
  "restrictedTools": {
    "bash": {
      "deny": ["git push", "git force-push"]
    }
  },
  "defaultMode": "acceptEdits"
}
```

The hook wiring already sits in the portable `settings.json` via `${CLAUDE_PROJECT_DIR}`, so this file only carries permissions and path overrides.

`.claude/qa.conf` is optional and never copied. Copy `qa.conf.example` to create it when Ripley must reach a non-localhost target. Without it, she can reach only localhost. A set `QA_ALLOWED_ORIGINS` replaces the localhost default, and `QA_BLOCKED_ORIGINS` always wins — production belongs there. The operator writes it; the crew does not.

### Runtime — created locally, never tracked

```
.claude/memory/                     # Seeded from memory.zip on first run
  ├── state/                        # Canonical mission state — a closed directory
  │   ├── CURRENT-MISSION.md
  │   ├── FLIGHT-RECORDER.md
  │   └── MISSION-ARCHIVE.md
  ├── missions/                     # One folder per mission, named mission-YYYYMMDD-NN
  ├── workspace/                    # Crew scratch space, archived at each new mission
  │   └── README.md
  ├── findings/                     # What the crew learned
  │   ├── FINDINGS.md
  │   ├── PATTERNS.md
  │   └── service-records/
  └── reference/                    # Binding directives, seeded empty
      └── DIRECTIVES.md
.claude/about/                      # Operator profile — optional, made by /about-setup
  ├── profile/PROFILE.md
  ├── preferences/PREFERENCES.md
  ├── preferences/AVAILABILITY.md
  ├── channels/CHANNELS.md
  ├── tools/README.md
  └── config/README.md
```

## Doing It By Hand

1. **Copy the portable layer** into the target repo root and its `.claude/`:

   ```bash
   cp /source/CLAUDE.md /target/
   mkdir -p /target/.claude && cp -R /source/.claude/. /target/.claude/
   ```

   This copies everything under the source's `.claude/`, dotfiles included. Run it from a clean checkout of the harness: a working copy also carries `settings.local.json` (step 4 says never copy it), `about/`, `qa.conf` and `memory/`, which belong to the source repo. `install-harness.sh` copies exactly the portable layer and is the safer route.

   Confirm `.claude/SOUL.md`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.claude/templates/`, `.claude/hooks/`, `.claude/settings.json`, and `.claude/memory.zip` all made it.

2. **Seed memory**:

   ```bash
   cd /target/.claude
   unzip -o memory.zip
   ```

   That builds `.claude/memory/` with the state and mission folders initialized. It has to exist before any `/mission`.

3. **Fix the hook permissions.** Copying doesn't reliably preserve the executable bit:

   ```bash
   chmod +x /target/.claude/hooks/*.sh
   ```

   The hooks fire on Edit and Write. Get this wrong and the state-continuity contract fails silently, which is the worst way for it to fail.

4. **Write `.claude/settings.local.json` fresh.** Don't copy it:

   ```bash
   # additionalDirectories → /target's absolute path
   # Allow: read, write, edit, bash, glob, grep, task, skill
   # Deny: git push, git force-push (restrictedTools.bash.deny)
   # defaultMode: "acceptEdits"
   ```

   It's gitignored and won't be committed.

5. **Set up the operator profile** (optional):

   ```text
   /about-setup
   ```

   Fills `.claude/about/` with your profile, preferences, availability, and channels. Skip it and the crew runs on sensible defaults — its absence is never treated as a problem.

6. **Add your directives** (optional — it ships empty):

   Put binding rules into `.claude/memory/reference/DIRECTIVES.md` using the entry template in `.claude/templates/reference/DIRECTIVES-TEMPLATE.md`. Humans write that file; agents read it before touching code.

7. **Check it works**:

   ```bash
   cd /target
   claude
   /agents
   ```

   Bishop and the five specialists should be there. If an agent is missing from `/agents` or an agent edit has not taken effect, restart Claude Code — the agent registry is read at session start, while skills and commands update immediately. Then:

   ```text
   /mission Create a test mission
   ```

   You want to see:
   - `CLAUDE.md` imports resolving with no errors in the system prompt
   - State files initialize correctly — `CURRENT-MISSION.md` populated with the test mission, `FLIGHT-RECORDER.md` ready for row delegation
   - `CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`, and a `mission-YYYYMMDD-NN` folder all initialized

## Browser Setup For Ripley

Ripley works with any browser MCP server that provides the capabilities listed in `.claude/skills/visual-qa/SKILL.md`. Her `tools:` line grants servers registered under the names `playwright`, `chrome-devtools` and `claude-in-chrome`. A server registered under another name, or installed through a plugin (whose tools are named `mcp__plugin_<plugin>_<server>__…`), is invisible to her until its prefix is added to her `tools:` line.

**Example registrations** — pin versions in real use, and check each tool's `--help` for its current flags:

```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest --isolated --headless
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --isolated --headless --no-usage-statistics
```

Claude in Chrome, Anthropic's extension, isn't added with `claude mcp add`. Install the Claude in Chrome extension (version 1.0.36 or later) in Chrome, Edge or another Chromium browser, and sign in to Claude Code with a claude.ai account on a direct Anthropic plan — API-key and `setup-token` auth leave it off. Then start with `claude --chrome` or run `/chrome`; it appears in `/mcp` as `claude-in-chrome`. It drives your real, logged-in browser, so Ripley uses it only when the brief names it for that run.

**Second layer.** The guard sees only direct navigation, so set the browser server's own origin limits as well, where it has them. Playwright MCP takes `--allowed-origins` and `--blocked-origins` (semicolon-separated); Chrome DevTools MCP takes `--allowedUrlPattern` and `--blockedUrlPattern`. Mirror `qa.conf` in them — `qa.conf` is space-separated and uses `:*` for any port, so translate each entry into the server's own syntax (check its `--help`) — and include production in the blocked list. Point Playwright MCP's `--output-dir` at `.claude/memory/workspace/qa/`; Chrome DevTools MCP has no output-directory flag, so Ripley passes explicit file paths.

**After adding a server**, restart Claude Code. Approve project servers from `.mcp.json` when prompted. Accept the workspace trust dialog: Ripley's guard is a frontmatter hook and doesn't run until the folder is trusted, nor in `-p` sessions.

**Requirements.** `jq` must be on PATH for the guard, which is tested with jq 1.7.1 and fails closed without it.

**Optional link checker.** If one is installed (for example `lychee`, `linkinator` or `muffet`), Bishop runs it read-only before Ripley's first pass. The harness never installs one.

**Optional design source.** To give Ripley a design server (Figma's MCP server, for example), add its prefix to her `tools:` line and its write tools to `disallowedTools:`.

## Keeping It Out Of Git

The harness and its memory shouldn't be committed. Two ways to handle it.

**Option A — local, invisible to everyone else.** Add to `.git/info/exclude`, which is never committed and your teammates never see:

```
/.claude/
/CLAUDE.md
```

**Option B — repo-wide.** The same two lines in `.gitignore`, committed and visible.

If any of it is already tracked:

```bash
git rm --cached CLAUDE.md
git rm --cached -r .claude
git commit -m "Untrack harness files"
```

## Doing It Across Many Repos

`install-harness.sh` automates all of the above.

```bash
/path/to/install-harness.sh [--dry-run] [--force] <target-repo-path>
```

It finds the source harness relative to itself, then:

1. Copies the portable layer in
2. Seeds `.claude/memory/` from the zip, leaving any existing memory untouched
3. Makes the hooks executable
4. Writes a fresh `.claude/settings.local.json` with the target's absolute path
5. Appends the untrack lines to `.git/info/exclude`, creating it if needed
6. Reports what it did

**Flags**

- `--dry-run` — print every action, change nothing
- `--force` — overwrite an existing `.claude/settings.local.json`, which it otherwise leaves alone to protect manual edits

**Running it again** is fine and expected — that's how you roll a newer harness version out across repos. Memory survives, the exclude lines don't duplicate, and `settings.local.json` isn't clobbered without `--force`. It never pushes and never deletes.

Use `--dry-run` first on any repo you care about. It's the cheapest way to see exactly what's about to be touched.

## Checklist

| Check | How |
|-------|-----|
| Portable layer landed | `ls .claude/SOUL.md .claude/agents/ .claude/commands/ .claude/skills/ .claude/templates/ .claude/hooks/` |
| Memory seeded | `ls .claude/memory/state/ .claude/memory/missions/` |
| Hooks executable | `ls -l .claude/hooks/*.sh` — all `-rwxr-xr-x` |
| `settings.local.json` written | Right `additionalDirectories` path, right tool permissions |
| Untracked | `.claude/` and `CLAUDE.md` in `.git/info/exclude` |
| Crew loads | `claude` → `/agents` shows Bishop and five specialists |
| State initializes | `/mission test` creates `CURRENT-MISSION.md` and sets up `FLIGHT-RECORDER.md` |
| Hooks fire | completion-gate and state-continuity wired in `.claude/settings.json`; qa-guard wired from `ripley.md` frontmatter (runs only once workspace trust is accepted) |
| Browser server connected | `/mcp` lists one under a name Ripley's `tools:` grants |
| jq present | `command -v jq` |
| QA guard executable | `ls -l .claude/hooks/qa-guard.sh` |

## When Things Don't Work

### Hooks aren't firing

During active missions, state-continuity warnings won't appear when the journal falls behind.

```bash
ls -l .claude/hooks/*.sh    # want -rwxr-xr-x
chmod +x .claude/hooks/*.sh # if not
```

### `additionalDirectories` is wrong

Claude Code can't find files in the target, or suggests paths that don't exist.

```bash
grep additionalDirectories .claude/settings.local.json
ls /path/from/settings.local.json/
```

Nine times out of ten this is a `settings.local.json` copied from another repo.

### `.claude/memory/` is missing

```bash
ls -la .claude/memory.zip
cd .claude && unzip -o memory.zip && cd ..
```

If the zip itself is gone or corrupt the install is incomplete — re-copy the portable layer from source.

### Some of the crew is missing

```bash
cd /target && pwd    # must be the repo root
claude
/agents
```

Still short? Check `.claude/agents/` has all six files, that `CLAUDE.md` is readable at the root, and that `settings.local.json` has `"task": {"allow": true}`.

---

## Where To Look

- **Who Bishop is** — `.claude/SOUL.md`
- **How Bishop operates** — `.claude/agents/bishop.md`: the execution loop, delegation rules, completion gates
- **The state contract** — `.claude/skills/mission-lifecycle/SKILL.md`. It's canonical, and it beats anything that contradicts it
- **File formats** — `.claude/templates/`, the source of truth for every canonical file
- **What the installer actually does** — `install-harness.sh` itself

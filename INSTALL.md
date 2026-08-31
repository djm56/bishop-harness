# Installing Bishop Into Another Repo

The harness is built to travel. This covers getting it into your other repositories and keeping it up to date across all of them.

It comes apart into three layers, and the split is the whole trick: a **portable layer** that's identical everywhere, a **per-repo layer** that has to be generated fresh each time, and a **runtime layer** that's created locally and never committed. Keep those separate and one repo's local state can't leak into another.

## The Three Layers

### Portable — copy this into every repo

Identical wherever it lands:

```
CLAUDE.md                           # Entry point
.claude/SOUL.md                     # Bishop's identity and values
.claude/AGENT-INDEX.md              # Crew index and runtime layout
.claude/agents/                     # Bishop plus four specialists
  ├── bishop.md                     # Primary agent
  ├── jnr-developer.md
  ├── code-reviewer.md
  ├── snr-developer.md
  └── doc-writer.md
.claude/commands/                   # Slash commands
  ├── start-task.md
  └── about-setup.md
.claude/skills/                     # Reusable skills
  ├── task-lifecycle/SKILL.md
  ├── documentation/SKILL.md
  ├── code-documentation/SKILL.md
  ├── code-review/SKILL.md
  ├── jnr-coding/SKILL.md
  ├── self-improvement/SKILL.md
  ├── snr-architecture/SKILL.md
  ├── git-workflow/SKILL.md
  └── wordpress-development/SKILL.md
.claude/templates/                  # Canonical file formats
  ├── state/STATE-FILE-TEMPLATE.md
  ├── task/TASK-TEMPLATE.md
  ├── task/DONE-REPORT-TEMPLATE.md
  ├── improvement/IMPROVEMENT-TEMPLATE.md
  └── reference/CONVENTIONS-TEMPLATE.md
.claude/hooks/                      # Enforcement
  ├── completion-gate.sh
  └── state-continuity.sh
.claude/settings.json               # Hook wiring — portable, uses ${CLAUDE_PROJECT_DIR}
.claude/memory.zip                  # Seed for the runtime memory folders
.claude/.gitignore                  # Keeps memory and local settings out of git
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

### Runtime — created locally, never tracked

```
.claude/memory/                     # Seeded from memory.zip on first run
  ├── state/                        # Canonical task state
  │   ├── ACTIVE-TASK.md
  │   ├── EVENT-LOG.md
  │   └── DONE-LOG.md
  ├── tasks/                        # One folder per task
  ├── agent-documents/              # Crew scratch space
  ├── improvements/                 # What the crew learned
  │   ├── IMPROVEMENTS.md
  │   ├── PATTERNS.md
  │   └── agent-notes/
  └── reference/                    # Project conventions, seeded empty
      └── CONVENTIONS.md
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
   cp -r /source/CLAUDE.md /source/.claude/* /target/
   ```

   Confirm `.claude/SOUL.md`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.claude/templates/`, `.claude/hooks/`, `.claude/settings.json`, and `.claude/memory.zip` all made it.

2. **Seed memory**:

   ```bash
   cd /target/.claude
   unzip -o memory.zip
   ```

   That builds `.claude/memory/` with the state and task folders initialized. It has to exist before any `/start-task`.

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

6. **Add your conventions** (optional — it ships empty):

   Put binding rules into `.claude/memory/reference/CONVENTIONS.md` using the entry template in `.claude/templates/reference/CONVENTIONS-TEMPLATE.md`. Humans write that file; agents read it before touching code.

7. **Check it works**:

   ```bash
   cd /target
   claude
   /agents
   ```

   Bishop and the four specialists should be there. Then:

   ```text
   /start-task Create a test task
   ```

   You want to see:
   - `CLAUDE.md` imports resolving with no errors in the system prompt
   - A `step-sync` row appearing in `.claude/memory/state/EVENT-LOG.md` after an edit — that's the hooks firing
   - `ACTIVE-TASK.md`, `EVENT-LOG.md`, and a task folder all initialized

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
| Memory seeded | `ls .claude/memory/state/ .claude/memory/tasks/` |
| Hooks executable | `ls -l .claude/hooks/*.sh` — all `-rwxr-xr-x` |
| `settings.local.json` written | Right `additionalDirectories` path, right tool permissions |
| Untracked | `.claude/` and `CLAUDE.md` in `.git/info/exclude` |
| Crew loads | `claude` → `/agents` shows Bishop and four specialists |
| State initializes | `/start-task test` creates `ACTIVE-TASK.md` and sets up `EVENT-LOG.md` |
| Hooks fire | Edit a file, then look for a `step-sync` row in `EVENT-LOG.md` |

## When Things Don't Work

### Hooks aren't firing

State files stop updating after edits.

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

Still short? Check `.claude/agents/` has all five files, that `CLAUDE.md` is readable at the root, and that `settings.local.json` has `"task": {"allow": true}`.

---

## Where To Look

- **Who Bishop is** — `.claude/SOUL.md`
- **How Bishop operates** — `.claude/agents/bishop.md`: the execution loop, delegation rules, completion gates
- **The state contract** — `.claude/skills/task-lifecycle/SKILL.md`. It's canonical, and it beats anything that contradicts it
- **File formats** — `.claude/templates/`, the source of truth for every canonical file
- **What the installer actually does** — `install-harness.sh` itself

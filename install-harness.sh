#!/usr/bin/env bash

#
# install-harness.sh — puts the Bishop harness into another repo
#
# WHAT IT DOES
#   Copies the harness out of this repo and into a target one, seeding that
#   repo's .claude/ directory with the portable layer — agents, skills,
#   templates, hooks, config — and then hiding it from git via
#   .git/info/exclude. The harness itself is never committed anywhere.
#
# RUNNING IT
#   ./install-harness.sh [--dry-run] [--force] <target-repo-path>
#
# FLAGS
#   --dry-run    Show every action it would take, change nothing.
#   --force      Allow an existing settings.local.json to be overwritten.
#                Without it, an existing file is left alone with a warning.
#   -h, --help   Print this and stop.
#
# STEP BY STEP
#   • Works out SOURCE from wherever this script lives, following symlinks.
#   • Checks TARGET exists and is actually a directory.
#   • Copies the portable pieces from SOURCE/.claude into TARGET/.claude:
#       IN:  CLAUDE.md, SOUL.md, AGENT-INDEX.md, agents/, commands/, skills/,
#            templates/, hooks/, settings.json, memory.zip
#       OUT: memory/, about/, settings.local.json, .deployignore, .git/,
#            README.md, install-harness.sh
#   • Re-running refreshes the portable layer and leaves local state alone.
#   • Seeds TARGET/.claude/memory/ from memory.zip, keeping anything already there.
#   • Writes TARGET/.claude/settings.local.json, honouring --force.
#   • Marks TARGET/.claude/hooks/ scripts executable.
#   • Appends /.claude/ and /CLAUDE.md to .git/info/exclude if they aren't there.
#   • Warns when TARGET isn't a git repo, since the untrack step needs .git/.
#   • Safe to run again: memory survives, exclude lines don't duplicate, and
#     settings.local.json isn't clobbered without --force.
#   • Never pushes. Never deletes.
#
# EXIT CODES
#   0 = it worked
#   1 = bad arguments, failed validation, or a command that didn't succeed
#

set -euo pipefail

# —————————————————————————————————————————————————————————————————————————————
# FUNCTIONS
# —————————————————————————————————————————————————————————————————————————————

#
# print_usage — write the usage block to stdout.
#
print_usage() {
  cat <<'EOF'
install-harness.sh — puts the Bishop harness into another repo

USAGE
  ./install-harness.sh [--dry-run] [--force] <target-repo-path>

OPTIONS
  --dry-run    Show what would happen, change nothing.
  --force      Overwrite existing settings.local.json (default: skip + warn).
  -h, --help   Print this message and exit.

EXAMPLE
  ./install-harness.sh ~/my-wordpress-site
  ./install-harness.sh --dry-run ~/my-wordpress-site
  ./install-harness.sh --force ~/my-wordpress-site
EOF
}

#
# log_info — ordinary progress, to stdout.
#
log_info() {
  echo "[*] $*"
}

#
# log_warn — something worth noticing, to stderr.
#
log_warn() {
  echo "[!] WARNING: $*" >&2
}

#
# log_error — say what broke, then stop with 1.
#
log_error() {
  echo "[ERROR] $*" >&2
  exit 1
}

#
# log_dry_run — report an action we're only pretending to take.
#
log_dry_run() {
  echo "[DRY-RUN] $*"
}

#
# resolve_source — work out the absolute directory this script lives in,
#   following symlinks where it has to.
#
resolve_source() {
  local script_path
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  echo "$script_path"
}

#
# validate_target — confirm TARGET is there and is a directory. Exit 1 if not.
#
validate_target() {
  local target="$1"

  if [[ ! -e "$target" ]]; then
    log_error "Target does not exist: $target"
  fi

  if [[ ! -d "$target" ]]; then
    log_error "Target is not a directory: $target"
  fi
}

#
# is_git_repo — 0 when TARGET is a git repo, 1 when it isn't.
#
is_git_repo() {
  local target="$1"
  [[ -d "$target/.git" ]]
}

#
# copy_portable_layer — move CLAUDE.md and the portable parts of .claude/ across,
#   preferring rsync and falling back to cp. Honours DRY_RUN.
#   Sets PORTABLE_LAYER_STATUS.
#
copy_portable_layer() {
  local source="$1"
  local target="$2"

  # Ensure .claude exists in target
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry_run "mkdir -p '$target/.claude'"
  else
    mkdir -p "$target/.claude"
  fi

  # Copy CLAUDE.md to target root
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry_run "cp '$source/CLAUDE.md' '$target/CLAUDE.md'"
  else
    cp "$source/CLAUDE.md" "$target/CLAUDE.md"
  fi

  # Copy .claude/* (portable layer) using rsync if available
  if command -v rsync &>/dev/null; then
    local rsync_cmd=(
      "rsync"
      "-a"
      "--include=SOUL.md"
      "--include=AGENT-INDEX.md"
      "--include=agents/"
      "--include=agents/**"
      "--include=commands/"
      "--include=commands/**"
      "--include=skills/"
      "--include=skills/**"
      "--include=templates/"
      "--include=templates/**"
      "--include=hooks/"
      "--include=hooks/**"
      "--include=settings.json"
      "--include=memory.zip"
      "--exclude=*"
      "$source/.claude/"
      "$target/.claude/"
    )

    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry_run "${rsync_cmd[*]}"
      PORTABLE_LAYER_STATUS="dry-run"
    else
      "${rsync_cmd[@]}" || log_error "rsync failed"
      PORTABLE_LAYER_STATUS="copied"
    fi
  else
    # Fallback: cp -r for individual items (ensuring no double-nesting on directories)
    local items=(
      "SOUL.md"
      "AGENT-INDEX.md"
      "agents"
      "commands"
      "skills"
      "templates"
      "hooks"
      "settings.json"
      "memory.zip"
    )

    for item in "${items[@]}"; do
      if [[ "$DRY_RUN" == "1" ]]; then
        if [[ -d "$source/.claude/$item" ]]; then
          log_dry_run "cp -r '$source/.claude/$item' '$target/.claude/$item' (contents)"
        else
          log_dry_run "cp '$source/.claude/$item' '$target/.claude/$item'"
        fi
      else
        if [[ -d "$source/.claude/$item" ]]; then
          mkdir -p "$target/.claude/$item"
          cp -R "$source/.claude/$item/." "$target/.claude/$item"
        else
          cp "$source/.claude/$item" "$target/.claude/$item"
        fi
      fi
    done

    if [[ "$DRY_RUN" == "1" ]]; then
      PORTABLE_LAYER_STATUS="dry-run"
    else
      PORTABLE_LAYER_STATUS="copied"
    fi
  fi
}

#
# seed_memory — unzip memory.zip into TARGET/.claude/memory/ when it isn't there
#   yet. Existing memory is left completely alone. Honours DRY_RUN.
#   Sets MEMORY_STATUS.
#
seed_memory() {
  local target="$1"
  local memory_path="$target/.claude/memory"

  if [[ -d "$memory_path" ]]; then
    log_info "memory/ already present — preserving existing state"
    MEMORY_STATUS="preserved"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry_run "unzip -q '$target/.claude/memory.zip' -d '$target/.claude/'"
    MEMORY_STATUS="dry-run"
  else
    if ! unzip -q "$target/.claude/memory.zip" -d "$target/.claude/"; then
      log_error "unzip memory.zip failed"
    fi
    MEMORY_STATUS="seeded"
  fi
}

#
# chmod_hooks — make every .sh in TARGET/.claude/hooks/ executable. Honours DRY_RUN,
#   reading the SOURCE hooks directory in that case so it can still report accurately.
#   Sets CHMOD_HOOKS_STATUS.
#
chmod_hooks() {
  local target="$1"
  local source="$2"
  local hooks_dir="$target/.claude/hooks"

  # In dry-run mode, check the SOURCE hooks directory to see what WOULD be copied
  if [[ "$DRY_RUN" == "1" ]]; then
    local source_hooks_dir="$source/.claude/hooks"
    local hook_count=0

    # Count .sh files in source hooks directory (read-only glob)
    while IFS= read -r -d '' hook_file; do
      hook_count=$((hook_count + 1))
    done < <(find "$source_hooks_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)

    if [[ $hook_count -gt 0 ]]; then
      log_dry_run "chmod +x hooks/*.sh ($hook_count script(s))"
      CHMOD_HOOKS_STATUS="dry-run"
    else
      CHMOD_HOOKS_STATUS="skipped"
    fi
    return 0
  fi

  # Real (non-dry-run) install: work on target hooks dir
  if [[ ! -d "$hooks_dir" ]]; then
    CHMOD_HOOKS_STATUS="skipped"
    return 0
  fi

  local hook_count=0
  # Find all .sh files in hooks directory
  while IFS= read -r -d '' hook_file; do
    hook_count=$((hook_count + 1))
    chmod +x "$hook_file"
  done < <(find "$hooks_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)

  if [[ $hook_count -eq 0 ]]; then
    CHMOD_HOOKS_STATUS="none-found"
  else
    CHMOD_HOOKS_STATUS="applied"
  fi
}

#
# write_settings_local_json — write TARGET/.claude/settings.local.json with
#   sensible defaults. Only overwrites under --force. Honours DRY_RUN.
#   Sets SETTINGS_JSON_STATUS.
#
write_settings_local_json() {
  local target="$1"
  local force="$2"
  local settings_path="$target/.claude/settings.local.json"

  # Resolve TARGET to absolute path
  local abs_target
  abs_target="$(cd "$target" && pwd -P)"

  # Build settings object
  local settings_json
  settings_json=$(cat <<EOF
{
  "permissions": {
    "allow": [
      "Edit(.claude/**)",
      "Write(.claude/**)",
      "Task",
      "Bash(git status:*)",
      "Bash(git branch:*)",
      "Bash(git switch:*)",
      "Bash(git checkout:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git rev-parse:*)",
      "Bash(chmod:*)",
      "Bash(unzip:*)",
      "Bash(jq:*)",
      "Skill(update-config)"
    ],
    "deny": [
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Bash(git push origin main:*)",
      "Bash(git push origin HEAD:main:*)"
    ],
    "defaultMode": "acceptEdits",
    "additionalDirectories": [
      "$abs_target/.claude"
    ]
  }
}
EOF
)

  # Check for existing file before any other logic
  if [[ -f "$settings_path" && "$force" != "1" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry_run "settings.local.json exists — would skip (use --force to overwrite)"
      SETTINGS_JSON_STATUS="dry-run-skip"
    else
      log_warn "settings.local.json already exists — skipping (use --force to overwrite)"
      SETTINGS_JSON_STATUS="skipped"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry_run "write settings.local.json to $settings_path"
    log_dry_run "  content:"
    echo "$settings_json" | sed 's/^/    /'
    SETTINGS_JSON_STATUS="dry-run"
    return 0
  fi

  # Validate JSON if jq is available
  if command -v jq &>/dev/null; then
    if ! echo "$settings_json" | jq empty; then
      log_error "Generated invalid JSON"
    fi
  fi

  # Write to file
  echo "$settings_json" > "$settings_path" || log_error "Failed to write settings.local.json"
  SETTINGS_JSON_STATUS="written"
}

#
# untrack_harness — add /.claude/ and /CLAUDE.md to TARGET/.git/info/exclude,
#   appending only what isn't already there. Warns when TARGET isn't a git repo.
#   Honours DRY_RUN. Sets UNTRACK_STATUS.
#
untrack_harness() {
  local target="$1"
  local exclude_file="$target/.git/info/exclude"

  if ! is_git_repo "$target"; then
    log_warn "Target is not a git repository — cannot add to .git/info/exclude"
    log_warn "  Please manually add these lines to your .gitignore or .git/info/exclude:"
    log_warn "    /.claude/"
    log_warn "    /CLAUDE.md"
    UNTRACK_STATUS="skipped-not-git"
    return 0
  fi

  # Create .git/info/exclude if it doesn't exist
  if [[ ! -f "$exclude_file" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry_run "create '$exclude_file'"
    else
      mkdir -p "$(dirname "$exclude_file")"
      touch "$exclude_file"
    fi
  fi

  # Check and append /.claude/ if not present
  if ! grep -q '^/.claude/$' "$exclude_file" 2>/dev/null; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry_run "append '/.claude/' to $exclude_file"
    else
      echo "/.claude/" >> "$exclude_file"
    fi
  fi

  # Check and append /CLAUDE.md if not present
  if ! grep -q '^/CLAUDE.md$' "$exclude_file" 2>/dev/null; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry_run "append '/CLAUDE.md' to $exclude_file"
    else
      echo "/CLAUDE.md" >> "$exclude_file"
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    UNTRACK_STATUS="dry-run"
  else
    UNTRACK_STATUS="updated"
  fi
}

#
# print_final_report — a short checklist of what actually happened, read back
#   from the status variables each step sets.
#
print_final_report() {
  local target="$1"
  local dry_run="$2"

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "BISHOP HARNESS INSTALLATION REPORT"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  if [[ "$dry_run" == "1" ]]; then
    echo "MODE: Dry-run (no changes made)"
    echo ""
  fi

  echo "INSTALLATION STEPS"

  # Portable layer status
  case "$PORTABLE_LAYER_STATUS" in
    "copied")
      echo "  ✓ Portable layer copied (CLAUDE.md, agents/, skills/, etc.)"
      ;;
    "dry-run")
      echo "  [DRY-RUN] Portable layer would be copied"
      ;;
    *)
      echo "  ⚠ Portable layer status unknown"
      ;;
  esac

  # Memory status
  case "$MEMORY_STATUS" in
    "seeded")
      echo "  ✓ Memory seeded from memory.zip"
      ;;
    "preserved")
      echo "  ✓ Memory preserved (existing state kept)"
      ;;
    "dry-run")
      echo "  [DRY-RUN] Memory would be seeded from memory.zip"
      ;;
    *)
      echo "  ⚠ Memory status unknown"
      ;;
  esac

  # Chmod hooks status
  case "$CHMOD_HOOKS_STATUS" in
    "applied")
      echo "  ✓ Hooks made executable"
      ;;
    "dry-run")
      echo "  [DRY-RUN] Hooks would be made executable"
      ;;
    "none-found")
      echo "  ⓘ No hook scripts found (skipped)"
      ;;
    "skipped")
      echo "  ⓘ Hooks directory not found (skipped)"
      ;;
    *)
      echo "  ⚠ Chmod hooks status unknown"
      ;;
  esac

  # Settings.local.json status
  case "$SETTINGS_JSON_STATUS" in
    "written")
      echo "  ✓ settings.local.json written"
      ;;
    "dry-run")
      echo "  [DRY-RUN] settings.local.json would be written"
      ;;
    "dry-run-skip")
      echo "  [DRY-RUN] settings.local.json exists — would skip"
      ;;
    "skipped")
      echo "  ⓘ settings.local.json exists — skipped (use --force to overwrite)"
      ;;
    *)
      echo "  ⚠ Settings.local.json status unknown"
      ;;
  esac

  # Untrack status
  case "$UNTRACK_STATUS" in
    "updated")
      echo "  ✓ Harness untracked via .git/info/exclude"
      ;;
    "dry-run")
      echo "  [DRY-RUN] Harness would be untracked via .git/info/exclude"
      ;;
    "skipped-not-git")
      echo "  ⚠ Not a git repository — cannot untrack (manual action required)"
      ;;
    *)
      echo "  ⚠ Untrack status unknown"
      ;;
  esac

  echo ""
  echo "TARGET: $target"
  if [[ "$dry_run" != "1" ]]; then
    echo "STATUS: Ready for use"
  fi
  echo ""
  echo "NEXT STEPS"
  echo "  1. (Optional) Run /about-setup in Claude Code to create operator profile"
  echo "  2. Populate .claude/memory/reference/CONVENTIONS.md with project rules"
  echo "  3. Open a Claude Code session in the target repository"
  echo "  4. Confirm that hooks fire and /mission initializes state correctly"
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
}

# —————————————————————————————————————————————————————————————————————————————
# MAIN
# —————————————————————————————————————————————————————————————————————————————

DRY_RUN=0
FORCE=0
TARGET=""
PORTABLE_LAYER_STATUS=""
MEMORY_STATUS=""
CHMOD_HOOKS_STATUS=""
SETTINGS_JSON_STATUS=""
UNTRACK_STATUS=""

# Read the flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$1"
      else
        log_error "Too many positional arguments"
      fi
      shift
      ;;
  esac
done

# Check what we got
if [[ -z "$TARGET" ]]; then
  print_usage
  exit 0
fi

# Locate ourselves, then check the target
SOURCE="$(resolve_source)"
validate_target "$TARGET"

# Make TARGET absolute
TARGET="$(cd "$TARGET" && pwd -P)"

log_info "SOURCE: $SOURCE"
log_info "TARGET: $TARGET"

if [[ "$DRY_RUN" == "1" ]]; then
  log_info "DRY-RUN mode enabled (no changes will be made)"
fi

echo ""

# Do the work
copy_portable_layer "$SOURCE" "$TARGET"
seed_memory "$TARGET"
chmod_hooks "$TARGET" "$SOURCE"
write_settings_local_json "$TARGET" "$FORCE"
untrack_harness "$TARGET"

# Say what happened
print_final_report "$TARGET" "$DRY_RUN"

exit 0

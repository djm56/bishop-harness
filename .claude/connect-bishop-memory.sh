#!/usr/bin/env bash
#
# connect-bishop-memory.sh
#
# Generator for .mcp.json bishop-memory server registration.
#
# The old bishop-memory installer reached into this harness and patched five things:
# the conf file, .mcp.json, .gitignore, and two doctrine files. That is being retired.
#
# The harness now owns its own doctrine and gitignore rules as committed content.
# Configuration lives in .claude/bishop-memory.conf — a gitignored file per-machine
# so each harness clone carries its own identity.
#
# .mcp.json is the one piece that cannot be committed: it holds the absolute path
# to the mcpd binary on this machine, which differs per install. But every value
# in it is derivable from the conf file, so this small generator replaces the
# foreign installer.
#
# Read .claude/bishop-memory.conf and generate or update .mcp.json with a
# bishop-memory server entry, merging into any existing file so other servers
# registered in it are preserved. Exit 0 on success, non-zero on refusal.
#

set -euo pipefail

# Log prefix for clarity
LOG_PREFIX="[connect-bishop-memory]"

# Find the project root. Trust CLAUDE_PROJECT_DIR when it's set; otherwise walk up.
# The script lives at .claude/connect-bishop-memory.sh, so the root is one level up.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Defaults and flags
DRY_RUN=0
CONF_FILE="$PROJECT_ROOT/.claude/bishop-memory.conf"
MCP_JSON="$PROJECT_ROOT/.mcp.json"
MCP_JSON_BAK="$MCP_JSON.bak"

# Parse command-line flags
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      printf '%s Invalid argument: %s\n' "$LOG_PREFIX" "$1" >&2
      exit 1
      ;;
  esac
done

# ============================================================================
# STEP 1: Validate conf file exists
# ============================================================================

if [ ! -f "$CONF_FILE" ]; then
  printf '%s ERROR: %s not found.\n' "$LOG_PREFIX" "$CONF_FILE" >&2
  printf '%s NEXT: Copy .claude/bishop-memory.conf.example to .claude/bishop-memory.conf and edit it.\n' "$LOG_PREFIX" >&2
  exit 1
fi

# ============================================================================
# STEP 2: Parse conf file safely
# ============================================================================

BISHOP_MEMORY_MODE=""
BISHOP_MEMORY_URL=""
BISHOP_HARNESS=""
BISHOP_MEMORY_HOME=""

while IFS= read -r CONFIG_LINE; do
  # Skip blank lines and comment lines
  case "$CONFIG_LINE" in
    "") continue ;;
    \#*) continue ;;
  esac

  # Split on the FIRST = only
  CONFIG_KEY="${CONFIG_LINE%%=*}"
  CONFIG_VALUE="${CONFIG_LINE#*=}"

  # Match and assign only recognized keys
  case "$CONFIG_KEY" in
    BISHOP_MEMORY_MODE)
      BISHOP_MEMORY_MODE="$CONFIG_VALUE"
      ;;
    BISHOP_MEMORY_URL)
      BISHOP_MEMORY_URL="$CONFIG_VALUE"
      ;;
    BISHOP_HARNESS)
      BISHOP_HARNESS="$CONFIG_VALUE"
      ;;
    BISHOP_MEMORY_HOME)
      BISHOP_MEMORY_HOME="$CONFIG_VALUE"
      ;;
  esac
done < "$CONF_FILE" 2>/dev/null || {
  printf '%s ERROR: Could not read %s.\n' "$LOG_PREFIX" "$CONF_FILE" >&2
  exit 1
}

# ============================================================================
# STEP 3: Validate BISHOP_MEMORY_MODE
# ============================================================================

if [ "$BISHOP_MEMORY_MODE" != "central" ]; then
  printf '%s INFO: BISHOP_MEMORY_MODE is not "central".\n' "$LOG_PREFIX" >&2
  printf '%s NEXT: Standalone mode needs no MCP registration. .mcp.json is not needed.\n' "$LOG_PREFIX" >&2
  printf '%s (This is by design. No action required.)\n' "$LOG_PREFIX" >&2
  exit 1
fi

# ============================================================================
# STEP 4: Validate BISHOP_HARNESS
# ============================================================================

if [ -z "$BISHOP_HARNESS" ]; then
  printf '%s ERROR: BISHOP_HARNESS is empty.\n' "$LOG_PREFIX" >&2
  printf '%s NEXT: Edit .claude/bishop-memory.conf and set BISHOP_HARNESS to a unique value per harness.\n' "$LOG_PREFIX" >&2
  printf '%s (Example: claude-code, my-harness, project-alpha. Keep it letters, digits, hyphen, underscore.)\n' "$LOG_PREFIX" >&2
  exit 1
fi

# Validate BISHOP_HARNESS format: letters, digits, hyphen, underscore only
if ! printf '%s' "$BISHOP_HARNESS" | grep -qE '^[a-zA-Z0-9_-]+$'; then
  printf '%s ERROR: BISHOP_HARNESS contains invalid characters: %s\n' "$LOG_PREFIX" "$BISHOP_HARNESS" >&2
  printf '%s NEXT: Edit .claude/bishop-memory.conf and set BISHOP_HARNESS to contain only letters, digits, hyphen, underscore.\n' "$LOG_PREFIX" >&2
  exit 1
fi

# ============================================================================
# STEP 5: Validate BISHOP_MEMORY_HOME
# ============================================================================

if [ -z "$BISHOP_MEMORY_HOME" ]; then
  printf '%s ERROR: BISHOP_MEMORY_HOME is empty.\n' "$LOG_PREFIX" >&2
  printf '%s NEXT: Edit .claude/bishop-memory.conf and set BISHOP_MEMORY_HOME to the bishop-memory install root.\n' "$LOG_PREFIX" >&2
  exit 1
fi

if ! printf '%s' "$BISHOP_MEMORY_HOME" | grep -qE '^/'; then
  printf '%s ERROR: BISHOP_MEMORY_HOME is not an absolute path: %s\n' "$LOG_PREFIX" "$BISHOP_MEMORY_HOME" >&2
  printf '%s NEXT: Edit .claude/bishop-memory.conf and set BISHOP_MEMORY_HOME to an absolute path.\n' "$LOG_PREFIX" >&2
  exit 1
fi

MCPD_PATH="$BISHOP_MEMORY_HOME/bin/mcpd"
if [ ! -f "$MCPD_PATH" ]; then
  printf '%s ERROR: %s does not exist or is not a file.\n' "$LOG_PREFIX" "$MCPD_PATH" >&2
  printf '%s NEXT: Build bishop-memory in %s: cd %s && make build\n' "$LOG_PREFIX" "$BISHOP_MEMORY_HOME" "$BISHOP_MEMORY_HOME" >&2
  exit 1
fi

# ============================================================================
# STEP 6: Set default URL if not provided
# ============================================================================

if [ -z "$BISHOP_MEMORY_URL" ]; then
  BISHOP_MEMORY_URL="http://127.0.0.1:8787"
fi

# ============================================================================
# STEP 6b: Probe for JSON tools (python3 or jq)
# ============================================================================

HAS_PYTHON3=0
HAS_JQ=0

if command -v python3 >/dev/null 2>&1; then
  HAS_PYTHON3=1
fi

if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
fi

if [ $HAS_PYTHON3 -eq 0 ] && [ $HAS_JQ -eq 0 ]; then
  printf '%s ERROR: Neither python3 nor jq is available.\n' "$LOG_PREFIX" >&2
  printf '%s NEXT: Install python3 or jq to generate JSON configuration.\n' "$LOG_PREFIX" >&2
  exit 1
fi

# ============================================================================
# STEP 7: Build the bishop-memory server entry as JSON
# ============================================================================

BISHOP_ENTRY=""
JSON_TOOL_USED=""

if [ $HAS_PYTHON3 -eq 1 ]; then
  if MCPD_PATH="$MCPD_PATH" BISHOP_HARNESS="$BISHOP_HARNESS" BISHOP_MEMORY_URL="$BISHOP_MEMORY_URL" \
    python3 -c 'import json, os; print(json.dumps({"type": "stdio", "command": os.environ["MCPD_PATH"], "args": [], "env": {"BISHOP_HARNESS": os.environ["BISHOP_HARNESS"], "BISHOP_MEMORY_URL": os.environ["BISHOP_MEMORY_URL"]}}, indent=2))' >/dev/null 2>&1; then
    BISHOP_ENTRY="$(MCPD_PATH="$MCPD_PATH" BISHOP_HARNESS="$BISHOP_HARNESS" BISHOP_MEMORY_URL="$BISHOP_MEMORY_URL" \
      python3 -c 'import json, os; print(json.dumps({"type": "stdio", "command": os.environ["MCPD_PATH"], "args": [], "env": {"BISHOP_HARNESS": os.environ["BISHOP_HARNESS"], "BISHOP_MEMORY_URL": os.environ["BISHOP_MEMORY_URL"]}}, indent=2))')"
    JSON_TOOL_USED="python3"
  fi
fi

if [ -z "$BISHOP_ENTRY" ] && [ $HAS_JQ -eq 1 ]; then
  BISHOP_ENTRY="$(jq -n \
    --arg cmd "$MCPD_PATH" \
    --arg harness "$BISHOP_HARNESS" \
    --arg url "$BISHOP_MEMORY_URL" \
    '{type: "stdio", command: $cmd, args: [], env: {BISHOP_HARNESS: $harness, BISHOP_MEMORY_URL: $url}}')"
  JSON_TOOL_USED="jq"
fi

if [ -z "$BISHOP_ENTRY" ]; then
  if [ $HAS_PYTHON3 -eq 1 ]; then
    printf '%s ERROR: python3 failed to generate JSON entry.\n' "$LOG_PREFIX" >&2
  fi
  if [ $HAS_JQ -eq 1 ]; then
    printf '%s ERROR: jq failed to generate JSON entry.\n' "$LOG_PREFIX" >&2
  fi
  printf '%s (Check that BISHOP_MEMORY_HOME points to a valid bishop-memory installation.)\n' "$LOG_PREFIX" >&2
  exit 1
fi

# ============================================================================
# STEP 8: Merge into .mcp.json
# ============================================================================

MERGED_JSON=""

if [ -f "$MCP_JSON" ]; then
  # File exists. Merge the entry into mcpServers.
  if [ $HAS_PYTHON3 -eq 1 ]; then
    MERGED_JSON="$(MCP_JSON="$MCP_JSON" BISHOP_ENTRY="$BISHOP_ENTRY" \
      python3 -c 'import json, os; data = json.load(open(os.environ["MCP_JSON"])); data.setdefault("mcpServers", {})["bishop-memory"] = json.loads(os.environ["BISHOP_ENTRY"]); print(json.dumps(data, indent=2))' 2>/dev/null || echo '')"
  fi
  if [ -z "$MERGED_JSON" ] && [ $HAS_JQ -eq 1 ]; then
    MERGED_JSON="$(jq \
      --argjson bishop_entry "$BISHOP_ENTRY" \
      '(.mcpServers //= {}) | .mcpServers.bishop-memory = $bishop_entry' \
      "$MCP_JSON" 2>/dev/null || echo '')"
  fi
else
  # File does not exist. Create a new one with bishop-memory as the only server.
  if [ $HAS_PYTHON3 -eq 1 ]; then
    MERGED_JSON="$(BISHOP_ENTRY="$BISHOP_ENTRY" \
      python3 -c 'import json, os; print(json.dumps({"mcpServers": {"bishop-memory": json.loads(os.environ["BISHOP_ENTRY"])}}, indent=2))' 2>/dev/null || echo '')"
  fi
  if [ -z "$MERGED_JSON" ] && [ $HAS_JQ -eq 1 ]; then
    MERGED_JSON="$(jq -n \
      --argjson bishop_entry "$BISHOP_ENTRY" \
      '{mcpServers: {("bishop-memory"): $bishop_entry}}' 2>/dev/null || echo '')"
  fi
fi

if [ -z "$MERGED_JSON" ]; then
  printf '%s ERROR: Could not merge JSON into %s.\n' "$LOG_PREFIX" "$MCP_JSON" >&2
  printf '%s TRIED: %s for JSON processing.\n' "$LOG_PREFIX" "$([ $HAS_PYTHON3 -eq 1 ] && echo "python3" || echo "") $([ $HAS_JQ -eq 1 ] && echo "jq" || echo "")" >&2
  printf '%s (Check that .mcp.json is valid JSON and can be parsed.)\n' "$LOG_PREFIX" >&2
  exit 1
fi

# ============================================================================
# STEP 9: Check idempotency
# ============================================================================

if [ -f "$MCP_JSON" ]; then
  # Compare via normalized JSON (parse and reformat both)
  EXISTING_NORMALIZED=""
  MERGED_NORMALIZED=""

  if [ $HAS_PYTHON3 -eq 1 ]; then
    EXISTING_NORMALIZED="$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.stdin.read()), sort_keys=True))" < "$MCP_JSON" 2>/dev/null || echo '')"
    MERGED_NORMALIZED="$(printf '%s' "$MERGED_JSON" | python3 -c "import json, sys; print(json.dumps(json.loads(sys.stdin.read()), sort_keys=True))" 2>/dev/null || echo '')"
  elif [ $HAS_JQ -eq 1 ]; then
    EXISTING_NORMALIZED="$(jq -S . "$MCP_JSON" 2>/dev/null | jq -c . || echo '')"
    MERGED_NORMALIZED="$(printf '%s' "$MERGED_JSON" | jq -S . 2>/dev/null | jq -c . || echo '')"
  fi

  if [ -n "$EXISTING_NORMALIZED" ] && [ -n "$MERGED_NORMALIZED" ] && [ "$EXISTING_NORMALIZED" = "$MERGED_NORMALIZED" ]; then
    # No change needed
    printf '%s OK: .mcp.json is already up to date.\n' "$LOG_PREFIX"
    exit 0
  fi
fi

# ============================================================================
# STEP 10: Handle --dry-run
# ============================================================================

if [ "$DRY_RUN" -eq 1 ]; then
  printf '%s --dry-run: Would write this to %s:\n' "$LOG_PREFIX" "$MCP_JSON"
  printf '%s\n' "$MERGED_JSON"
  printf '%s --dry-run: No files were modified.\n' "$LOG_PREFIX"
  exit 0
fi

# ============================================================================
# STEP 11: Backup existing .mcp.json on first write only
# ============================================================================

if [ -f "$MCP_JSON" ] && [ ! -f "$MCP_JSON_BAK" ]; then
  cp "$MCP_JSON" "$MCP_JSON_BAK"
  printf '%s Backed up existing .mcp.json to .mcp.json.bak\n' "$LOG_PREFIX"
fi

# ============================================================================
# STEP 12: Write .mcp.json atomically
# ============================================================================

# Create temp file as a sibling of the destination to ensure atomic rename
# within the same filesystem. Use explicit directory and template.
TEMP_FILE="$PROJECT_ROOT/.mcp.json.XXXXXX"
if ! TEMP_FILE="$(mktemp "$TEMP_FILE")"; then
  printf '%s ERROR: Could not create temporary file for atomic write.\n' "$LOG_PREFIX" >&2
  exit 1
fi

# Cleanup handler: remove temp file on exit, but preserve it on mv failure for diagnosis
trap "rm -f '$TEMP_FILE'" EXIT

printf '%s' "$MERGED_JSON" > "$TEMP_FILE"

# Atomic rename (move) — because temp is a sibling, this stays within one filesystem
if ! mv "$TEMP_FILE" "$MCP_JSON"; then
  printf '%s ERROR: Could not write to %s.\n' "$LOG_PREFIX" "$MCP_JSON" >&2
  printf '%s ERROR: Temporary file preserved at %s for diagnosis.\n' "$LOG_PREFIX" "$TEMP_FILE" >&2
  # Remove trap so temp file is not deleted
  trap - EXIT
  exit 1
fi

printf '%s Updated .mcp.json with bishop-memory server entry.\n' "$LOG_PREFIX"

# ============================================================================
# STEP 13: Health check on the bishop-memory service
# ============================================================================

HEALTH_CHECK_URL="${BISHOP_MEMORY_URL}/healthz"
if command -v curl >/dev/null 2>&1; then
  if curl -s --max-time 2 "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
    printf '%s Service health check OK: %s is responding.\n' "$LOG_PREFIX" "$BISHOP_MEMORY_URL"
  else
    printf '%s WARNING: Could not reach %s at %s\n' "$LOG_PREFIX" "bishop-memory" "$BISHOP_MEMORY_URL" >&2
    printf '%s NEXT: Start the service before running a mission: cd %s && make run\n' "$LOG_PREFIX" "$BISHOP_MEMORY_HOME" >&2
  fi
else
  printf '%s INFO: curl not found. Health check skipped. (Service should be running before you use central memory mode.)\n' "$LOG_PREFIX"
fi

# ============================================================================
# STEP 14: Next steps for the operator
# ============================================================================

printf '%s\n' "$LOG_PREFIX"
printf '%s Manual next steps:\n' "$LOG_PREFIX"
printf '%s   1. Restart Claude Code (full exit and relaunch) so it loads the updated .mcp.json.\n' "$LOG_PREFIX"
printf '%s   2. When Claude Code relaunches, you will be prompted to approve the bishop-memory\n' "$LOG_PREFIX"
printf '%s      MCP server. Approve it — until you do, the server stays inert and missions\n' "$LOG_PREFIX"
printf '%s      cannot use central memory allocation.\n' "$LOG_PREFIX"
printf '%s\n' "$LOG_PREFIX"

exit 0

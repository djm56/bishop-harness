#!/bin/sh
#
# completion-gate.sh
#
# The one place the harness genuinely says no.
#
# Takes hook JSON on stdin. When a Write or Edit to ACTIVE-TASK.md tries to set Status
# to "complete", this refuses unless that task already has a DONE-REPORT.md on disk.
#
# It fails open on purpose: no jq, unparseable JSON, anything unexpected — exit 0 and
# let the work through. A gate that jams the whole loop is worse than one that misses.
#

# Find the project root. Trust CLAUDE_PROJECT_DIR when it's set; otherwise walk up from the script.
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
else
  # We live at .claude/hooks/completion-gate.sh, so the root is two levels up.
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# No jq, no parsing. Step aside.
if ! command -v jq >/dev/null 2>&1; then
  echo "[completion-gate.sh] WARNING: jq not found on PATH. Skipping hook (fail-open)." >&2
  exit 0
fi

# The hook payload arrives on stdin.
HOOK_JSON="$(cat)"

# Which file is being written?
FILE_PATH="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
if [ -z "$FILE_PATH" ]; then
  echo "[completion-gate.sh] WARNING: Could not extract file_path from hook JSON. Skipping (fail-open)." >&2
  exit 0
fi

# Only ACTIVE-TASK.md is our business.
FILE_BASENAME="$(basename "$FILE_PATH")"
if [ "$FILE_BASENAME" != "ACTIVE-TASK.md" ]; then
  # Something else entirely. Let it through.
  exit 0
fi

# Grab what's being written — Write puts it in content, Edit in new_string.
CONTENT="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)"
if [ -z "$CONTENT" ]; then
  echo "[completion-gate.sh] WARNING: Could not extract content from hook JSON. Skipping (fail-open)." >&2
  exit 0
fi

# Is this actually trying to close the task? Case-insensitive, whole word only.
if ! printf '%s' "$CONTENT" | grep -iq 'Status:[[:space:]]*complete[[:space:]]*$'; then
  # Not a completion. Not our problem.
  exit 0
fi

# Pull the Task ID out of the content. The line may carry a leading "- ", so match
# loosely rather than anchoring to the start.
TASK_ID="$(printf '%s' "$CONTENT" | grep -i 'Task ID:' | sed -E 's/.*[Tt]ask [Ii][Dd]:[[:space:]]*(task-[0-9a-zA-Z_-]+).*/\1/' | head -1)"
if [ -z "$TASK_ID" ]; then
  echo "[completion-gate.sh] WARNING: Could not parse Task ID from ACTIVE-TASK.md content. Skipping (fail-open)." >&2
  exit 0
fi

# Does the report exist?
DONE_REPORT_PATH="$PROJECT_ROOT/.claude/memory/tasks/$TASK_ID/DONE-REPORT.md"
if [ -f "$DONE_REPORT_PATH" ]; then
  # It does. The task may close.
  exit 0
else
  # It doesn't. Stop here.
  REASON="Completion gate: DONE-REPORT.md missing for $TASK_ID. Create it before marking the task complete."

  # Escape backslashes and quotes so the reason can't break the JSON we emit.
  REASON_ESCAPED="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  # Hand the refusal back to Claude Code.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$REASON_ESCAPED"

  # Non-zero as well, for good measure.
  exit 2
fi

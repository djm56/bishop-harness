#!/bin/sh
#
# state-continuity.sh
#
# Advisory only. This hook never blocks anything.
#
# It takes a quick look at whether EVENT-LOG.md has actually moved for the active
# task — a cheap way to notice a missed state-sync before it becomes a mystery.
#
# Always exits 0. Missing log, empty log, or a newest row belonging to some other
# task earns a soft warning on stdout; otherwise it says nothing at all.
# No jq needed here — grep, sed and tail do the job.
#

# Find the project root. Trust CLAUDE_PROJECT_DIR when it's set; otherwise walk up from the script.
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
else
  # We live at .claude/hooks/state-continuity.sh, so the root is two levels up.
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# Which task is currently active?
ACTIVE_TASK_FILE="$PROJECT_ROOT/.claude/memory/state/ACTIVE-TASK.md"
if [ ! -f "$ACTIVE_TASK_FILE" ]; then
  # No file, nothing to compare against.
  exit 0
fi

ACTIVE_TASK_ID="$(grep -i 'Task ID:' "$ACTIVE_TASK_FILE" 2>/dev/null | sed -E 's/.*[Tt]ask [Ii][Dd]:[[:space:]]*(task-[0-9a-zA-Z_-]+).*/\1/' | head -1)"
if [ -z "$ACTIVE_TASK_ID" ]; then
  # Couldn't read an id. Leave it alone.
  exit 0
fi

# Now look at the newest row in the journal.
EVENT_LOG_FILE="$PROJECT_ROOT/.claude/memory/state/EVENT-LOG.md"
if [ ! -f "$EVENT_LOG_FILE" ]; then
  # The journal isn't there at all.
  printf '{"systemMessage":"State-continuity warning: EVENT-LOG.md is missing for active task %s."}\n' "$ACTIVE_TASK_ID"
  exit 0
fi

# Take the last data row, skipping the header and the |---|---| separator.
LAST_ROW="$(grep -E '^\|[^-]' "$EVENT_LOG_FILE" 2>/dev/null | grep -v 'Timestamp' | tail -1)"
if [ -z "$LAST_ROW" ]; then
  # Journal exists but has nothing in it yet.
  printf '{"systemMessage":"State-continuity warning: EVENT-LOG.md has no data rows for active task %s."}\n' "$ACTIVE_TASK_ID"
  exit 0
fi

# Second column is the Task ID: | Timestamp | Task ID | Step | Agent | Event | Note |
LAST_TASK_ID="$(printf '%s' "$LAST_ROW" | sed -E 's/^\|[^|]*\|[[:space:]]*(task-[0-9a-zA-Z_-]+).*/\1/')"
if [ -z "$LAST_TASK_ID" ]; then
  # The row didn't parse.
  printf '{"systemMessage":"State-continuity warning: Could not parse Task ID from EVENT-LOG.md last row."}\n' "$ACTIVE_TASK_ID"
  exit 0
fi

# If the newest row belongs to a different task, the log has probably fallen behind.
if [ "$LAST_TASK_ID" != "$ACTIVE_TASK_ID" ]; then
  printf '{"systemMessage":"State-continuity warning: EVENT-LOG.md may not have advanced for %s (newest row is for %s)."}\n' "$ACTIVE_TASK_ID" "$LAST_TASK_ID"
fi

# Always 0. This hook advises; it never blocks.
exit 0

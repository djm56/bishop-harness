#!/bin/sh
#
# state-continuity.sh
#
# Advisory only. This hook never blocks anything.
#
# It takes a quick look at whether FLIGHT-RECORDER.md has actually moved for the active
# mission — a cheap way to notice a missed state-sync before it becomes a mystery.
#
# Always exits 0. Missing log, empty log, or a newest row belonging to some other
# mission earns a soft warning on stdout; otherwise it says nothing at all.
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

# Which mission is currently active?
CURRENT_MISSION_FILE="$PROJECT_ROOT/.claude/memory/state/CURRENT-MISSION.md"
if [ ! -f "$CURRENT_MISSION_FILE" ]; then
  # No file, nothing to compare against.
  exit 0
fi

CURRENT_MISSION_ID="$(grep -i 'Mission ID:' "$CURRENT_MISSION_FILE" 2>/dev/null | sed -n -E 's/.*[Mm]ission [Ii][Dd]:[[:space:]]*(mission-[0-9a-zA-Z_-]+).*/\1/p' | head -1)"
if [ -z "$CURRENT_MISSION_ID" ]; then
  # Couldn't read an id. Leave it alone.
  exit 0
fi

# Now look at the newest row in the journal.
FLIGHT_RECORDER_FILE="$PROJECT_ROOT/.claude/memory/state/FLIGHT-RECORDER.md"
if [ ! -f "$FLIGHT_RECORDER_FILE" ]; then
  # The journal isn't there at all.
  printf '{"systemMessage":"State-continuity warning: FLIGHT-RECORDER.md is missing for active mission %s."}\n' "$CURRENT_MISSION_ID"
  exit 0
fi

# Take the last data row, skipping the header and the |---|---| separator.
LAST_ROW="$(grep -E '^\|[^-]' "$FLIGHT_RECORDER_FILE" 2>/dev/null | grep -v 'Timestamp' | tail -1)"
if [ -z "$LAST_ROW" ]; then
  # Journal exists but has nothing in it yet.
  printf '{"systemMessage":"State-continuity warning: FLIGHT-RECORDER.md has no data rows for active mission %s."}\n' "$CURRENT_MISSION_ID"
  exit 0
fi

# Second column is the Mission ID: | Timestamp | Mission ID | Step | Agent | Event | Note |
LAST_MISSION_ID="$(printf '%s' "$LAST_ROW" | sed -n -E 's/^\|[^|]*\|[[:space:]]*(mission-[0-9a-zA-Z_-]+).*/\1/p')"
if [ -z "$LAST_MISSION_ID" ]; then
  # The row didn't parse.
  printf '{"systemMessage":"State-continuity warning: Could not parse Mission ID from FLIGHT-RECORDER.md last row."}\n' "$CURRENT_MISSION_ID"
  exit 0
fi

# If the newest row belongs to a different mission, the log has probably fallen behind.
if [ "$LAST_MISSION_ID" != "$CURRENT_MISSION_ID" ]; then
  printf '{"systemMessage":"State-continuity warning: FLIGHT-RECORDER.md may not have advanced for %s (newest row is for %s)."}\n' "$CURRENT_MISSION_ID" "$LAST_MISSION_ID"
fi

# Always 0. This hook advises; it never blocks.
exit 0

#!/bin/sh
#
# state-continuity.sh
#
# Advisory only. This hook never blocks anything.
#
# Three checks, always exits 0:
#
# 1. Cross-mission staleness (active mission must have logged before): detects when the
#    newest FLIGHT-RECORDER.md row belongs to a different mission than the active one,
#    but only once the active mission has at least one row of its own in the journal.
#    Silent while a newly-initialized mission hasn't synced its first row yet — that's
#    the ordinary shape of mission startup, not staleness.
#
# 2. Within-mission lag (ordinary writes only): compares the last done step in PROGRESS.md
#    against the newest journal row's Step field, but only when the triggering write is
#    ordinary work (not part of state machinery). Skipped during state-sync to avoid
#    false positives on mid-flight editorial sequences.
#
# 3. Structural validation: checks the newest row for required table shape — leading and
#    trailing pipes, 6 cells, valid timestamp, and temporal ordering. Runs on all writes.
#
# Always exits 0. Warnings go to stdout as JSON; no warnings means silence.
#

# Find the project root. Trust CLAUDE_PROJECT_DIR when it's set; otherwise walk up from the script.
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
else
  # We live at .claude/hooks/state-continuity.sh, so the root is two levels up.
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# Read hook JSON from stdin (once, into a variable to avoid hangs).
HOOK_JSON="$(cat)"

# Extract file_path from the hook JSON to determine if this is ordinary work or state machinery.
# Try jq first if available; fall back to sed/grep on failure or jq absence.
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
fi

# If jq didn't resolve the path (jq absent, failed, or empty result), try a sed fallback.
if [ -z "$FILE_PATH" ]; then
  FILE_PATH="$(printf '%s' "$HOOK_JSON" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# Determine whether to run the lag check (G1).
# Skip G1 if file_path is empty (extraction failed) or if it's under .claude/memory/ (state machinery).
RUN_LAG_CHECK="yes"
if [ -z "$FILE_PATH" ] || printf '%s' "$FILE_PATH" | grep -q '\.claude/memory/'; then
  RUN_LAG_CHECK="no"
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

# G0: Gate the cross-mission check on the active mission having logged at least one row
# of its own. A new mission's CURRENT-MISSION.md is updated (bishop.md, "Standing Up A
# New Mission", item 4) before that mission's own first FLIGHT-RECORDER.md row exists
# (item 5, then the step-1 sync) — during that ordinary-work window the newest row is
# expected to belong to the mission before it, and that's initialization, not staleness.
# This is a different condition than G1's RUN_LAG_CHECK on purpose: G1's false positive
# is mid-flight within one multi-edit sync, so it gates on which file a write touched.
# This one's false positive spans ordinary work between two unrelated syncs and touches
# no particular file, so it gates on journal content instead.
CURRENT_MISSION_HAS_ROWS="no"
if grep -E '^\|[^-]' "$FLIGHT_RECORDER_FILE" 2>/dev/null | grep -v 'Timestamp' | sed -n -E 's/^\|[^|]*\|[[:space:]]*(mission-[0-9a-zA-Z_-]+).*/\1/p' | grep -qx "$CURRENT_MISSION_ID"; then
  CURRENT_MISSION_HAS_ROWS="yes"
fi

# If the newest row belongs to a different mission, and the active mission has logged
# before, the log has probably fallen behind. Silent when the active mission has no
# rows yet at all — see the gate above.
if [ "$LAST_MISSION_ID" != "$CURRENT_MISSION_ID" ] && [ "$CURRENT_MISSION_HAS_ROWS" = "yes" ]; then
  printf '{"systemMessage":"State-continuity warning: FLIGHT-RECORDER.md may not have advanced for %s (newest row is for %s)."}\n' "$CURRENT_MISSION_ID" "$LAST_MISSION_ID"
fi

# G1: Detect within-mission sync lag (only on ordinary work, not state machinery).
if [ "$RUN_LAG_CHECK" = "yes" ] && [ "$LAST_MISSION_ID" = "$CURRENT_MISSION_ID" ]; then
  PROGRESS_FILE="$PROJECT_ROOT/.claude/memory/missions/$CURRENT_MISSION_ID/PROGRESS.md"
  if [ -f "$PROGRESS_FILE" ]; then
    # Find the last row with Status = "done" (case-insensitive)
    LAST_DONE_STEP="$(grep -iE '^\|[^|]+\|[^|]+\|[^|]+\|[[:space:]]*done[[:space:]]*\|' "$PROGRESS_FILE" 2>/dev/null | tail -1 | sed -n -E 's/^\|[[:space:]]*([^|]+)\|.*/\1/p' | sed 's/[[:space:]]*$//')"

    if [ -n "$LAST_DONE_STEP" ]; then
      # Extract the Step field from the last journal row (third column)
      JOURNAL_STEP="$(printf '%s' "$LAST_ROW" | sed -n -E 's/^\|[^|]*\|[^|]*\|[[:space:]]*([^|]+)\|.*/\1/p' | sed 's/[[:space:]]*$//')"

      # Only compare if the journal Step is not "—" (completion or blocked event)
      if [ "$JOURNAL_STEP" != "—" ]; then
        if [ "$LAST_DONE_STEP" != "$JOURNAL_STEP" ]; then
          # Escape backslashes and quotes for JSON output (K5)
          LAST_DONE_STEP_ESCAPED="$(printf '%s' "$LAST_DONE_STEP" | sed 's/\\/\\\\/g; s/"/\\"/g')"
          JOURNAL_STEP_ESCAPED="$(printf '%s' "$JOURNAL_STEP" | sed 's/\\/\\\\/g; s/"/\\"/g')"
          printf '{"systemMessage":"State-continuity warning: PROGRESS.md last done step is %s but FLIGHT-RECORDER.md newest row has step %s."}\n' "$LAST_DONE_STEP_ESCAPED" "$JOURNAL_STEP_ESCAPED"
        fi
      fi
    fi
  fi
fi

# G2: Validate the newest journal row structurally.
VALIDATION_ERRORS=""

# Check if row begins with | and ends with |
if ! printf '%s' "$LAST_ROW" | grep -q '^|.*|$'; then
  VALIDATION_ERRORS="${VALIDATION_ERRORS}row must begin with | and end with |; "
fi

# Count cells (fields between pipes). A row with 6 cells has 7 pipes.
# Strip escaped pipes (\|) first to avoid counting them as column separators (K1).
CELL_COUNT="$(printf '%s' "$LAST_ROW" | sed 's/\\|//g' | grep -o '|' | wc -l)"
EXPECTED_PIPES=7  # 6 cells means 7 pipes (leading, 5 between, trailing)
if [ "$CELL_COUNT" -ne "$EXPECTED_PIPES" ]; then
  VALIDATION_ERRORS="${VALIDATION_ERRORS}row has $((CELL_COUNT - 1)) cells but should have 6; "
fi

# Validate Timestamp format: YYYY-MM-DD HH:MM UTC (first column)
TIMESTAMP="$(printf '%s' "$LAST_ROW" | sed -n -E 's/^\|[[:space:]]*([^|]+)\|.*/\1/p' | sed 's/[[:space:]]*$//')"
if ! printf '%s' "$TIMESTAMP" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} UTC$'; then
  VALIDATION_ERRORS="${VALIDATION_ERRORS}timestamp format is invalid (expected YYYY-MM-DD HH:MM UTC); "
fi

# Check timestamp ordering with the row above (only if there are at least 2 data rows)
SECOND_LAST_ROW="$(grep -E '^\|[^-]' "$FLIGHT_RECORDER_FILE" 2>/dev/null | grep -v 'Timestamp' | tail -2 | head -1)"
if [ -n "$SECOND_LAST_ROW" ]; then
  PREV_TIMESTAMP="$(printf '%s' "$SECOND_LAST_ROW" | sed -n -E 's/^\|[[:space:]]*([^|]+)\|.*/\1/p' | sed 's/[[:space:]]*$//')"
  if [ -n "$PREV_TIMESTAMP" ] && [ "$TIMESTAMP" != "$PREV_TIMESTAMP" ]; then
    if [ "$TIMESTAMP" \< "$PREV_TIMESTAMP" ]; then
      VALIDATION_ERRORS="${VALIDATION_ERRORS}timestamp is earlier than the previous row; "
    fi
  fi
fi

if [ -n "$VALIDATION_ERRORS" ]; then
  # Remove trailing "; " and report
  VALIDATION_ERRORS="${VALIDATION_ERRORS%; }"
  printf '{"systemMessage":"State-continuity warning: FLIGHT-RECORDER.md newest row has issues: %s"}\n' "$VALIDATION_ERRORS"
fi

# Always 0. This hook advises; it never blocks.
exit 0

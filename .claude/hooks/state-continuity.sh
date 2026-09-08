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

# Mirror LAST_ROW to bishop-memory if configured to do so.
#
# CRITICAL: This section must print NOTHING on any path — success, failure, skip.
# The hook communicates by printing a single JSON object to stdout.
# A second printf would emit concatenated JSON objects and corrupt the hook's
# output contract. All mirroring work is silent by design.
#
# Fail open: any missing config, tool, parsing error, network failure, or
# non-2xx response results in skipping silently and continuing to exit 0.
#

# Gate 1: Configuration file and mode check.
CONFIG_FILE="$PROJECT_ROOT/.claude/bishop-memory.conf"
if [ -f "$CONFIG_FILE" ]; then
  # Source and call the shared conf parser. Fail open if it's missing or fails.
  LIB_FILE="$PROJECT_ROOT/.claude/lib/bishop-memory-conf.sh"
  # Guard on both existence and readability. [ -f ] alone passes unreadable files,
  # which then fail when sourced (and on strict sh may be fatal). [ -r ] correctly
  # refuses. Syntax errors in the sourced file are caught by the || exit 0 below;
  # this check covers the file-not-readable case that [ -f ] would miss.
  if [ ! -f "$LIB_FILE" ] || [ ! -r "$LIB_FILE" ]; then
    exit 0
  fi
  . "$LIB_FILE" 2>/dev/null || exit 0
  bishop_memory_read_conf "$CONFIG_FILE" || exit 0

  # Map the shared variables to hook-local names for use below.
  MIRROR_MODE="$BISHOP_MEMORY_MODE"
  MIRROR_URL="$BISHOP_MEMORY_URL"
  MIRROR_HARNESS="$BISHOP_HARNESS"

  # Skip if mode is not central, or if harness ID is empty.
  if [ "$MIRROR_MODE" != "central" ] || [ -z "$MIRROR_HARNESS" ]; then
    exit 0
  fi

  # Default the URL if unset.
  if [ -z "$MIRROR_URL" ]; then
    MIRROR_URL="http://127.0.0.1:8787"
  fi

  # Gate 2: Required tools.
  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    exit 0
  fi

  # Gate 3: Skip if the newest row is structurally invalid (VALIDATION_ERRORS is set above).
  if [ -n "$VALIDATION_ERRORS" ]; then
    exit 0
  fi

  # Gate 4: Parse the row and normalize fields.
  # Schema: | Timestamp | Mission ID | Step | Agent | Event | Note |
  # With FS="|", leading/trailing pipes produce empty first/last fields.
  # So fields are: 2=timestamp, 3=mission, 4=step, 5=agent, 6=event, 7+...=note (rejoin with |).
  # Output 6 values as newline-delimited lines with no quoting or escaping.
  # Newline is safe as a delimiter because a journal row is a single line (no value can contain newline).
  PARSED_FILE="$(mktemp)" || exit 0

  printf '%s' "$LAST_ROW" | awk -F'|' '{
    # Extract fields before trimming (awk indices account for leading/trailing empty fields).
    ts = $2
    mission = $3
    step = $4
    agent = $5
    event = $6
    # Note is everything from field 7 onwards, rejoin with | first (before trimming).
    # NF is the empty field after the trailing pipe in the markdown, so use NF-1.
    note = ""
    for (i = 7; i < NF; i++) {
      note = note (note ? "|" : "") $i
    }
    # Unescape \| in the reassembled note.
    gsub(/\\\|/, "|", note)
    # Now trim each field individually (note is the reassembled, unescaped version).
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", ts)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", mission)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", step)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", agent)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", event)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", note)
    # Output values as separate lines with no quoting or escaping (newline is safe delimiter).
    printf "%s\n%s\n%s\n%s\n%s\n%s\n", ts, mission, step, agent, event, note
  }' 2>/dev/null > "$PARSED_FILE"

  if [ ! -s "$PARSED_FILE" ]; then
    exit 0
  fi

  # Read the 6 values from the temp file using input redirection, not pipes.
  # This keeps the assignments in the current shell instead of a subshell.
  { IFS= read -r MIRROR_TS
    IFS= read -r MIRROR_MISSION
    IFS= read -r MIRROR_STEP
    IFS= read -r MIRROR_AGENT
    IFS= read -r MIRROR_EVENT
    IFS= read -r MIRROR_NOTE
  } < "$PARSED_FILE" || exit 0

  # Normalize placeholders: treat "—" and empty as absent.
  # Trim whitespace first, then check for placeholders.
  MIRROR_STEP="$(printf '%s' "$MIRROR_STEP" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ "$MIRROR_STEP" = "—" ] && MIRROR_STEP=""

  MIRROR_AGENT="$(printf '%s' "$MIRROR_AGENT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ "$MIRROR_AGENT" = "—" ] && MIRROR_AGENT=""

  MIRROR_EVENT="$(printf '%s' "$MIRROR_EVENT" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ "$MIRROR_EVENT" = "—" ] && MIRROR_EVENT=""

  MIRROR_NOTE="$(printf '%s' "$MIRROR_NOTE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ "$MIRROR_NOTE" = "—" ] && MIRROR_NOTE=""

  # Required fields: event and note.
  if [ -z "$MIRROR_EVENT" ] || [ -z "$MIRROR_NOTE" ]; then
    exit 0
  fi

  # Check field length caps. Skip the row if any non-note field exceeds its cap.
  if [ "${#MIRROR_STEP}" -gt 16 ] || [ "${#MIRROR_AGENT}" -gt 64 ] || [ "${#MIRROR_EVENT}" -gt 64 ] || [ "${#MIRROR_TS}" -gt 64 ]; then
    exit 0
  fi

  # Truncate note to 2000 characters. Use cut to enforce exact character limit.
  if [ "${#MIRROR_NOTE}" -gt 2000 ]; then
    MIRROR_NOTE="$(printf '%s' "$MIRROR_NOTE" | cut -c1-2000)"
  fi

  # Gate 5: Mutex and cursor, to avoid duplicate events.
  # Cursor path: .claude/memory/state/.bishop-memory-cursor
  # Lock path: .claude/memory/state/.bishop-memory-lock
  # This directory is deliberately closed (per CREW-MANIFEST.md) to hold
  # "machine-written state from a registered hook" — exactly what these are.
  CURSOR_FILE="$PROJECT_ROOT/.claude/memory/state/.bishop-memory-cursor"
  LOCK_DIR="$PROJECT_ROOT/.claude/memory/state/.bishop-memory-lock"
  LOCK_THRESHOLD=60  # seconds. Stale locks older than this are removed. The hook
                     # has a 10s timeout and curl has a 2s budget, so 60s generously
                     # covers normal execution and detects truly abandoned locks.

  # Try to acquire the lock. If it already exists, another hook invocation is
  # mirroring — skip silently to avoid duplicates. If it's stale (older than
  # LOCK_THRESHOLD), remove it and retry.
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    # Lock acquired. Set up trap to release it and clean up temp file on all exit paths.
    trap "rm -f '$PARSED_FILE' 2>/dev/null; rmdir '$LOCK_DIR' 2>/dev/null" EXIT

    # Compute checksum of LAST_ROW (without leading/trailing whitespace).
    ROW_CHECKSUM="$(printf '%s' "$LAST_ROW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | cksum | awk '{print $1}')"

    # If cursor exists and contains the same checksum, skip (already mirrored).
    if [ -f "$CURSOR_FILE" ]; then
      LAST_CHECKSUM="$(cat "$CURSOR_FILE" 2>/dev/null)"
      if [ "$LAST_CHECKSUM" = "$ROW_CHECKSUM" ]; then
        exit 0
      fi
    fi

    # Build the JSON request. Omit absent fields (step, agent) but never omit
    # occurred_at (timestamp), mission_id, event, or note (already gated above).
    JSON_BODY="$(jq -n \
      --arg ts "$MIRROR_TS" \
      --arg mission "$MIRROR_MISSION" \
      --arg step "$MIRROR_STEP" \
      --arg agent "$MIRROR_AGENT" \
      --arg event "$MIRROR_EVENT" \
      --arg note "$MIRROR_NOTE" \
      '{
        occurred_at: $ts,
        mission_id: $mission,
        event: $event,
        note: $note
      } | if $step != "" then .step = $step else . end | if $agent != "" then .agent = $agent else . end' \
      2>/dev/null)"

    if [ -z "$JSON_BODY" ]; then
      exit 0
    fi

    # POST the request. Use a 2s timeout (the hook's 10s budget is not for hanging).
    # Capture the HTTP status code. Fail open on any error.
    HTTP_CODE="$(curl --silent --show-error --max-time 2 \
      -X POST \
      "$MIRROR_URL/v1/flight-recorder" \
      -H "Content-Type: application/json" \
      -d "$JSON_BODY" \
      --output /dev/null \
      --write-out '%{http_code}' \
      2>/dev/null)"

    # Check for 2xx success codes (200, 201, etc). Non-2xx means the request failed.
    if [ -z "$HTTP_CODE" ] || ! printf '%s' "$HTTP_CODE" | grep -qE '^2[0-9][0-9]$'; then
      # Request failed or non-2xx response. Leave the cursor untouched so
      # the next write will retry naturally. Fail open and continue.
      exit 0
    fi

    # 2xx response confirmed. Write the cursor only now, so a failed POST
    # leaves it untouched for retry.
    printf '%s' "$ROW_CHECKSUM" > "$CURSOR_FILE" 2>/dev/null || true

    exit 0
  else
    # Lock directory already exists. Check if it's stale (older than LOCK_THRESHOLD).
    LOCK_MTIME="$(stat -f '%m' "$LOCK_DIR" 2>/dev/null)" || exit 0
    CURRENT_TIME="$(date +%s)"
    LOCK_AGE=$((CURRENT_TIME - LOCK_MTIME))

    if [ "$LOCK_AGE" -gt "$LOCK_THRESHOLD" ]; then
      # Lock is stale. Remove it and retry.
      rmdir "$LOCK_DIR" 2>/dev/null && mkdir "$LOCK_DIR" 2>/dev/null && {
        # Lock acquired. Set up trap to release it and clean up temp file on all exit paths.
        trap "rm -f '$PARSED_FILE' 2>/dev/null; rmdir '$LOCK_DIR' 2>/dev/null" EXIT

        # Compute checksum of LAST_ROW (without leading/trailing whitespace).
        ROW_CHECKSUM="$(printf '%s' "$LAST_ROW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | cksum | awk '{print $1}')"

        # If cursor exists and contains the same checksum, skip (already mirrored).
        if [ -f "$CURSOR_FILE" ]; then
          LAST_CHECKSUM="$(cat "$CURSOR_FILE" 2>/dev/null)"
          if [ "$LAST_CHECKSUM" = "$ROW_CHECKSUM" ]; then
            exit 0
          fi
        fi

        # Build the JSON request.
        JSON_BODY="$(jq -n \
          --arg ts "$MIRROR_TS" \
          --arg mission "$MIRROR_MISSION" \
          --arg step "$MIRROR_STEP" \
          --arg agent "$MIRROR_AGENT" \
          --arg event "$MIRROR_EVENT" \
          --arg note "$MIRROR_NOTE" \
          '{
            occurred_at: $ts,
            mission_id: $mission,
            event: $event,
            note: $note
          } | if $step != "" then .step = $step else . end | if $agent != "" then .agent = $agent else . end' \
          2>/dev/null)"

        if [ -z "$JSON_BODY" ]; then
          exit 0
        fi

        # POST the request.
        HTTP_CODE="$(curl --silent --show-error --max-time 2 \
          -X POST \
          "$MIRROR_URL/v1/flight-recorder" \
          -H "Content-Type: application/json" \
          -d "$JSON_BODY" \
          --output /dev/null \
          --write-out '%{http_code}' \
          2>/dev/null)"

        # Check for 2xx success codes.
        if [ -z "$HTTP_CODE" ] || ! printf '%s' "$HTTP_CODE" | grep -qE '^2[0-9][0-9]$'; then
          exit 0
        fi

        # 2xx response confirmed. Write the cursor.
        printf '%s' "$ROW_CHECKSUM" > "$CURSOR_FILE" 2>/dev/null || true

        exit 0
      }
    fi
    # Lock exists and is fresh. Another invocation is handling this row. Skip silently.
    exit 0
  fi
fi

# Always 0. This hook advises; it never blocks.
exit 0

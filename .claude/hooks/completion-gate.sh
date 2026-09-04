#!/bin/sh
#
# completion-gate.sh
#
# The one place the harness genuinely says no.
#
# Takes hook JSON on stdin. When a Write or Edit to CURRENT-MISSION.md tries to set Status
# to "complete", this refuses unless that mission already has a DEBRIEF.md on disk with both
# mandatory sections ("Wrong Assumptions" and "Sub-Agent Mistakes and Corrections") present
# and populated.
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

# No awk, no section checking. Step aside.
if ! command -v awk >/dev/null 2>&1; then
  echo "[completion-gate.sh] WARNING: awk not found on PATH. Skipping hook (fail-open)." >&2
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

# Only CURRENT-MISSION.md is our business.
FILE_BASENAME="$(basename "$FILE_PATH")"
if [ "$FILE_BASENAME" != "CURRENT-MISSION.md" ]; then
  # Something else entirely. Let it through.
  exit 0
fi

# Grab what's being written — Write puts it in content, Edit in new_string.
CONTENT="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)"
if [ -z "$CONTENT" ]; then
  echo "[completion-gate.sh] WARNING: Could not extract content from hook JSON. Skipping (fail-open)." >&2
  exit 0
fi

# Is this actually trying to close the task? Case-insensitive. Two ways to detect it:
# 1. The field list or table row shape: "- Status: complete" or "| Status | complete |"
# 2. The bypass case: the edit's new_string is exactly "complete" (nothing else)
COMPLETION_DETECTED=0

if printf '%s' "$CONTENT" | grep -iqE 'Status[[:space:]]*[|:][[:space:]]*complete([[:space:]]|\||$)'; then
  COMPLETION_DETECTED=1
else
  # Check if content (with leading/trailing whitespace stripped) is exactly "complete"
  CONTENT_TRIMMED="$(printf '%s' "$CONTENT" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if printf '%s' "$CONTENT_TRIMMED" | grep -iqE '^complete$'; then
    COMPLETION_DETECTED=1
  fi
fi

if [ "$COMPLETION_DETECTED" -eq 0 ]; then
  # Not a completion. Not our problem.
  exit 0
fi

# Pull the Mission ID out of the content. Find any line mentioning "Mission ID" — field list
# or table row, the separator doesn't matter — then take the first mission-<id> token off
# it. Matches mission-YYYYMMDD-NN and anything else of that shape.
MISSION_ID="$(printf '%s' "$CONTENT" | grep -iE 'Mission[[:space:]]*ID' | grep -oE 'mission-[0-9A-Za-z_-]+' | head -1)"

# If the content doesn't have a mission ID (e.g., bypass case of bare "complete"),
# try to read it from the file on disk (which still has the pre-edit content).
if [ -z "$MISSION_ID" ] && [ -f "$FILE_PATH" ]; then
  MISSION_ID="$(grep -iE 'Mission[[:space:]]*ID' "$FILE_PATH" 2>/dev/null | grep -oE 'mission-[0-9A-Za-z_-]+' | head -1)"
fi

if [ -z "$MISSION_ID" ]; then
  echo "[completion-gate.sh] WARNING: Could not parse Mission ID from CURRENT-MISSION.md content or disk. Skipping (fail-open)." >&2
  exit 0
fi

# Does the report exist?
DEBRIEF_PATH="$PROJECT_ROOT/.claude/memory/missions/$MISSION_ID/DEBRIEF.md"
if [ ! -f "$DEBRIEF_PATH" ]; then
  # It doesn't. Stop here.
  REASON="Completion gate: DEBRIEF.md missing for $MISSION_ID. Create it before marking the mission complete."

  # Escape backslashes and quotes so the reason can't break the JSON we emit.
  REASON_ESCAPED="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  # Hand the refusal back to Claude Code.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$REASON_ESCAPED"

  # Non-zero as well, for good measure.
  exit 2
fi

# The DEBRIEF exists. Check for readability first (F4).
if [ ! -r "$DEBRIEF_PATH" ]; then
  # File exists but is not readable. Fail open, not closed.
  exit 0
fi

# The DEBRIEF exists and is readable. Now check for mandatory sections.
# Look for "Wrong Assumptions" and "Sub-Agent Mistakes" headings.
# Each section must have at least 3 lines beginning with "|" (header, separator, data).

# Helper function to extract a section and count table rows
check_section() {
  section_name="$1"
  heading_pattern="$2"
  debrief_file="$3"

  # Extract the section: from the heading line to the next line starting with "## " or EOF
  # Pass pattern as data to avoid syntax errors from special characters (F5)
  section_content="$(awk -v pat="$heading_pattern" '$0 ~ pat {p=1; next} /^##[[:space:]]/{if(p) exit} p' "$debrief_file" 2>/dev/null)"
  awk_rc=$?

  # If awk failed to run, return 3 (indeterminate) (F1)
  if [ "$awk_rc" -ne 0 ]; then
    return 3
  fi

  if [ -z "$section_content" ]; then
    # Section not found
    return 1
  fi

  # Count lines beginning with "|"
  pipe_count=$(printf '%s' "$section_content" | grep -c '^|')

  if [ "$pipe_count" -lt 3 ]; then
    # Section exists but doesn't have enough rows
    return 2
  fi

  # Section is good
  return 0
}

# Check mandatory sections in a loop (F6)
# Collapse the two duplicated call sites into one iteration over both sections
sections="
Wrong Assumptions:^##[[:space:]]*Wrong Assumptions
Sub-Agent Mistakes:^##[[:space:]]*Sub-Agent Mistakes
"

while IFS=: read -r section_display section_pattern; do
  [ -z "$section_display" ] && continue

  check_section "$section_display" "$section_pattern" "$DEBRIEF_PATH"
  rc=$?

  # Capture status before testing it (F2). Only deny for 1 and 2. Exit 0 for anything else (fail open).
  case "$rc" in
    0)
      # Section present and populated. Continue to next section.
      continue
      ;;
    1)
      # Section heading absent
      REASON="Completion gate: DEBRIEF.md for $MISSION_ID is missing the '$section_display' section."
      REASON_ESCAPED="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$REASON_ESCAPED"
      exit 2
      ;;
    2)
      # Section present but under-populated
      REASON="Completion gate: DEBRIEF.md for $MISSION_ID has a '$section_display' section but it is empty (fewer than 3 table rows)."
      REASON_ESCAPED="$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$REASON_ESCAPED"
      exit 2
      ;;
    *)
      # Return value 3 or any other value means the check could not be completed.
      # Fail open (F1 and F2): exit 0 and let the work through.
      exit 0
      ;;
  esac
done <<EOF
$sections
EOF

# All checks passed. The mission may close.
exit 0

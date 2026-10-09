#!/bin/sh
#
# qa-guard.sh
#
# Ripley's QA guard: her navigation, her file paths, and her origin allowlist.
#
# Takes hook JSON on stdin. Registered in the hooks: frontmatter of .claude/agents/ripley.md,
# so it runs only while Ripley runs. The rules live in .claude/skills/mission-lifecycle/SKILL.md
# under "### The Hooks" (the qa-guard.sh bullet); this file implements them and does not restate them.
#
# It fails closed, the reverse of completion-gate.sh: no jq, a root that is not absolute, an
# unreadable conf, input that is not JSON, or a jq failure all deny. A denial prints a
# permissionDecision deny object on stdout, the reason on stderr, and exits 2. An allow is silent
# and exits 0.
#
# Shape: POSIX sh does the plumbing (root, conf lines, the decision). One jq program makes the
# decision. It runs every check in order -- conf entries, navigation, save_to_disk, file paths --
# and takes the first error, so no check is skipped because an earlier one passed.
#
# Debt: paths are resolved lexically, so a symlink already inside the QA folder is followed
# by whatever writes through it. The spec records this under "What Is Not Enforced".

# Find the project root. Trust CLAUDE_PROJECT_DIR when it is set; otherwise walk up from the script.
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  ROOT="$CLAUDE_PROJECT_DIR"
else
  # We live at .claude/hooks/qa-guard.sh, so the root is two levels up.
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# deny <reason>: the decision JSON on stdout, the reason on stderr, exit 2.
deny() {
  if ! jq -n -c --arg r "qa-guard.sh: $1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"qa-guard.sh: denied; the reason could not be formatted, see stderr."}}'
  fi
  printf '[qa-guard.sh] %s\n' "$1" >&2
  exit 2
}

# No jq, no checking. Refuse, with the fix named. Fixed JSON, nothing to escape.
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"qa-guard.sh: jq was not found on PATH. Install jq and make it visible to hooks; every Ripley call is refused until then."}}'
  printf '%s\n' '[qa-guard.sh] jq was not found on PATH. Install jq and make it visible to hooks; every Ripley call is refused until then.' >&2
  exit 2
fi

# A root that is not absolute cannot be compared with anything.
case "$ROOT" in
  /*) ;;
  *) deny "the project root \"$ROOT\" is not an absolute path. Set CLAUDE_PROJECT_DIR to an absolute path." ;;
esac

# The hook payload arrives on stdin.
STDIN="$(cat)"
if [ -z "$STDIN" ]; then
  deny "the hook received no input. Every Ripley call is refused until the harness sends the tool call as JSON."
fi

# Read the conf line by line. Never sourced, so it cannot execute anything.
# Last occurrence of a key wins; a final line with no newline is still read.
CONF_PATH="$ROOT/.claude/qa.conf"
QA_ALLOWED=""
QA_BLOCKED=""
ALLOWED_SET=0

if [ -e "$CONF_PATH" ]; then
  if [ ! -f "$CONF_PATH" ] || [ ! -r "$CONF_PATH" ]; then
    deny ".claude/qa.conf exists but cannot be read as a file. Fix its type or permissions, or remove it; every Ripley call is refused until then."
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "" | \#*) continue ;;
    esac
    case "$line" in
      *=*) key="${line%%=*}"; value="${line#*=}" ;;
      *) key="$line"; value="" ;;
    esac
    case "$key" in
      QA_ALLOWED_ORIGINS) QA_ALLOWED="$value"; ALLOWED_SET=1 ;;
      QA_BLOCKED_ORIGINS) QA_BLOCKED="$value" ;;
    esac
  done < "$CONF_PATH"
fi

# Invalid JSON gets its own reason; everything after this point is a jq-program matter.
if ! printf '%s' "$STDIN" | jq empty >/dev/null 2>&1; then
  deny "the hook input is not valid JSON. Every Ripley call is refused until the harness sends valid input."
fi

# The decision. Prints exactly "allow", or "deny<TAB><reason>". jq's own stderr is left alone
# rather than folded into the result.
RESULT="$(printf '%s' "$STDIN" | jq -r \
  --arg root "$ROOT" \
  --arg allowed "$QA_ALLOWED" \
  --arg allowed_set "$ALLOWED_SET" \
  --arg blocked "$QA_BLOCKED" \
  '
def bad_char: explode | any(.[]; . <= 32 or . == 92 or (. >= 127 and . <= 160) or . == 5760 or (. >= 8192 and . <= 8202) or . == 8232 or . == 8233 or . == 8239 or . == 8287 or . == 12288);
def has_ctl: explode | any(.[]; . < 32 or . == 127);
def segs: split("/") | map(select(. != "" and . != "."));
def drop_dot: if (startswith("[") | not) and endswith(".") then .[:-1] else . end;
def default_port: if . == "http" then 80 else 443 end;
def valid_host: if startswith("[") then test("\\A\\[[0-9a-f:.]+\\]\\z") else test("\\A[a-z0-9-]+(\\.[a-z0-9-]+)*\\z") end;
def valid_port: test("\\A[1-9][0-9]{0,4}\\z") and (tonumber <= 65535);
def parse_url:
  if type != "string" or length == 0 then {err: "url must be a non-empty string"}
  elif . == "about:blank" then {blank: true}
  elif bad_char then {err: "url contains a backslash, whitespace or control character"}
  else
    ([capture("\\A(?<scheme>https?)://(?<rest>.*)\\z"; "i")] | .[0]) as $m
    | if $m == null then {err: "url must be about:blank or an absolute http(s) URL"}
      else
        ($m.rest | capture("\\A(?<a>[^/?#]*)").a) as $auth
        | if $auth == "" then {err: "url has an empty host"}
          elif ($auth | contains("@")) then {err: "url carries userinfo (user@host)"}
          else
            ([$auth | capture("\\A(?<h>\\[[^\\]]*\\]|[^:\\[\\]]*)(?::(?<p>.*))?\\z")] | .[0]) as $hp
            | if $hp == null then {err: "url authority is malformed"}
              else
                ($hp.h | ascii_downcase | drop_dot) as $host
                | ($m.scheme | ascii_downcase) as $scheme
                | if ($host | valid_host | not) then {err: "url host is not a valid hostname or IPv6 literal"}
                  elif ($hp.p != null and ($hp.p | valid_port | not)) then {err: "url port is not 1-65535 or has a leading zero"}
                  else {scheme: $scheme, host: $host, port: (if $hp.p == null then ($scheme | default_port) else ($hp.p | tonumber) end)}
                  end
              end
          end
      end
  end;
def parse_entry:
  if type != "string" or has_ctl or bad_char then null
  else
    ([capture("\\A(?<scheme>https?)://(?<h>\\[[^\\]]*\\]|[^:/?#@\\[\\]]+)(?::(?<p>.*))?\\z"; "i")] | .[0]) as $m
    | if $m == null then null
      else
        ($m.h | ascii_downcase) as $h0
        | ($h0 | startswith("*.")) as $wild
        | ((if $wild then $h0[2:] else $h0 end) | drop_dot) as $host
        | ($m.scheme | ascii_downcase) as $scheme
        | if ($host | valid_host | not) or ($wild and ($host | startswith("["))) then null
          elif $m.p == null then {scheme: $scheme, host: $host, wild: $wild, port: ($scheme | default_port)}
          elif $m.p == "*" then {scheme: $scheme, host: $host, wild: $wild, port: "*"}
          elif ($m.p | valid_port) then {scheme: $scheme, host: $host, wild: $wild, port: ($m.p | tonumber)}
          else null
          end
      end
  end;
def origin_match($e; $scheme; $host; $port):
  $e.scheme == $scheme
  and (if $e.wild then ($host | endswith("." + $e.host)) else $host == $e.host end)
  and ($e.port == "*" or $e.port == $port);
def check_list($key; $s):
  if ($s | has_ctl) then
    {errors: ["\($key) contains a control character such as a carriage return; check .claude/qa.conf for CRLF line endings and fix it"], parsed: []}
  else
    ($s | split(" ") | map(select(length > 0)) | map({raw: ., p: parse_entry})) as $r
    | {errors: [$r[] | select(.p == null) | "\($key) has a malformed entry: \(.raw) (expected http(s)://host[:port or :*], no path); fix .claude/qa.conf"],
       parsed: [$r[] | select(.p != null) | .p]}
  end;
def path_ok($key; $rs):
  if length == 0 or startswith("~") or (split("/") | any(. == "..")) then false
  else
    (if startswith("/") then segs else $rs + segs end) as $s
    | ($rs + [".claude", "memory", "workspace", "qa"]) as $qa
    | ($rs + [".claude", "skills", "visual-qa"]) as $vq
    | ($s[:($qa | length)] == $qa) or ($key == "sourcePath" and $s[:($vq | length)] == $vq)
  end;
def path_check($key; $v; $rs):
  if ($v | type) == "string" then
    (if ($v | path_ok($key; $rs)) then [] else ["File path refused: \($key) = \($v | .[:120] | @json) is not inside .claude/memory/workspace/qa/ (or is relative-escaping, empty or ~)"] end)
  elif ($v | type) == "array" then
    ([$v[] | select((type == "string" and path_ok($key; $rs)) | not)] | if length == 0 then [] else ["File path refused: \($key) holds an element that is not a string path inside .claude/memory/workspace/qa/"] end)
  else ["File path refused: \($key) must be a string or an array of strings"]
  end;

if (type != "object") or ((.tool_input | type) != "object") then
  "deny\tthe hook input has no tool_input object"
else
  .tool_input as $ti
  | ($root | segs) as $rs
  | check_list("QA_ALLOWED_ORIGINS"; if $allowed_set == "1" then $allowed else "http://localhost:* https://localhost:* http://127.0.0.1:* https://127.0.0.1:* http://[::1]:* https://[::1]:*" end) as $al
  | check_list("QA_BLOCKED_ORIGINS"; $blocked) as $bl
  | ($al.errors + $bl.errors) as $conf_errors
  | (if ($ti | has("url")) then
       ($ti.url | parse_url) as $p
       | if $p.err != null then ["Navigation refused: " + $p.err]
         elif $p.blank == true then []
         else
           "\($p.scheme)://\($p.host):\($p.port)" as $o
           | if any($bl.parsed[]; origin_match(.; $p.scheme; $p.host; $p.port)) then ["Navigation refused: \($o) is blocked by QA_BLOCKED_ORIGINS"]
             elif any($al.parsed[]; origin_match(.; $p.scheme; $p.host; $p.port)) then []
             else ["Navigation refused: \($o) is not in QA_ALLOWED_ORIGINS; list it in .claude/qa.conf if it is meant to be allowed"]
             end
         end
     else [] end) as $nav_errors
  | (if ($ti | has("save_to_disk")) and (($ti.save_to_disk == true) or (($ti.save_to_disk | type) == "string" and ($ti.save_to_disk | ascii_downcase) == "true"))
     then ["save_to_disk is true; the destination of that file cannot be checked"] else [] end) as $save_errors
  | ([$ti | to_entries[] | select(.key | ascii_downcase | test("(path|paths|file|files|filename|filenames|dir|directory)$")) | path_check(.key; .value; $rs)] | flatten) as $path_errors
  | [$conf_errors, $nav_errors, $save_errors, $path_errors] | flatten | first // "allow"
  | if . == "allow" then "allow" else "deny\t" + . end
end
')"
JQ_STATUS=$?

# Anything other than a clean allow or deny from jq is an internal error, and an internal error denies.
if [ "$JQ_STATUS" -ne 0 ]; then
  deny "internal error: the jq decision program failed (exit $JQ_STATUS). Every Ripley call is refused until it is fixed."
fi

TAB="$(printf '\t')"
case "$RESULT" in
  allow)
    exit 0
    ;;
  "deny$TAB"*)
    deny "${RESULT#deny"$TAB"}"
    ;;
  *)
    deny "internal error: the jq decision program returned something unexpected. Every Ripley call is refused until it is fixed."
    ;;
esac

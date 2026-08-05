#!/usr/bin/env bash
# answers.sh <map-iid> [--json]
#
# For every grilling/prototype child of a wayfinder map, every OPEN research/task
# child (a "Needs a human — checklist" ticket is a task, and the human's
# report-back lands on it as an ordinary comment) — and for the map itself —
# prints the latest frontier comment, every comment posted after it (candidate
# answers), and any collect marker already applied. Fetch only: reading the answers
# is the lead's job, because they arrive in prose as often as in shorthand.
#
# Authorship is NOT a signal. The agent posts under the same token as the human, so
# a candidate answer is identified by position (after the frontier) and by shape
# (not one of the agent's own headings), never by who wrote it.
#
# GitLab/glab specific. Requires: glab (authenticated in this repo), jq, and
# map-frontier.sh (beside this script) for child discovery.

set -euo pipefail

MAP="${1:-}"
JSON=0
[ "${2:-}" = "--json" ] && JSON=1
if [ -z "$MAP" ]; then
  echo "usage: answers.sh <map-iid> [--json]" >&2
  exit 2
fi
MAP="${MAP#\#}"

command -v glab >/dev/null || { echo "answers: glab not found" >&2; exit 127; }
command -v jq   >/dev/null || { echo "answers: jq not found"   >&2; exit 127; }

HERE="$(cd "$(dirname "$0")" && pwd)"
FRONTIER_SH=""
for C in "$HERE/map-frontier.sh" \
         "$HOME/.agents/skills/wayfinder-afk/scripts/map-frontier.sh" \
         "$HOME/.claude/skills/wayfinder-afk/scripts/map-frontier.sh"; do
  [ -r "$C" ] && { FRONTIER_SH="$C"; break; }
done
[ -n "$FRONTIER_SH" ] || { echo "answers: map-frontier.sh not found beside this script" >&2; exit 127; }

strip() { sed 's/^[^[{]*//'; }

# Pages a ticket's notes to exhaustion, oldest first. One page was never enough:
# per_page caps at 100 and GitLab serves ASC pages from the OLD end, so a single
# call silently dropped the NEWEST notes — i.e. the candidate answers, the exact
# thing this script exists to fetch. Status lands in globals, not the exit code,
# for the same subshell reason as map-frontier's fetch_pages:
#   NOTES_OK    0 = the first page failed. NOTHING is known about this ticket —
#                   "no notes" and "could not look" must never be the same output.
#   NOTES_TRUNC 1 = cut short by the page cap or a mid-run error; newest missing.
NOTES_PAGE_CAP="${NOTES_PAGE_CAP:-30}"     # 30 pages x 100 = 3000 notes/ticket

fetch_notes() {                            # $1 = iid; result in $NOTES_JSON
  local iid="$1" page=1 raw="" p n
  NOTES_OK=1; NOTES_TRUNC=0
  while [ "$page" -le "$NOTES_PAGE_CAP" ]; do
    p="$(glab api "projects/:fullpath/issues/$iid/notes?per_page=100&sort=asc&order_by=created_at&page=$page" 2>/dev/null | strip || true)"
    n="$(printf '%s' "$p" | jq 'length' 2>/dev/null || true)"
    # n must be an actual integer — jq prints nothing yet exits 0 on the empty
    # string a failed glab leaves behind.
    case "$n" in
      ''|*[!0-9]*)
        if [ "$page" -eq 1 ]; then NOTES_OK=0; else NOTES_TRUNC=1; fi
        break
        ;;
    esac
    raw="$raw$p"
    if [ "$n" -lt 100 ]; then break; fi   # a short page proves the notes ran out
    page=$(( page + 1 ))
    if [ "$page" -gt "$NOTES_PAGE_CAP" ]; then NOTES_TRUNC=1; fi
  done
  NOTES_JSON="$(printf '%s' "$raw" | jq -s 'add // [] | [ .[] | select(.system == false)
    | {id, created_at, updated_at, author: .author.username, body} ] | sort_by(.created_at)')"
}

# Agent-authored comment shapes. Anything NOT matching these, posted after the latest
# frontier, is a candidate answer. Comments posted from now on carry an explicit
# "<!-- wayfinder:agent -->" stamp; the heading list is the fallback for older ones.
CLASSIFY='
  def is_frontier: (.body // "") | test("^#+ *Frontier — round");
  def is_marker:   (.body // "") | test("wayfinder-(afk|collect): applied");
  def is_settled:  (.body // "") | test("^#+ *Settled —");
  def is_agent:    (.body // "")
    | test("<!-- *wayfinder:agent")
      or test("^#+ *(Frontier — round|Settled —|Answer\\b|Needs a human|Unattended run|Correction\\b|Supplementary\\b)")
      or test("^\\*\\*(Supplementary|Correction|Lead correction)\\b")
      or test("^Cross-ref from")
      or test("wayfinder-(afk|collect): applied");
'

CHILDREN="$(bash "$FRONTIER_SH" "$MAP" --json)"
# Grilling/prototype in ANY state (a closed frontier can still hold a late,
# uncollected answer), plus every other OPEN child — the human's report-back on
# a checklist task previously had no reader at all.
TARGETS="$(printf '%s' "$CHILDREN" | jq -r '
  [ .[] | select(.type == "grilling" or .type == "prototype" or .state != "closed")
  | .iid ] | .[]')"

RESULT='[]'
FETCH_FAILED=0
FETCH_TRUNCATED=0
for IID in $MAP $TARGETS; do
  fetch_notes "$IID"
  NOTES="$NOTES_JSON"
  FETCH_STATE="ok"
  if [ "$NOTES_OK" = "0" ]; then FETCH_STATE="FAILED"; FETCH_FAILED=$(( FETCH_FAILED + 1 )); fi
  if [ "$NOTES_TRUNC" = "1" ]; then FETCH_STATE="TRUNCATED"; FETCH_TRUNCATED=$(( FETCH_TRUNCATED + 1 )); fi
  META="$(printf '%s' "$CHILDREN" | jq --argjson iid "$IID" \
    'map(select(.iid == $iid)) | first // {iid: $iid, title: "(the map)", type: "map", state: "opened", url: ""}')"
  ENTRY="$(printf '%s' "$NOTES" | jq --argjson meta "$META" --arg fetch "$FETCH_STATE" "$CLASSIFY"'
    ($meta.iid) as $iid
    | (map(select(is_frontier)) | last) as $frontier
    | (map(select(is_marker))) as $markers
    | ([ $markers[] | (.body | [ scan("#?([0-9]{6,})") | .[0] ]) ] | flatten) as $consumed
    | {
        iid: $iid, title: $meta.title, type: $meta.type, state: $meta.state, url: $meta.url,
        notes_fetch: $fetch,
        frontier: (if $frontier then
                     { id: ($frontier.id|tostring), created_at: $frontier.created_at,
                       edited: ($frontier.updated_at != $frontier.created_at),
                       round: (($frontier.body | capture("round (?<r>[0-9]+)").r) // "1"),
                       # jq/Oniguruma here anchors ^ to the START OF THE STRING, not the
                       # line — "^\\*\\*Q" matches nothing. Anchor on an explicit newline.
                       # Decisions are bulleted, questions are bare bold headings; counting
                       # them loosely over-reads every "see Q4" in prose.
                       decisions: ([ $frontier.body | scan("\n[-*] *\\*\\*D[0-9]+") ] | length),
                       questions: ([ $frontier.body | scan("\n\\*\\*Q[0-9]+\\.") ] | length),
                       probe_backed: ([ $frontier.body | scan("Settled by: *`") ] | length),
                       body: $frontier.body }
                   else null end),
        applied_rounds: [ $markers[] | .body ],
        candidates: [ .[]
          | select(is_agent | not)
          | select($frontier == null or .created_at > $frontier.created_at)
          | select((.id|tostring) as $i | ($consumed | index($i)) == null)
          | {id, created_at, author, body} ]
      }')"
  RESULT="$(printf '%s' "$RESULT" | jq --argjson e "$ENTRY" '. + [$e]')"
done

if [ "$JSON" = "1" ]; then
  printf '%s\n' "$RESULT"
  exit 0
fi

printf '%s' "$RESULT" | jq -r '
  "map #\(.[0].iid) — session inventory\n"
  + "\n  calls to ratify:   " + ([ .[] | .frontier.decisions // 0 ] | add | tostring)
  + "\n  open questions:    " + ([ .[] | .frontier.questions // 0 ] | add | tostring)
  + " (" + ([ .[] | .frontier.probe_backed // 0 ] | add | tostring) + " probe-backed)"
  + "\n  frontiers:         " + ([ .[] | select(.frontier != null) ] | length | tostring)
  + "\n  uncollected notes: " + ([ .[] | .candidates | length ] | add | tostring)
  + " across " + ([ .[] | select((.candidates|length) > 0) ] | length | tostring) + " ticket(s)"
  + (([ .[] | select(.notes_fetch == "FAILED") ] | length) as $f
     | if $f > 0 then "\n  NOTES FETCH FAILED: \($f) ticket(s) — their answers are UNKNOWN, not absent" else "" end)
  + (([ .[] | select(.notes_fetch == "TRUNCATED") ] | length) as $t
     | if $t > 0 then "\n  NOTES TRUNCATED: \($t) ticket(s) hit the page cap — NEWEST notes missing; re-run with NOTES_PAGE_CAP higher" else "" end)
  + "\n"
  + ( map(
      "\n" + ("=" * 72) + "\n#\(.iid) [\(.type)] \(.title)\n"
      + (if .notes_fetch == "FAILED" then
           "  ** NOTES FETCH FAILED — frontier and answers UNKNOWN for this ticket. **\n"
           + "  ** The counts above exclude it. Re-run before collecting. **\n"
         else
           (if .frontier then
              "  frontier: note \(.frontier.id), round \(.frontier.round) — \(.frontier.decisions) call(s), \(.frontier.questions) question(s)"
              + (if .frontier.edited then "  ** EDITED since posting — read the body for inline answers **" else "" end)
            else "  frontier: NONE POSTED" end)
           + (if .notes_fetch == "TRUNCATED" then "\n  ** NOTES TRUNCATED at the page cap — the NEWEST notes, i.e. the answers, may be missing. **" else "" end)
           + (if (.applied_rounds|length) > 0 then "\n  already collected: \(.applied_rounds|length) round(s)" else "" end)
           + "\n  uncollected: \(.candidates|length)\n"
           + ( .candidates
               | map("\n  --- note \(.id) · \(.created_at) · \(.author) ---\n\(.body)\n")
               | join("") )
         end)
    ) | join("") )
'

# Bench kit inventory — the stage-3 half of the session. Read from the working tree, so
# it only appears if the bench branch is checked out; otherwise say where to find it.
BENCH="$(git rev-parse --show-toplevel 2>/dev/null || true)/bench/$MAP"
printf '\n%s\n' "========================================================================"
if [ -d "$BENCH" ]; then
  printf 'bench kit — %s\n' "$BENCH"
  [ -r "$BENCH/RUN.md" ] && printf '  RUN.md present (session plan)\n'
  for P in "$BENCH"/probe-*.sh "$BENCH"/probe-*; do
    [ -r "$P" ] || continue
    case "$P" in *'*'*) continue;; esac
    printf '  %s\n' "$(basename "$P")"
    sed -n '2,12p' "$P" | sed -n 's/^# \(Settles\|Needs\|Gesture\|Safety\|Status\|Blind to\): */      \1: /p'
  done
else
  printf 'bench kit — not in this working tree.\n'
  printf '  Expected at bench/%s/ on branch wayfinder/%s-bench.\n' "$MAP" "$MAP"
  printf '  git switch wayfinder/%s-bench   (or check it out into a worktree)\n' "$MAP"
fi

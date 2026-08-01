#!/usr/bin/env bash
# answers.sh <map-iid> [--json]
#
# For every grilling/prototype child of a wayfinder map — and for the map itself —
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

notes() { # <iid> -> JSON array of non-system notes, oldest first
  local out n
  out="$(glab api "projects/:fullpath/issues/$1/notes?per_page=100&sort=asc&order_by=created_at" 2>/dev/null | strip)"
  [ -n "$out" ] || { echo '[]'; return; }
  n="$(printf '%s' "$out" | jq 'length')"
  [ "$n" -ge 100 ] && echo "answers: #$1 returned $n notes — page cap reached, older ones may be missing" >&2
  printf '%s' "$out" | jq '[ .[] | select(.system == false)
    | {id, created_at, updated_at, author: .author.username, body} ] | sort_by(.created_at)'
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
TARGETS="$(printf '%s' "$CHILDREN" | jq -r '
  [ .[] | select(.type == "grilling" or .type == "prototype") | .iid ] | .[]')"

RESULT='[]'
for IID in $MAP $TARGETS; do
  NOTES="$(notes "$IID")"
  META="$(printf '%s' "$CHILDREN" | jq --argjson iid "$IID" \
    'map(select(.iid == $iid)) | first // {iid: $iid, title: "(the map)", type: "map", state: "opened", url: ""}')"
  ENTRY="$(printf '%s' "$NOTES" | jq --argjson meta "$META" "$CLASSIFY"'
    ($meta.iid) as $iid
    | (map(select(is_frontier)) | last) as $frontier
    | (map(select(is_marker))) as $markers
    | ([ $markers[] | (.body | [ scan("#?([0-9]{6,})") | .[0] ]) ] | flatten) as $consumed
    | {
        iid: $iid, title: $meta.title, type: $meta.type, state: $meta.state, url: $meta.url,
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
  + " across " + ([ .[] | select((.candidates|length) > 0) ] | length | tostring) + " ticket(s)\n"
  + ( map(
      "\n" + ("=" * 72) + "\n#\(.iid) [\(.type)] \(.title)\n"
      + (if .frontier then
           "  frontier: note \(.frontier.id), round \(.frontier.round) — \(.frontier.decisions) call(s), \(.frontier.questions) question(s)"
           + (if .frontier.edited then "  ** EDITED since posting — read the body for inline answers **" else "" end)
         else "  frontier: NONE POSTED" end)
      + (if (.applied_rounds|length) > 0 then "\n  already collected: \(.applied_rounds|length) round(s)" else "" end)
      + "\n  uncollected: \(.candidates|length)\n"
      + ( .candidates
          | map("\n  --- note \(.id) · \(.created_at) · \(.author) ---\n\(.body)\n")
          | join("") )
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

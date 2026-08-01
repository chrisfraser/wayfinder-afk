#!/usr/bin/env bash
# map-frontier.sh <map-iid> [--json]
#
# Prints every child ticket of a wayfinder map, grouped by what a sweep can do
# with it right now: TAKEABLE (open, unblocked, unclaimed), CLAIMED, BLOCKED,
# CLOSED. Children are found by their "Part of: ... (#<map>)" body pointer;
# blocking is read from the "## Blocked by" section of each body.
#
# GitLab/glab specific. Requires: glab (authenticated in this repo), jq.
# glab prints a multi-config warning on stdout, so every payload is stripped to
# its first '[' or '{' before jq sees it.

set -euo pipefail

MAP="${1:-}"
JSON=0
[ "${2:-}" = "--json" ] && JSON=1
if [ -z "$MAP" ]; then
  echo "usage: map-frontier.sh <map-iid> [--json]" >&2
  exit 2
fi
MAP="${MAP#\#}"

command -v glab >/dev/null || { echo "map-frontier: glab not found" >&2; exit 127; }
command -v jq   >/dev/null || { echo "map-frontier: jq not found"   >&2; exit 127; }

strip() { sed 's/^[^[{]*//'; }

# 1. every wayfinder-labelled issue, open and closed
ALL="$(for L in research task grilling prototype; do
         glab issue list --label "wayfinder:$L" --all --output json --per-page 100 2>/dev/null | strip
       done | jq -s 'add // [] | unique_by(.iid)')"

# 2. children of this map, with their declared blockers
CHILDREN="$(printf '%s' "$ALL" | jq --arg map "$MAP" '
  # "m" is jq/Oniguruma dot-matches-newline; "s" is NOT — it retargets ^ and $.
  def blockers:
    ((.description // "") | (match("## Blocked by(.*?)(?:\n## |\\z)"; "m").captures[0].string // ""))
    | [ scan("#([0-9]+)") | .[0] | tonumber ];
  def parented: (.description // "") | test("Part of:[^\n]*(work_items/" + $map + "\\)|#" + $map + "\\))");
  def mentioned: (.description // "") | test("work_items/" + $map + "\\)|#" + $map + "\\)");
  (map(select(parented)) | if length > 0 then . else null end) // map(select(mentioned))
  | map({
      iid, state, title,
      url: .web_url,
      type: ((.labels // []) | map(select(startswith("wayfinder:"))) | first // "wayfinder:?" | ltrimstr("wayfinder:")),
      claimed: (((.assignees // []) | length) > 0),
      assignee: (((.assignees // []) | map(.username) | join(",")) // ""),
      blockers: blockers
    })
  | sort_by(.iid)')"

# 3. resolve the state of any blocker that is not itself a child (a blocker can
#    be an ordinary issue on another map, or unlabelled)
KNOWN="$(printf '%s' "$CHILDREN" | jq '[.[] | {key: (.iid|tostring), value: .state}] | from_entries')"
MISSING="$(printf '%s' "$CHILDREN" | jq -r --argjson known "$KNOWN" \
  '[.[].blockers[]] | unique | map(select($known[tostring] == null)) | .[]')"
for ID in $MISSING; do
  ST="$(glab issue view "$ID" --output json 2>/dev/null | strip | jq -r '.state // "opened"')"
  KNOWN="$(printf '%s' "$KNOWN" | jq --arg k "$ID" --arg v "$ST" '. + {($k): $v}')"
done

# 4. classify
OUT="$(printf '%s' "$CHILDREN" | jq --argjson known "$KNOWN" '
  map(. + {
    open_blockers: [ .blockers[] | select(($known[tostring] // "opened") != "closed") ]
  })
  | map(. + {
      bucket: (if .state == "closed" then "CLOSED"
               elif (.open_blockers | length) > 0 then "BLOCKED"
               elif .claimed then "CLAIMED"
               else "TAKEABLE" end)
    })')"

if [ "$JSON" = "1" ]; then
  printf '%s\n' "$OUT"
  exit 0
fi

printf '%s' "$OUT" | jq -r --arg map "$MAP" '
  def line: "  #\(.iid) [\(.type)] \(.title)"
    + (if (.open_blockers|length) > 0 then "\n        blocked by: " + (.open_blockers | map("#\(.)") | join(", ")) else "" end)
    + (if .claimed and .state != "closed" then "\n        claimed by: " + .assignee else "" end);
  def section($name; $rows):
    "\($name) (\($rows|length))\n" + (if ($rows|length) == 0 then "  —\n" else (($rows | map(line) | join("\n")) + "\n") end);
  "map #\($map) — \(length) child ticket(s)\n\n"
  + section("TAKEABLE — open, unblocked, unclaimed"; map(select(.bucket == "TAKEABLE")))
  + "\n" + section("CLAIMED — open, someone is on it"; map(select(.bucket == "CLAIMED")))
  + "\n" + section("BLOCKED — waiting on an open ticket"; map(select(.bucket == "BLOCKED")))
  + "\n" + section("CLOSED"; map(select(.bucket == "CLOSED")))
  + "\nby type, still open: "
  + ([ .[] | select(.state != "closed") | .type ] | group_by(.) | map("\(.[0])=\(length)") | join("  "))
'

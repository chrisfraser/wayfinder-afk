#!/usr/bin/env bash
# map-frontier.sh <map-iid> [--json]
#
# Prints every child ticket of a wayfinder map, grouped by what a sweep can do
# with it right now: TAKEABLE (open, unblocked, unclaimed), CLAIMED, BLOCKED,
# CLOSED. Children are found by their "Part of: ... (#<map>)" body pointer;
# blocking is read from the "## Blocked by" section of each body.
#
# Also reports UNLABELLED: issues that point at this map but carry no
# "wayfinder:*" label. Step 1 finds children by QUERYING the four labels, so
# such a ticket is invisible to it — in no bucket, never swept, never blocking
# anything. Catching them needs the separate unfiltered scan in step 1b.
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

# 1b. orphan scan: open issues carrying NO wayfinder:* label, checked against the
#     same "Part of:" pointer step 2 uses. Bounded — ORPHAN_MAX open issues, most
#     recent first — because this one is unfiltered and a busy project is large.
#     The bound and the scanned count are printed with the result: "no orphans"
#     must never be indistinguishable from "did not look".
ORPHAN_MAX="${ORPHAN_MAX:-500}"
ORPHAN_OK=1
RAW=""
PAGE=1
while [ "$PAGE" -le $(( (ORPHAN_MAX + 99) / 100 )) ]; do
  P="$(glab api "projects/:fullpath/issues?per_page=100&page=$PAGE&state=opened&order_by=created_at&sort=desc" 2>/dev/null | strip || true)"
  N="$(printf '%s' "$P" | jq 'length' 2>/dev/null || true)"
  # N must be an actual integer. jq's exit code is NOT the test: fed the empty
  # string a failed glab leaves behind, jq prints nothing and still exits 0 —
  # which read as "0 issues", i.e. a failed scan reporting "no orphans found".
  case "$N" in
    ''|*[!0-9]*)
      # A failed FIRST page means the scan never ran; a failed later page means
      # it ran partially. Either way the report below stays honest.
      [ "$PAGE" -eq 1 ] && ORPHAN_OK=0
      break
      ;;
  esac
  RAW="$RAW$P"
  [ "$N" -lt 100 ] && break
  PAGE=$(( PAGE + 1 ))
done

SCANNED=0
ORPHANS='[]'
if [ "$ORPHAN_OK" = "1" ]; then
  SCANNED="$(printf '%s' "$RAW" | jq -s 'add // [] | length')"
  # Same "Part of:" regex as `parented` below — the two must not drift.
  ORPHANS="$(printf '%s' "$RAW" | jq -s --arg map "$MAP" '
    add // []
    | map(select(((.labels // []) | map(select(startswith("wayfinder:"))) | length) == 0))
    | map(select((.description // "") | test("Part of:[^\n]*(work_items/" + $map + "\\)|#" + $map + "\\))")))
    | map({iid, title, url: .web_url})
    | sort_by(.iid)')"
fi

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

# The orphan report. In --json mode it goes to STDERR: stdout stays the bare
# array of children that collect already parses, so this stays a pure addition.
orphan_report() {
  if [ "$ORPHAN_OK" = "0" ]; then
    printf 'UNLABELLED — SCAN FAILED (glab api). Orphans are NOT ruled out.\n'
    return
  fi
  local n
  n="$(printf '%s' "$ORPHANS" | jq 'length')"
  if [ "$n" -eq 0 ]; then
    printf 'UNLABELLED — none, across %s open issue(s) scanned (cap ORPHAN_MAX=%s)\n' "$SCANNED" "$ORPHAN_MAX"
    return
  fi
  printf '%s' "$ORPHANS" | jq -r --arg scanned "$SCANNED" '
    "UNLABELLED — \(length) issue(s) point at this map but carry no wayfinder:* label\n"
    + "  In no bucket above: never swept, never blocking, invisible to every run.\n"
    + "  Label each one, then re-run:  glab issue update <iid> --label \"wayfinder:<type>\"\n"
    + (map("  #\(.iid) \(.title)\n        \(.url)") | join("\n"))
    + "\n  (\($scanned) open issue(s) scanned)"'
}

if [ "$JSON" = "1" ]; then
  printf '%s\n' "$OUT"
  orphan_report >&2
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
printf '\n'
orphan_report

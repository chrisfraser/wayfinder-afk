#!/usr/bin/env bash
# map-frontier.sh <map-iid> [--json]
#
# Prints every child ticket of a wayfinder map, grouped by what a sweep can do
# with it right now: TAKEABLE (open, unblocked, unclaimed), CLAIMED, BLOCKED,
# CLOSED. Children are found by their "Part of: ... (#<map>)" body pointer;
# blocking is read from the "## Blocked by" section of each body.
#
# Also reports COMPLETE BUT OPEN: open tickets already carrying an agent
# resolution comment. The work was done and the close never landed — and because
# the subagent claims a ticket before starting, such a ticket sits in CLAIMED,
# which no round retakes. It is invisible until someone reads the map by hand.
#
# Also reports UNLABELLED: issues that point at this map but carry no
# "wayfinder:*" label. Step 1 finds children by QUERYING the four labels, so
# such a ticket is invisible to it — in no bucket, never swept, never blocking
# anything. Catching them needs the separate unfiltered scan in step 1b.
#
# Further warning sections, each a distinct stranding mode: STALE CLAIM (handed
# off but still assigned), CLAIMED NO RESOLUTION (claimed with nothing posted —
# a live run or a dead one), LOOSE POINTER (labelled, mentions the map, pointer
# doesn't parse), BLOCKER LOOKUP FAILED (blocker unreadable, treated as open).
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

# Pages a GitLab issues query to exhaustion. `glab issue list --all` does NOT do
# this: -A/--all selects all STATES, while -p/--page is the pagination flag it
# never passes — so a label with more than 100 tickets came back silently short,
# and a truncated frontier was indistinguishable from a complete one.
#
# Results land in $FETCH_RESULT rather than on stdout, deliberately: called as
# `X="$(fetch_pages ...)"` the function would run in a subshell and its status
# globals would be discarded at exactly the moment they matter.
#   FETCH_OK        0 if the FIRST page failed — the query never ran at all
#   FETCH_TRUNCATED 1 if results were cut short, by the page cap or a mid-run error
#   FETCH_COUNT     issues actually retrieved
PAGE_CAP="${PAGE_CAP:-50}"          # 50 pages x 100 = 5000 issues per query

fetch_pages() {                     # $1 = query (no per_page/page), $2 = page cap
  local q="$1" maxp="$2" page=1 raw="" p n
  FETCH_OK=1; FETCH_TRUNCATED=0; FETCH_COUNT=0
  while [ "$page" -le "$maxp" ]; do
    p="$(glab api "${q}&per_page=100&page=${page}" 2>/dev/null | strip || true)"
    n="$(printf '%s' "$p" | jq 'length' 2>/dev/null || true)"
    # n must be an actual integer. jq's exit code is NOT the test: fed the empty
    # string a failed glab leaves behind, jq prints nothing and still exits 0 —
    # which reads as "0 issues", i.e. a failed query reporting an empty project.
    case "$n" in
      ''|*[!0-9]*)
        if [ "$page" -eq 1 ]; then FETCH_OK=0; else FETCH_TRUNCATED=1; fi
        break
        ;;
    esac
    raw="$raw$p"
    FETCH_COUNT=$(( FETCH_COUNT + n ))
    # A short page is the only proof the results ran out. Reaching the cap on a
    # FULL page means more remain, which is truncation and must be said.
    if [ "$n" -lt 100 ]; then
      FETCH_RESULT="$(printf '%s' "$raw" | jq -s 'add // []')"
      return 0
    fi
    page=$(( page + 1 ))
  done
  if [ "$FETCH_OK" = "1" ]; then FETCH_TRUNCATED=1; fi
  FETCH_RESULT="$(printf '%s' "$raw" | jq -s 'add // []')"
  return 0
}

# 1. every wayfinder-labelled issue, open and closed
PARTS=""
LABEL_FAIL=""
LABEL_TRUNC=""
for L in research task grilling prototype; do
  fetch_pages "projects/:fullpath/issues?labels=wayfinder:$L&state=all&order_by=created_at&sort=desc" "$PAGE_CAP"
  if [ "$FETCH_OK" = "0" ];        then LABEL_FAIL="$LABEL_FAIL $L"; fi
  if [ "$FETCH_TRUNCATED" = "1" ]; then LABEL_TRUNC="$LABEL_TRUNC $L"; fi
  PARTS="$PARTS$FETCH_RESULT"
done
ALL="$(printf '%s' "$PARTS" | jq -s 'add // [] | unique_by(.iid)')"

# 1b. orphan scan: open issues carrying NO wayfinder:* label, checked against the
#     same "Part of:" pointer step 2 uses. Bounded separately — this one is
#     unfiltered, so on a busy project it is the expensive query, and a partial
#     orphan scan is far less damaging than a partial frontier. The bound and the
#     scanned count are printed with the result: "no orphans" must never be
#     indistinguishable from "did not look".
ORPHAN_MAX="${ORPHAN_MAX:-500}"
fetch_pages "projects/:fullpath/issues?state=opened&order_by=created_at&sort=desc" \
            "$(( (ORPHAN_MAX + 99) / 100 ))"
ORPHAN_OK="$FETCH_OK"
ORPHAN_TRUNC="$FETCH_TRUNCATED"
RAW="$FETCH_RESULT"

SCANNED=0
ORPHANS='[]'
if [ "$ORPHAN_OK" = "1" ]; then
  SCANNED="$FETCH_COUNT"
  # Same "Part of:" regex as `parented` below — the two must not drift.
  ORPHANS="$(printf '%s' "$RAW" | jq --arg map "$MAP" '
    map(select(((.labels // []) | map(select(startswith("wayfinder:"))) | length) == 0))
    | map(select((.description // "") | test("Part of:[^\n]*(work_items/" + $map + "\\)|#" + $map + "\\))")))
    | map({iid, title, url: .web_url})
    | sort_by(.iid)')"
fi

# 2. children of this map, with their declared blockers. Strict "Part of:" pointer
#    ONLY — adopting any issue that merely mentions the map invents children, and
#    an invented child gets swept, blocked on, and counted. Labelled issues that
#    mention the map but fail the strict parse are reported as LOOSE POINTER below
#    instead of being silently adopted or silently dropped.
CHILDREN="$(printf '%s' "$ALL" | jq --arg map "$MAP" '
  # "m" is jq/Oniguruma dot-matches-newline; "s" is NOT — it retargets ^ and $.
  def blockers:
    ((.description // "") | (match("## Blocked by(.*?)(?:\n## |\\z)"; "m").captures[0].string // ""))
    | [ scan("#([0-9]+)") | .[0] | tonumber ];
  def parented: (.description // "") | test("Part of:[^\n]*(work_items/" + $map + "\\)|#" + $map + "\\))");
  map(select(parented))
  | map({
      iid, state, title,
      url: .web_url,
      type: ((.labels // []) | map(select(startswith("wayfinder:"))) | first // "wayfinder:?" | ltrimstr("wayfinder:")),
      claimed: (((.assignees // []) | length) > 0),
      assignee: (((.assignees // []) | map(.username) | join(",")) // ""),
      blockers: blockers
    })
  | sort_by(.iid)')"

# 2b. labelled issues that MENTION this map but whose "Part of:" line does not
#     parse. Before this check they were silently adopted as children, which
#     invented children on other maps; silently dropping them instead would make
#     a malformed pointer indistinguishable from no pointer. Open ones only —
#     a closed one is not waiting on anything.
LOOSE="$(printf '%s' "$ALL" | jq --arg map "$MAP" '
  def parented: (.description // "") | test("Part of:[^\n]*(work_items/" + $map + "\\)|#" + $map + "\\))");
  def mentioned: (.description // "") | test("work_items/" + $map + "\\)|#" + $map + "\\)");
  map(select(.state != "closed" and (parented | not) and mentioned))
  | map({iid, title, url: .web_url}) | sort_by(.iid)')"

# 3. resolve the state of any blocker that is not itself a child (a blocker can
#    be an ordinary issue on another map, or unlabelled). A FAILED lookup is not
#    "opened": defaulting it silently left the blocked ticket BLOCKED forever —
#    a deleted or confidential blocker read as a permanently open one. Still
#    treated as open (the conservative reading), but said out loud.
KNOWN="$(printf '%s' "$CHILDREN" | jq '[.[] | {key: (.iid|tostring), value: .state}] | from_entries')"
MISSING="$(printf '%s' "$CHILDREN" | jq -r --argjson known "$KNOWN" \
  '[.[].blockers[]] | unique | map(select($known[tostring] == null)) | .[]')"
BLOCKER_FAIL=""
for ID in $MISSING; do
  ST="$(glab issue view "$ID" --output json 2>/dev/null | strip | jq -r '.state // empty' 2>/dev/null || true)"
  if [ -z "$ST" ]; then
    ST="unknown"
    BLOCKER_FAIL="$BLOCKER_FAIL #$ID"
  fi
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

# 5. completion check. An open ticket already carrying an agent resolution comment
#    is work that was DONE and then not closed — the `glab issue close` never
#    landed, or the subagent stopped after commenting.
#
#    This is self-concealing without the check. The subagent claims the ticket
#    before starting, so a failed close leaves it assigned-and-open: bucket
#    CLAIMED, excluded from TAKEABLE, skipped by every later round. It looks like
#    someone is on it, forever. Nothing else in the run contradicts that, because
#    the lead's "closed" count comes from what subagents reported, not the tracker.
#
#    Deliberately does NOT flag a "Needs a human — checklist" ticket: that one is
#    open on purpose and closing it would lose the human's queue.
CHECK_MAX="${CHECK_MAX:-60}"
CHECK_NOTES_CAP="${CHECK_NOTES_CAP:-30}"   # 30 pages x 100 = 3000 notes per ticket
DONE_OPEN='[]'
HANDED_OFF='[]'
NO_TRACE='[]'
CHECK_OK=1
CHECK_SCANNED=0
CHECK_TRUNC=0
# Newest first: the tickets a just-finished run stranded are the highest iids,
# and a CHECK_MAX truncation must cut the OLD end of the list, not the end where
# the fresh wreckage is.
for ID in $(printf '%s' "$OUT" | jq -r '[ .[] | select(.state != "closed") | .iid ] | sort | reverse | .[]'); do
  if [ "$CHECK_SCANNED" -ge "$CHECK_MAX" ]; then CHECK_TRUNC=1; break; fi
  # Paged to exhaustion, like answers.sh on the same endpoint. One ASC page serves
  # the OLD end, so past 100 notes `last` would crown note #100 "the most recent
  # word" — exactly the blind spot the recency rule below exists to close.
  fetch_pages "projects/:fullpath/issues/$ID/notes?sort=asc&order_by=created_at" "$CHECK_NOTES_CAP"
  CHECK_SCANNED=$(( CHECK_SCANNED + 1 ))
  if [ "$FETCH_OK" = "0" ] || [ "$FETCH_TRUNCATED" = "1" ]; then
    # Failed or cut short: the latest note may be the missing one, and recency is
    # the whole signal — this ticket is unclassifiable, not "NEITHER".
    CHECK_OK=0
    continue
  fi
  # jq/Oniguruma anchors ^ to the START OF THE STRING, not the line (answers.sh
  # documents the same trap) — so headings match at the body's first byte or
  # after an explicit newline, never mid-line.
  # The LATEST classifiable note wins. "HUMAN always outranks RESOLVED" looked
  # safer but had a blind spot: an early checklist followed by a later resolution
  # (the human did their part, the agent resolved, the close failed) was never
  # flagged. Recency is the honest signal — the notes are fetched oldest-first,
  # so `last` is the most recent word on the ticket.
  # A frontier classifies as HUMAN: a ticket whose latest word is a frontier is
  # open ON PURPOSE, waiting on answers. Without that, the Settled comment under
  # a round n+1 frontier (deferred questions — collect leaves the ticket open by
  # design) read as RESOLVED and flagged a deliberately open ticket every round.
  V="$(printf '%s' "$FETCH_RESULT" | jq -r '
        if type != "array" then "ERR" else
          [ .[] | select(.system != true) | .body // ""
            | if   test("(^|\\n)#+ *(Needs a human|Changed since this was filed|Frontier — round)") then "HUMAN"
              elif test("(^|\\n)#+ *(Answer\\b|Already settled\\b|Not needed\\b|Settled —)")        then "RESOLVED"
              else empty end ]
          | last // "NEITHER"
        end' 2>/dev/null || true)"
  case "$V" in
    RESOLVED) DONE_OPEN="$(printf '%s' "$DONE_OPEN" | jq --argjson id "$ID" '. + [$id]')" ;;
    HUMAN)    HANDED_OFF="$(printf '%s' "$HANDED_OFF" | jq --argjson id "$ID" '. + [$id]')" ;;
    NEITHER)  NO_TRACE="$(printf '%s' "$NO_TRACE" | jq --argjson id "$ID" '. + [$id]')" ;;
    *) CHECK_OK=0 ;;   # empty or ERR: the parse failed, not "nothing found"
  esac
done

# A ticket handed to someone else — re-scoped, or left as a human checklist — that
# is still ASSIGNED is stranded for the same reason a failed close is: CLAIMED is
# never retaken, so it is offered to nobody. The agent that handed it off owed it
# an un-assign.
STALE_CLAIMS="$(printf '%s' "$OUT" | jq --argjson ids "$HANDED_OFF" \
  '[ .[] | select(.state != "closed" and .claimed and (.iid as $i | $ids | index($i))) ]')"

# Claimed, and the notes show NEITHER a resolution NOR a handoff: either a run is
# on it right now, or the claimant died mid-work — a crashed subagent leaves
# exactly this shape, and it strands the ticket forever because CLAIMED is never
# retaken. The two are indistinguishable from here, so this is reported as a
# question for the reader, not a verdict: at the END of a round it must be empty
# of the run's own claims.
CLAIMED_NO_RES="$(printf '%s' "$OUT" | jq --argjson ids "$NO_TRACE" \
  '[ .[] | select(.state != "closed" and .claimed and (.iid as $i | $ids | index($i))) ]')"

completion_report() {
  local n
  n="$(printf '%s' "$DONE_OPEN" | jq 'length')"
  if [ "$n" -gt 0 ]; then
    printf '%s' "$OUT" | jq -r --argjson ids "$DONE_OPEN" '
      "COMPLETE BUT OPEN — \($ids|length) ticket(s) carry a resolution comment and are still open\n"
      + "  The work was done; the close never landed. Until it does they sit in CLAIMED,\n"
      + "  which no round retakes — they are skipped forever. Read each, then:\n"
      + "  glab issue close <iid>\n"
      + (map(select(.iid as $i | $ids | index($i))) | map("  #\(.iid) [\(.type)] \(.title)\n        \(.url)") | join("\n"))'
  elif [ "$CHECK_OK" = "0" ]; then
    printf 'COMPLETE BUT OPEN — CHECK INCOMPLETE (a notes fetch failed or was cut short). Not ruled out.\n'
  elif [ "$CHECK_TRUNC" = "1" ]; then
    printf 'COMPLETE BUT OPEN — none in the first %s open ticket(s), but CHECK_MAX=%s stopped\n' "$CHECK_SCANNED" "$CHECK_MAX"
    printf '                    the check before the rest. Not ruled out.\n'
  else
    printf 'COMPLETE BUT OPEN — none, across all %s open ticket(s) checked\n' "$CHECK_SCANNED"
  fi
  if [ "$n" -gt 0 ] && [ "$CHECK_OK" = "0" ]; then
    printf '\n  (a notes fetch also failed or was cut short — there may be more)\n'
  fi
  if [ "$(printf '%s' "$STALE_CLAIMS" | jq 'length')" -gt 0 ]; then
    printf '%s' "$STALE_CLAIMS" | jq -r '
      "STALE CLAIM — \(length) ticket(s) handed off but still assigned\n"
      + "  Re-scoped, left as a checklist, or waiting on frontier answers — and never\n"
      + "  un-assigned. They sit in CLAIMED, which no round retakes, so they are\n"
      + "  offered to nobody:\n"
      + "  glab issue update <iid> --unassign\n"
      + (map("  #\(.iid) [\(.type)] \(.title) — held by \(.assignee)") | join("\n"))'
  fi
  if [ "$(printf '%s' "$CLAIMED_NO_RES" | jq 'length')" -gt 0 ]; then
    printf '%s' "$CLAIMED_NO_RES" | jq -r '
      "CLAIMED, NO RESOLUTION — \(length) claimed ticket(s) with no resolution or handoff posted\n"
      + "  Either a run is on them right now, or the claimant died mid-work. A crashed\n"
      + "  subagent leaves exactly this shape, and CLAIMED is never retaken. At the end\n"
      + "  of a round this list must not name anything that round claimed — un-assign\n"
      + "  what it does: glab issue update <iid> --unassign\n"
      + (map("  #\(.iid) [\(.type)] \(.title) — held by \(.assignee)") | join("\n"))'
  fi
}

# Coverage of step 1. A frontier built from a short read is WRONG, not merely
# small — the missing tickets are absent from every bucket, so nothing above
# hints they exist. Say so loudly, or a partial sweep reads as a finished one.
coverage_report() {
  if [ -n "$LABEL_FAIL" ]; then
    printf 'COVERAGE — QUERY FAILED for label(s):%s. The buckets above are INCOMPLETE;\n' "$LABEL_FAIL"
    printf '           tickets of that type are missing entirely. Do not sweep on this.\n'
  fi
  if [ -n "$LABEL_TRUNC" ]; then
    printf 'COVERAGE — TRUNCATED at the %s-page cap for label(s):%s. More tickets exist\n' "$PAGE_CAP" "$LABEL_TRUNC"
    printf '           than were read. Re-run with PAGE_CAP higher before trusting the buckets.\n'
  fi
  if [ -z "$LABEL_FAIL" ] && [ -z "$LABEL_TRUNC" ]; then
    printf 'COVERAGE — complete: all four label queries read to exhaustion.\n'
  fi
  if [ -n "$BLOCKER_FAIL" ]; then
    printf 'BLOCKER LOOKUP FAILED for:%s — treated as OPEN, so their dependents stay\n' "$BLOCKER_FAIL"
    printf '           BLOCKED. A deleted or confidential blocker looks exactly like this;\n'
    printf '           verify by hand or the dependents are blocked forever.\n'
  fi
}

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
    if [ "$ORPHAN_TRUNC" = "1" ]; then
      printf 'UNLABELLED — none in the first %s open issue(s), but the scan hit ORPHAN_MAX=%s\n' "$SCANNED" "$ORPHAN_MAX"
      printf '             before running out. Older issues were NOT checked.\n'
    else
      printf 'UNLABELLED — none, across all %s open issue(s) (scan ran to exhaustion)\n' "$SCANNED"
    fi
    return
  fi
  printf '%s' "$ORPHANS" | jq -r --arg scanned "$SCANNED" '
    "UNLABELLED — \(length) issue(s) point at this map but carry no wayfinder:* label\n"
    + "  In no bucket above: never swept, never blocking, invisible to every run.\n"
    + "  Label each one, then re-run:  glab issue update <iid> --label \"wayfinder:<type>\"\n"
    + (map("  #\(.iid) \(.title)\n        \(.url)") | join("\n"))
    + "\n  (\($scanned) open issue(s) scanned)"'
}

# Labelled, mentions the map, but the "Part of:" line does not parse. Not adopted
# as a child (adoption invents children), not silently dropped (a malformed
# pointer must not read as no pointer). Fix the body, don't relabel.
loose_report() {
  [ "$(printf '%s' "$LOOSE" | jq 'length')" -gt 0 ] || return 0
  printf '%s' "$LOOSE" | jq -r '
    "LOOSE POINTER — \(length) open labelled issue(s) mention this map but their\n"
    + "  Part of: line does not parse, so they are in NO bucket above. The URL must\n"
    + "  end in work_items/<map> or #<map> — fix the body, then re-run:\n"
    + (map("  #\(.iid) \(.title)\n        \(.url)") | join("\n"))'
}

if [ "$JSON" = "1" ]; then
  printf '%s\n' "$OUT"
  coverage_report >&2
  completion_report >&2
  orphan_report >&2
  loose_report >&2
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
coverage_report
completion_report
orphan_report
loose_report

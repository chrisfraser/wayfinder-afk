#!/usr/bin/env bash
# landing-verify.sh — did each ticket branch's CONTENT arrive on the landing branch?
#
#   check <base-ref> <target-ref> <branch>...      extracted-marker verification (the default interface)
#   one <label> <src> <base> <target> <pattern> [pathspec...]
#                                                  one hand-authored marker, three-armed
#   selftest                                       fixtures + mutation proof; `check` runs this first
#
# A merge can drop a hunk with no conflict and no warning while leaving the
# commit fully reachable: `git log` says the work landed, the file does not
# contain it. Ancestry answers a different question than content. This script
# asks the content question, three-armed, so a negative cannot lie:
#
#   arm 1  positive control       does the marker match on the branch that
#                                 authored it? If not, the MARKER is broken
#                                 (pattern mangled, pathspec wrong, prose
#                                 reflowed) — not the tree.
#   arm 2  discrimination control does the marker miss on the merge-base? If
#                                 not, the string is common or another branch
#                                 wrote it too, and PRESENT would mean nothing.
#   arm 3  the question           does it match on the target?
#
# Only arm 3 produces a verdict. Arms 1–2 failing is PRECONDITION: the check
# never ran, and counting it as either answer is a lie — the same rule bench
# probes already follow. Arm 2 is what converts PRESENT from "this string
# exists on the target" into "this branch's content arrived on the target".
#
# Markers are EXTRACTED from each branch's own diff against its merge-base —
# longest added line, unique in the authoring tree, absent from the base,
# code identifiers preferred over prose (an identifier cannot reflow; a
# Markdown sentence can). Markers typed from memory are what `one` is for,
# and every observed false result came from one. MARKERS=<n> markers per
# branch (default 3), each from a distinct file where possible.
#
# `check` runs `selftest` first and FAILS CLOSED: no verdicts from a check
# that has not just proven, on fixtures, that it reports PRESENT, ABSENT and
# PRECONDITION correctly — and that each control arm actually changes the
# outcome (mutation cases run each check with one arm disabled and assert the
# specific lie that arm exists to stop).
#
# Exit codes are the contract:
#   0  every marker PRESENT
#   1  at least one ABSENT — content did not arrive
#   3  PRECONDITION only — nothing verified either way; fix the markers
#   2  usage, broken ref, or selftest failure (fail closed)
#
# Out of scope, learned at cost — do not "improve" these back in:
#   - comparing <merge> against <merge>^2: reported 275 lost files where 4
#     were lost. Compare against the merge-base.
#   - `git log -- <path>` as evidence: it follows the stale parent and is
#     blind to exactly this class (--full-history would be the minimum).
#   - "the merge produced no conflict": evidence of nothing.
#   - ancestry scans ("is the branch merged?"): a neighbouring question — a
#     file a later ticket rewrote into a novel blob reads clean.

set -uo pipefail

# _LV_MUTATE disables one arm so the selftest can prove the arm is load-
# bearing. A mutated control in a real run is theatre, so it is refused
# outside the selftest.
if [ -n "${_LV_MUTATE:-}" ] && [ "${_LV_SELFTEST:-}" != "1" ]; then
  echo "landing-verify: _LV_MUTATE is selftest-only — a disabled control in a real run is theatre" >&2
  exit 2
fi

usage() {
  echo "usage: landing-verify.sh check <base-ref> <target-ref> <branch>..." >&2
  echo "       landing-verify.sh one <label> <src-ref> <base-ref> <target-ref> <pattern> [pathspec...]" >&2
  echo "       landing-verify.sh selftest" >&2
  exit 2
}

need_ref() {
  git rev-parse --verify --quiet "$1^{commit}" >/dev/null || {
    echo "landing-verify: no such ref: $1" >&2; exit 2; }
}

# git grep on a ref: 0 hit, 1 miss — anything else is an ERROR and must never
# read as a miss, because "absent" would then conflate content with plumbing.
tgrep() {  # ref pattern [pathspec...]
  local ref=$1 pat=$2; shift 2
  git grep -q -F -e "$pat" "$ref" -- "$@"
  local rc=$?
  [ "$rc" -le 1 ] || { echo "landing-verify: git grep failed (rc=$rc) on $ref — cannot read that as absent" >&2; exit 2; }
  return "$rc"
}

# On ABSENT, say whether the content moved or was reworded, so a human can
# tell without opening files. Tree-wide on purpose.
nearest() {  # target pattern
  local dst=$1 pat=$2 hit loose
  hit=$(git grep -n -F -e "$pat" "$dst" 2>/dev/null | head -1) || true
  if [ -n "$hit" ]; then printf '  moved? exact text found at: %s\n' "$hit"; return; fi
  loose=$(printf '%s' "$pat" | tr -s '[:space:]' ' ' | cut -d' ' -f1-4)
  hit=$(git grep -n -F -e "$loose" "$dst" 2>/dev/null | head -3) || true
  if [ -n "$hit" ]; then printf '  nearest (loosened to "%s"):\n%s\n' "$loose" "$(printf '%s\n' "$hit" | sed 's/^/    /')"
  else printf '  no loosened match either — gone, not moved or reworded\n'; fi
}

# The three arms. Only arm 3 returns a verdict (0 present / 1 absent);
# arms 1–2 return 2 = PRECONDITION. All arms share pattern and pathspec —
# that sharing is what makes arm 1 catch a wrong pathspec instead of
# blaming the tree.
marker_check() {  # label src-ref base-ref target-ref pattern [pathspec...]
  local label=$1 src=$2 base=$3 dst=$4 pat=$5; shift 5
  if [ "${_LV_MUTATE:-}" != "arm1" ]; then
    if ! tgrep "$src" "$pat" "$@"; then
      printf 'PRECONDITION: %s — marker does not match on %s; the MARKER is wrong, not the tree\n' "$label" "$src"
      return 2
    fi
  fi
  if [ "${_LV_MUTATE:-}" != "arm2" ]; then
    if tgrep "$base" "$pat" "$@"; then
      printf 'PRECONDITION: %s — marker already present on %s; it cannot discriminate\n' "$label" "$base"
      return 2
    fi
  fi
  if tgrep "$dst" "$pat" "$@"; then
    printf 'VERDICT: %s PRESENT\n' "$label"
    return 0
  fi
  printf 'VERDICT: %s ABSENT  <-- content did not arrive\n' "$label"
  nearest "$dst" "$pat"
  return 1
}

# Emit up to $3 "file<TAB>pattern" lines from the branch's own diff against
# its merge-base: longest added lines first, identifiers over prose, one per
# file, each proven unique on the authoring tree and absent from the base.
extract_markers() {  # branch merge-base want
  local br=$1 mb=$2 want=$3
  local emitted=0 seen_files=" " _score file pat hits
  while IFS=$'\t' read -r _score file pat; do
    [ -n "$pat" ] || continue
    case "$seen_files" in *" $file "*) continue;; esac
    hits=$(git grep -F -e "$pat" "$br" -- 2>/dev/null | wc -l | tr -d ' ')
    [ "$hits" = "1" ] || continue
    if tgrep "$mb" "$pat"; then continue; fi
    printf '%s\t%s\n' "$file" "$pat"
    seen_files="$seen_files$file "
    emitted=$((emitted + 1))
    [ "$emitted" -ge "$want" ] && break
  done < <(git diff "$mb" "$br" --no-color | awk '
      /^\+\+\+ b\// { f = substr($0, 7); next }
      /^\+\+\+ /    { f = ""; next }
      /^\+/ && f != "" {
        l = substr($0, 2); sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
        if (length(l) < 16 || length(l) > 200) next
        if (l !~ /[A-Za-z_][A-Za-z0-9_]{3,}/) next
        score = length(l)
        if (f !~ /\.(md|markdown|txt)$/) score += 500
        printf "%05d\t%s\t%s\n", score, f, l
      }' | sort -rn | head -200)
  return 0
}

# `check` refuses to run unless the selftest just passed with a positive
# tally. Missing tally, zero cases, or a non-zero exit all fail closed — a
# verifier nobody has watched go red is not a control.
selftest_gate() {
  [ "${_LV_SELFTEST:-}" = "1" ] && return 0
  local out rc n
  out=$(bash "$0" selftest 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out"
    echo "landing-verify: SELFTEST FAILED — refusing to produce verdicts with an unproven check (fail closed)"
    exit 2
  fi
  n=$(printf '%s\n' "$out" | sed -n 's/^SELFTEST PASS: \([0-9][0-9]*\)\/.*/\1/p' | head -1)
  case "$n" in
    ''|0|*[!0-9]*)
      printf '%s\n' "$out"
      echo "landing-verify: selftest exited 0 but printed no positive tally — fail closed"
      exit 2;;
  esac
}

cmd_check() {  # base-ref target-ref branch...
  local base=$1 dst=$2; shift 2
  need_ref "$base"; need_ref "$dst"
  local br; for br in "$@"; do need_ref "$br"; done
  selftest_gate

  local present=0 absent=0 precond=0 failed="" mb markers rc file pat b_absent
  for br in "$@"; do
    mb=$(git merge-base "$base" "$br") || {
      printf 'PRECONDITION: %s — no merge-base with %s\n' "$br" "$base"
      precond=$((precond + 1)); continue; }
    markers=$(extract_markers "$br" "$mb" "${MARKERS:-3}")
    if [ -z "$markers" ]; then
      printf 'PRECONDITION: %s — no discriminating marker extractable from its diff; verify this branch by hand\n' "$br"
      precond=$((precond + 1)); continue
    fi
    b_absent=0
    while IFS=$'\t' read -r file pat; do
      marker_check "$br ($file)" "$br" "$mb" "$dst" "$pat"; rc=$?
      case "$rc" in
        0) present=$((present + 1));;
        1) absent=$((absent + 1)); b_absent=1;;
        2) precond=$((precond + 1));;
      esac
    done <<EOF
$markers
EOF
    [ "$b_absent" = "1" ] && failed="$failed $br"
  done

  printf 'LANDING VERIFY: %d branch(es) — markers: %d PRESENT · %d ABSENT · %d PRECONDITION\n' \
    "$#" "$present" "$absent" "$precond"
  if [ "$absent" -gt 0 ]; then
    printf 'CONTENT DID NOT ARRIVE:%s — treat like a conflict: keep out of the certification, name in the review queue\n' "$failed"
    return 1
  fi
  [ "$precond" -gt 0 ] && return 3
  return 0
}

cmd_one() {  # label src base target pattern [pathspec...]
  local label=$1 src=$2 base=$3 dst=$4 pat=$5; shift 5
  need_ref "$src"; need_ref "$base"; need_ref "$dst"
  marker_check "$label" "$src" "$base" "$dst" "$pat" "$@"
  local rc=$?
  [ "$rc" = "2" ] && return 3
  return "$rc"
}

cmd_selftest() {
  export _LV_SELFTEST=1
  local SELF R pass=0 fail=0
  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  LV_ST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/landing-verify-st.XXXXXX") || exit 2
  trap 'rm -rf "$LV_ST_TMP"' EXIT
  R="$LV_ST_TMP/repo"; mkdir -p "$R"

  g() { git -C "$R" -c user.name=selftest -c user.email=selftest@local -c commit.gpgsign=false "$@"; }

  g init -q -b main
  {
    echo "shared boilerplate line that predates every ticket branch"
    echo "second base line, also long enough to be a marker candidate"
  } > "$R/base.txt"
  g add -A && g commit -q -m base
  g branch fixture-present && g branch fixture-dropped
  g switch -q fixture-present
  printf 'int wayfinder_marker_present_alpha(void) { return 42; }\n' > "$R/feat.c"
  g add -A && g commit -q -m feat
  g switch -q fixture-dropped
  printf 'int wayfinder_marker_dropped_beta(void) { return 7; }\n' > "$R/drop.c"
  g add -A && g commit -q -m drop
  g switch -q main && g switch -q -c landing
  g merge -q --no-ff --no-edit fixture-present >/dev/null
  # -s ours: exits 0, no conflict, commit fully reachable — content dropped.
  # The exact class the checker exists to catch.
  g merge -q -s ours --no-edit fixture-dropped >/dev/null

  run_case() {  # name want-rc must-contain must-not-contain cmd...
    local name=$1 want=$2 must=$3 mustnot=$4; shift 4
    local out rc ok=1
    out=$(cd "$R" && "$@" 2>&1); rc=$?
    [ "$rc" = "$want" ] || ok=0
    case "$out" in *"$must"*) :;; *) ok=0;; esac
    if [ -n "$mustnot" ]; then case "$out" in *"$mustnot"*) ok=0;; esac; fi
    if [ "$ok" = "1" ]; then
      echo "  ok: $name"; pass=$((pass + 1))
    else
      echo "  FAIL: $name (rc=$rc, wanted $want)"
      printf '%s\n' "$out" | sed 's/^/    | /'
      fail=$((fail + 1))
    fi
  }

  run_case "content that arrived reads PRESENT" 0 \
    "PRESENT" "<-- content did not arrive" \
    bash "$SELF" check main landing fixture-present
  run_case "silently dropped merge reads ABSENT (merge exited 0, commit reachable)" 1 \
    "ABSENT  <-- content did not arrive" "" \
    bash "$SELF" check main landing fixture-dropped
  run_case "marker typed from memory is PRECONDITION, never a verdict" 3 \
    "the MARKER is wrong, not the tree" "VERDICT" \
    bash "$SELF" one arm1-fixture fixture-present main landing \
    "int wayfinder_marker_typed_from_memory(void)"
  run_case "merge-base-present string is PRECONDITION: cannot discriminate" 3 \
    "cannot discriminate" "VERDICT" \
    bash "$SELF" one arm2-fixture fixture-present main landing \
    "shared boilerplate line that predates"
  run_case "mutation: arm 1 disabled, wrong marker becomes false ABSENT (arm proven load-bearing)" 1 \
    "ABSENT" "PRECONDITION" \
    env _LV_MUTATE=arm1 bash "$SELF" one arm1-mutated fixture-present main landing \
    "int wayfinder_marker_typed_from_memory(void)"
  run_case "mutation: arm 2 disabled, common string becomes false PRESENT (arm proven load-bearing)" 0 \
    "PRESENT" "PRECONDITION" \
    env _LV_MUTATE=arm2 bash "$SELF" one arm2-mutated fixture-present main landing \
    "shared boilerplate line that predates"

  local total=$((pass + fail))
  if [ "$fail" = "0" ] && [ "$total" -gt 0 ]; then
    echo "SELFTEST PASS: $pass/$total cases — PRESENT/ABSENT/PRECONDITION fixtures + both arms mutation-proven"
    return 0
  fi
  echo "SELFTEST FAIL: $pass/$total cases"
  return 2
}

case "${1:-}" in
  check)    [ $# -ge 4 ] || usage; shift; cmd_check "$@";;
  one)      [ $# -ge 6 ] || usage; shift; cmd_one "$@";;
  selftest) cmd_selftest;;
  *)        usage;;
esac

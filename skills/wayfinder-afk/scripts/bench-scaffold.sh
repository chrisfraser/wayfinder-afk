#!/usr/bin/env bash
# bench-scaffold.sh <map> [repo-root]
#
# Lays down bench/<map>/ for a wayfinder run's Phase 3: a run-all.sh that collects
# verdicts from every probe, and a RUN.md skeleton for the lead to fill in last.
# Idempotent — never overwrites an existing RUN.md.

set -euo pipefail

MAP="${1:?usage: bench-scaffold.sh <map> [repo-root]}"
ROOT="${2:-$(git rev-parse --show-toplevel)}"
DIR="$ROOT/bench/$MAP"

mkdir -p "$DIR"

cat > "$DIR/run-all.sh" <<'RUNNER'
#!/usr/bin/env bash
# Runs every probe here that needs no gesture, and collects the verdicts.
# A probe that never ran is reported separately — absence of a VERDICT is not an answer.

cd "$(dirname "$0")" || exit 1

verdicts=()
failed=()
ran=0
total=0

for p in probe-*.sh; do
  [ -e "$p" ] || continue
  total=$((total + 1))
  grep -q '^# Gesture: *yes' "$p" && continue   # needs a human hand; listed in RUN.md instead
  ran=$((ran + 1))
  printf '\n=== %s ===\n' "$p"
  out="$(bash "$p" 2>&1)"
  rc=$?
  printf '%s\n' "$out"
  v="$(printf '%s\n' "$out" | grep '^VERDICT:')" || v=""
  if [ "$rc" -ne 0 ] || [ -z "$v" ]; then
    failed+=("$p (exit $rc)")
  else
    verdicts+=("$v")
  fi
done

# An empty bench must not read as a passed bench: zero probes means nothing was
# asked, and "nothing asked" exiting 0 is the absence-of-errors trap.
if [ "$total" -eq 0 ]; then
  printf 'NO PROBES FOUND in %s — nothing ran, nothing is answered.\n' "$(pwd)"
  exit 1
fi
if [ "$ran" -eq 0 ]; then
  printf 'All %d probe(s) here need a gesture — nothing to batch-run. Use RUN.md.\n' "$total"
  exit 0
fi

printf '\n========== VERDICTS (%d/%d) ==========\n' "${#verdicts[@]}" "$ran"
[ "${#verdicts[@]}" -gt 0 ] && printf '%s\n' "${verdicts[@]}"

if [ "${#failed[@]}" -gt 0 ]; then
  printf '\n---------- DID NOT RUN (%d) — no answer, not a negative answer ----------\n' "${#failed[@]}"
  printf '%s\n' "${failed[@]}"
  exit 1
fi
RUNNER

chmod +x "$DIR/run-all.sh"

if [ ! -e "$DIR/RUN.md" ]; then
  cat > "$DIR/RUN.md" <<HEADER
# Bench session — map #$MAP

<!-- scaffolded by /wayfinder-afk Phase 3; the lead fills this in last, once every probe is in.
     Order the sections by DEVICE so each radio is picked up once. Format: TEMPLATES.md. -->

Everything this map needs from you that a machine couldn't get.
Answer straight back into the frontier comments: \`D1 ratify · Q3 B\`.

## Before you start

- <preconditions>
- \`bash bench/$MAP/run-all.sh\` runs everything needing no gesture and prints one verdict block.

## Nothing to run — judgement only

- <#iid Q n — why no probe can settle it>

## If a probe fails

A failed precondition prints \`PRECONDITION:\` and exits non-zero. That is not an answer —
it means the probe never ran. Only a \`VERDICT:\` line settles anything.
HEADER
fi

printf 'bench/%s/ ready: run-all.sh%s\n' "$MAP" \
  "$([ -e "$DIR/RUN.md" ] && printf ', RUN.md')"

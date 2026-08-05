#!/usr/bin/env bash
# device-lease.sh claim <serial> <map> [ttl-min] | release <serial> <map>
#                | check <serial> | list
#
# Host-local hardware leases, so two AFK runs on different maps can share a
# bench without driving the same device at once. A lease names the MAP that
# holds it, never a process: agent shells live for one command, so PID liveness
# proves nothing — expiry is by TTL (default 60 min, LEASE_TTL_MIN or the third
# argument), and the holder renews by re-claiming. Claiming a lease your map
# already holds IS the renewal.
#
# The lock is mkdir, which is atomic on POSIX; the owner file inside carries
# map/epoch/ttl/who. Leases live under $WAYFINDER_LEASE_DIR (default
# ~/.wayfinder/leases) — host-local on purpose: an ADB device is attached to
# THIS host, so any run competing for it is on this host too. A bench shared
# across machines needs a tracker-side convention; this script does not pretend
# to cover that.
#
# Exit codes are the contract, and each is a different fact:
#   0  claimed / renewed / released / free
#   3  held live by another map — the device is busy; busy is an answer
#   4  release refused — the lease belongs to another map
#   2  usage
#
# A refused claim is not an error in your logic. Report which map holds the
# device and hand the probe over unvalidated; never wait, never break a live
# lease. Only an EXPIRED or CORRUPT lease is claimable over.

set -euo pipefail

LEASE_ROOT="${WAYFINDER_LEASE_DIR:-$HOME/.wayfinder/leases}"

usage() {
  echo "usage: device-lease.sh claim <serial> <map> [ttl-min] | release <serial> <map> | check <serial> | list" >&2
  exit 2
}

slug() { printf '%s' "$1" | tr '/ ' '__'; }
now()  { date +%s; }

# Reads $1/owner into O_MAP O_TS O_TTL O_BY. Returns 1 on anything unreadable or
# non-numeric — a half-written owner file (claimer died mid-write) must read as
# CORRUPT/stale, never as a live lease with garbage arithmetic behind it.
read_owner() {
  local f="$1/owner"
  O_MAP="$(sed -n 's/^map=//p'     "$f" 2>/dev/null | head -1)"
  O_TS="$(sed -n 's/^epoch=//p'    "$f" 2>/dev/null | head -1)"
  O_TTL="$(sed -n 's/^ttl_min=//p' "$f" 2>/dev/null | head -1)"
  O_BY="$(sed -n 's/^by=//p'       "$f" 2>/dev/null | head -1)"
  case "$O_MAP" in '') return 1;; esac
  case "$O_TS"  in ''|*[!0-9]*) return 1;; esac
  case "$O_TTL" in ''|*[!0-9]*) return 1;; esac
  return 0
}

expired() { [ $(( $(now) - O_TS )) -gt $(( O_TTL * 60 )) ]; }
age_min() { echo $(( ( $(now) - O_TS ) / 60 )); }

write_owner() {   # $1 dir  $2 map  $3 ttl-min
  {
    printf 'map=%s\n' "$2"
    printf 'epoch=%s\n' "$(now)"
    printf 'ttl_min=%s\n' "$3"
    printf 'by=%s@%s\n' "${USER:-?}" "$(hostname -s 2>/dev/null || echo '?')"
  } > "$1/owner.tmp"
  mv "$1/owner.tmp" "$1/owner"
}

cmd_claim() {     # serial map [ttl]
  local serial="$1" map="${2#\#}" ttl="${3:-${LEASE_TTL_MIN:-60}}"
  case "$ttl" in ''|*[!0-9]*) echo "device-lease: ttl must be minutes, got '$ttl'" >&2; exit 2;; esac
  local dir="$LEASE_ROOT/$(slug "$serial")"
  mkdir -p "$LEASE_ROOT"
  if mkdir "$dir" 2>/dev/null; then
    write_owner "$dir" "$map" "$ttl"
    echo "LEASED — $serial to map #$map for ${ttl}m"
    return 0
  fi
  if read_owner "$dir"; then
    if [ "$O_MAP" = "$map" ]; then
      write_owner "$dir" "$map" "$ttl"
      echo "RENEWED — $serial for map #$map, ${ttl}m from now"
      return 0
    fi
    if ! expired; then
      echo "HELD — $serial is leased to map #$O_MAP by $O_BY, $(age_min)m ago, $(( O_TTL - $(age_min) ))m left. Not touched."
      return 3
    fi
    echo "STALE — map #$O_MAP's lease on $serial expired $(( $(age_min) - O_TTL ))m ago; breaking it."
  else
    echo "CORRUPT — lease on $serial has no readable owner; treating as stale and breaking it."
  fi
  rm -rf "$dir"
  if mkdir "$dir" 2>/dev/null; then
    write_owner "$dir" "$map" "$ttl"
    echo "LEASED — $serial to map #$map for ${ttl}m"
    return 0
  fi
  echo "HELD — another claim won the race for $serial. Re-run check."
  return 3
}

cmd_release() {   # serial map
  local serial="$1" map="${2#\#}"
  local dir="$LEASE_ROOT/$(slug "$serial")"
  if [ ! -d "$dir" ]; then
    echo "FREE — $serial holds no lease. Nothing to release."
    return 0
  fi
  if read_owner "$dir" && [ "$O_MAP" != "$map" ]; then
    echo "NOT YOURS — $serial is leased to map #$O_MAP, not #$map. Leaving it."
    return 4
  fi
  rm -rf "$dir"
  echo "RELEASED — $serial (was map #$map)"
}

cmd_check() {     # serial
  local serial="$1"
  local dir="$LEASE_ROOT/$(slug "$serial")"
  if [ ! -d "$dir" ]; then
    echo "FREE — $serial"
    return 0
  fi
  if read_owner "$dir"; then
    if expired; then
      echo "EXPIRED — $serial was leased to map #$O_MAP by $O_BY, ttl ran out $(( $(age_min) - O_TTL ))m ago. Claimable."
      return 0
    fi
    echo "HELD — $serial leased to map #$O_MAP by $O_BY, $(age_min)m ago, $(( O_TTL - $(age_min) ))m left"
    return 3
  fi
  echo "CORRUPT — $serial has a lease dir but no readable owner. Claimable as stale."
  return 0
}

cmd_list() {
  mkdir -p "$LEASE_ROOT"
  local any=0 d serial
  for d in "$LEASE_ROOT"/*/; do
    [ -d "$d" ] || continue
    any=1
    serial="$(basename "$d")"
    if read_owner "$d"; then
      if expired; then
        printf '%s  map #%s  by %s  EXPIRED %sm ago\n' "$serial" "$O_MAP" "$O_BY" "$(( $(age_min) - O_TTL ))"
      else
        printf '%s  map #%s  by %s  %sm old, %sm left\n' "$serial" "$O_MAP" "$O_BY" "$(age_min)" "$(( O_TTL - $(age_min) ))"
      fi
    else
      printf '%s  CORRUPT owner file — claimable as stale\n' "$serial"
    fi
  done
  [ "$any" = "1" ] || echo "no leases under $LEASE_ROOT"
}

case "${1:-}" in
  claim)   [ $# -ge 3 ] || usage; cmd_claim "$2" "$3" "${4:-}";;
  release) [ $# -ge 3 ] || usage; cmd_release "$2" "$3";;
  check)   [ $# -ge 2 ] || usage; cmd_check "$2";;
  list)    cmd_list;;
  *)       usage;;
esac

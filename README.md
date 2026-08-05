# wayfinder-afk

An agent skill that works a [`/wayfinder`](https://github.com/mattpocock/skills) map while you're away, then sits with you when you're back.

```
/wayfinder-afk #23              run the map unattended
/wayfinder-afk collect #23      collect your answers and apply them
```

Wayfinder plans a big chunk of work as a **map** of decision tickets on your issue tracker, and resolves them one ticket per session, with you in the room. This skill breaks that constraint in both directions: it sweeps every ticket that doesn't need you, and it makes the ones that do as cheap as possible to answer.

## What it does

### `/wayfinder-afk #23` — the unattended run

Three jobs, in order.

1. **Sweep** — every takeable AFK ticket (`research`, and `task` the agent can drive alone) is claimed and worked in parallel, one subagent each. Calls it can defend are taken and recorded for ratification; the rest are escalated to a review queue on the map. It never stalls, and it loops until nothing takeable is left.
2. **Frontier** — the human-in-the-loop tickets (`grilling`, `prototype`) are *prepared*, never resolved. Each gets investigated to the exact point where your judgement is genuinely needed, then one **frontier comment**: facts established, decisions to ratify, and numbered questions — each with why it matters, the options, a recommendation, and what would settle it. A `prototype` ticket gets its rough artifact built first, so you're reacting to something concrete.
3. **Bench kit** — for every remaining question it asks: *is this a preference, or a fact nobody went and got?* A fact a machine can fetch isn't a question, it's an unbuilt probe. It builds the smallest thing that turns each one into a one-command verdict — a one-liner, a shell probe, a test, or as a last resort a throwaway bench app — collected in `bench/<map>/` with a session plan ordered so you pick up each device once.

You come back to a map where the easy work is closed, the hard work is a numbered list, and most of the list has a command that answers it. The repo comes back clean: everything the run made is committed and pushed — a draft MR where work is meant to land, a throwaway `wayfinder/*` branch where it isn't — and never a dirty tree. Runs on different maps can share a machine and a bench: tickets are claimed, branches are namespaced, and devices are taken by lease (`scripts/device-lease.sh`), so two unattended runs won't drive the same radio.

### `/wayfinder-afk collect #23` — the guided session

A conversation, not a report. Nothing is dumped in bulk, nothing is answered on your behalf, and the map is updated as you go.

1. **Ratify** — the calls the run took, grouped by shared premise, approve or decline. These come first because everything else rests on them; a decline changes which questions get asked at all.
2. **Grill** — the open questions, one at a time, ordered so that answers prune later questions. After every answer it says what that settled, made moot, and unlocked.
3. **Reconcile** — what your answers just did to the bench kit, before a single probe runs. A probe that looks moot is often the only check on the answer that made it moot.
4. **Bench** — the probes, one at a time, in device order. You run them and paste, or it runs the read-only ones and reads the logs itself.

Everything is banked at each boundary, so a session that dies loses only the questions not yet asked. `--dry-run` walks the whole session and writes nothing.

## Install

```bash
npx skills@latest add chrisfraser/wayfinder-afk
```

Works with Claude Code, Codex, and anything else the [skills CLI](https://skills.sh) supports. The skill is **user-invoked only** — it will never fire on its own, only when you type it.

## Requirements

- **[`/wayfinder`](https://github.com/mattpocock/skills) — a hard dependency.** This skill inherits its entire vocabulary from it: map, ticket, frontier, fog, HITL/AFK, plan-don't-do. Both modes read `wayfinder/SKILL.md` before doing anything, and stop if it isn't installed.

  ```bash
  npx skills@latest add mattpocock/skills
  ```

  Take `wayfinder` and `setup-matt-pocock-skills` at minimum. `research`, `prototype` and `grilling` are used by the run's subagents where the ticket type calls for them.

- **A tracker doc.** `docs/agents/issue-tracker.md` in your repo, written by `/setup-matt-pocock-skills`. It says where maps, tickets and blocking relationships physically live.

- **`glab` and `jq`**, for the bundled scripts only. `scripts/map-frontier.sh` (what's takeable right now) and `scripts/answers.sh` (what's been answered since the frontier) are GitLab-specific. On another tracker the skill derives the same buckets by hand — everything else works unchanged.

## What's in the box

```
skills/wayfinder-afk/
  SKILL.md             the contract, the dispatch, and the invariants both modes share
  run/PHASES.md        the unattended run: sweep, frontier, bench kit, handover
  run/PLAYBOOK.md      the decision test, subagent briefs, the probe contract, concurrency
  run/TEMPLATES.md     exact shapes for every comment and map section the run posts
  collect/STAGES.md    the guided session: ratify, grill, reconcile, bench, apply
  collect/PLAYBOOK.md  grouping, ordering, parsing answers, applying idempotently
  collect/TEMPLATES.md what you see in the session, and what gets written to the tracker
  scripts/             map-frontier.sh · answers.sh · bench-scaffold.sh · device-lease.sh
```

## How the two halves stay in sync

Every comment either mode posts carries a `<!-- wayfinder:agent -->` stamp. The agent posts under the same token as you, so authorship distinguishes nothing — the stamp is how `collect` tells the run's own writing from your answers. An unstamped comment on a grilling ticket is read as an answer.

Everything durable lives on the tracker, so a lost session costs nothing: frontiers, the review queue and the run report are all server-side, and one script rebuilds the picture.

## Credits

Built on [mattpocock/skills](https://github.com/mattpocock/skills) — `/wayfinder` is Matt Pocock's, and this skill is a pair of bookends around it, not a replacement for it.

Licensed under GPL-3.0. See [LICENSE](LICENSE).

---
name: wayfinder-afk
description: Works a wayfinder map while you're away, then sits with you when you're back. `/wayfinder-afk #23` sweeps every AFK ticket in parallel subagents, prepares the human-in-the-loop ones as bulk-answerable question frontiers, and builds a bench kit that turns each remaining question into a one-command verdict. `/wayfinder-afk collect #23` runs the guided session that turns your answers back into the map.
disable-model-invocation: true
---

# Wayfinder AFK

The two halves of moving a `/wayfinder` map while the human isn't in the room.

**Run** turns a map into questions: it clears everything that doesn't need the human, frames what's left so it can be answered in bulk, and builds the rig that makes answering it a one-command verdict. **Collect** turns the answers back into a map: a guided session over the calls the run took, the questions it raised, and the probes it built.

They are a pair. Run's output is shaped for collect's input, and every comment either one posts carries the same stamp so collect can tell the agent's writing from the human's.

## Invocation

```
/wayfinder-afk #23                      run the map unattended
/wayfinder-afk run #23                  the same, said explicitly
/wayfinder-afk collect #23              the guided answering session
/wayfinder-afk collect #23 --dry-run    the session, writing nothing
/wayfinder-afk collect #23 --stage 2    the session, starting at a stage
```

**Dispatch**: first argument is `collect` → collect mode. Anything else — a bare map id, a map URL, or an explicit `run` — → run mode. Flags belong to collect and are described there.

A map is **required**. Without one, ask which map; never pick one.

- **Run mode** → read [run/PHASES.md](run/PHASES.md) and follow it.
- **Collect mode** → read [collect/STAGES.md](collect/STAGES.md) and follow it.

Read only the mode you were invoked in. The other half's playbook is a large document that will not help you.

## First, the vocabulary

Both modes inherit their vocabulary — map, ticket, frontier, fog, HITL/AFK, plan-don't-do — from the `/wayfinder` skill, which is a **dependency**, not a suggestion. Read its `SKILL.md` once at the start of either mode:

```
~/.agents/skills/wayfinder/SKILL.md      or      ~/.claude/skills/wayfinder/SKILL.md
```

If neither exists, say so and stop: install it with `npx skills@latest add mattpocock/skills`. Guessing at the map format is how a run corrupts one.

Where the map, its child tickets, blocking and frontier queries physically live is **tracker-specific**. `docs/agents/issue-tracker.md` in the repo is authoritative; run `/setup-matt-pocock-skills` if it isn't there. The bundled scripts are GitLab-specific — on another tracker, derive the same buckets by hand.

## Invariants — both modes

1. **Every comment this skill posts ends with `<!-- wayfinder:agent -->`.** The agent posts under the same token as the human, so authorship distinguishes nothing. Collect reads the stamp to tell the run's own output from the human's answers; an unstamped comment on a grilling ticket will be read as an answer.
2. **Never answer for the human.** Grilling and prototype tickets are HITL. A recommendation is not an answer, and only their answer closes one.
3. **Only the lead writes the map body.** Subagents write their own ticket and report back; concurrent map edits lose data. Re-read the body immediately before editing it — another session may be on the same map.
4. **Claim before work.** Assigning the ticket is the first action, always.
5. **Commit to a branch, never push.** No merging, no touching `main`. A run that dies mid-way must strand nothing and touch nothing shared. Restore the branch the user started on when the session ends.
6. **Build for the hardware, never drive it.** No installing, flashing, factory-resetting, and above all **no rebooting** — a reboot has already ended Wi-Fi ADB permanently on a radio and stranded it mid-run. Read-only checks on a device the session explicitly owns are the only exception, and in collect the human can lift the ban in the turn they lift it.
7. **Assert on a positive signal, never on the absence of a negative one.** `BUILD SUCCESSFUL`, an exit code you actually captured, a parsed result file — never "grep found no errors". If your shell filters command output, bypass the filter for anything whose *failure* you must see (`rtk proxy <cmd>`, if that's the filter).
8. **Deferred is not dropped**, and unread is a legitimate outcome. A fabricated answer is not.

## What's in here

```
run/PHASES.md        the unattended run: sweep, frontier, bench kit, handover
run/PLAYBOOK.md      the decision test, subagent briefs, the probe contract, concurrency
run/TEMPLATES.md     exact shapes for every comment and map section the run posts
collect/STAGES.md    the guided session: ratify, grill, reconcile, bench, apply
collect/PLAYBOOK.md  grouping, ordering, parsing answers, applying idempotently
collect/TEMPLATES.md what the human sees in the session, and what gets written
scripts/            map-frontier.sh · answers.sh · bench-scaffold.sh
```

Script paths in the mode documents are relative to this skill's directory.

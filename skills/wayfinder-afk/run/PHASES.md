# Run mode — `/wayfinder-afk <map>`

Work a wayfinder map unattended. Three jobs, in order: **clear everything that doesn't need the human**; **frame what's left so it can be answered in bulk**; **build the rig that makes answering it a one-command verdict**. The measure of a run is how short the human's session at the bench is afterwards — and a map that ends the run bigger than it started has usually failed that test, whatever else it produced.

Read the `/wayfinder` skill's `SKILL.md` once at the start if you haven't — this mode inherits its vocabulary and overrides exactly two things.

## Quick start

```
/wayfinder-afk #293
```

`bash scripts/map-frontier.sh 293` prints every child ticket bucketed TAKEABLE / CLAIMED / BLOCKED / CLOSED, with blockers resolved. Run it at the top of every round. It is GitLab-specific; on another tracker, derive the same four buckets by hand.

## The two overrides

1. **Many tickets per run, not one.** Wayfinder resolves one ticket per session. Here, every takeable AFK ticket — `research`, and `task` the agent can drive alone — is claimed and worked **in parallel**, one subagent each, launched in a single message.
2. **Grilling and prototype tickets are prepared, never resolved.** They are HITL. The agent never answers for the human and never closes one. The value added is investigation, a built artifact where the ticket calls for one, and a question frontier they can answer in bulk.

## Phase 0 — Orient

Load the map body: destination, Notes, standing constraints, Decisions so far. **Standing constraints are not relitigated** — a sweep that reopens them has failed. Run the frontier script. Announce the plan: what will be swept, what will be prepped, what is already blocked on the human.

## Phase 1 — AFK sweep loop

Each **round**:

1. Recompute the frontier. Clear its two warning sections **before** taking anything, because both mean the picture is wrong: **COMPLETE BUT OPEN** names resolved tickets whose close never landed — finish those closes first, they are free wins and they otherwise sit in CLAIMED forever, which no round retakes; **UNLABELLED** names tickets attached to this map but in no bucket. Then take every TAKEABLE `research` ticket and every TAKEABLE `task` ticket that has no human-only step.
2. Launch one subagent per ticket, all in one message. Each claims its ticket **before** any work, then runs the **intake check** ([PLAYBOOK.md](PLAYBOOK.md)) before doing any: is it already complete, and if not, has anything changed the path to completeness? A ticket resolved a second time, or resolved against a premise that expired last round, costs more than one never taken.
3. A `task` ticket needing hardware, credentials, money, or a human hand is **not** AFK: the subagent leaves a precise do-this checklist on the ticket, leaves it open, and reports it as blocked on the human.
4. Collect results. Only the lead touches the map: append closed tickets to Decisions so far, graduate fog, add escalations to the review queue, and route every proposed new ticket through the **ticket test** ([PLAYBOOK.md](PLAYBOOK.md)) — the lead is the second gate, and rejects here are normal.
   **Then write every reported invalidation onto the ticket it invalidates** — a comment naming what changed, which part of that ticket is now void, and where the new fact came from. This is what makes the next round's intake check work: subagents can only detect a changed path if the change was written down where the next reader will stand. An invalidation reported to the lead and not written to the ticket is lost, and the ticket it should have stopped gets worked anyway, against a premise that expired in the previous round. Questions for the human become numbered questions on an existing frontier, not tickets. What survives is created-then-wired, **each filed with its `wayfinder:<type>` label and a `Part of:` pointer at this map, or the next round's frontier will not see it** (TEMPLATES.md, and the crib in PLAYBOOK.md).
5. **Reconcile against the tracker, not the reports.** Re-run the frontier script. Every ticket a subagent said it closed must now be in CLOSED, and the **COMPLETE BUT OPEN** section must be empty. Anything it names is resolved work whose close never landed: read the resolution comment, satisfy yourself the work is done, close it yourself, and confirm the state. A subagent's word is a claim; the tracker is the fact.
6. Count the round from that reconciled state: closed, filed, **net**. Say it out loud each round. Counting from the reports instead is how a run reports six closed and leaves four open.
7. Loop. Stop when no TAKEABLE research/task ticket remains, when a round closes nothing new, or after 4 rounds — then say which and why. If a round ends **net-positive** (filed more than it closed), the next round is **closing-only**: no new tickets at all, candidates held in the map's `## Candidate tickets` list. Two net-positive rounds in a row stops the loop — the map is growing faster than the run can clear it, and that is a finding for the lead, not a reason for a fifth round.

## Phase 2 — Grilling frontier pass

Order open `grilling` and `prototype` tickets by how many other tickets they unblock, descending. One subagent each, parallel, capped as in [PLAYBOOK.md](PLAYBOOK.md).

Each investigates to the exact point where a human decision is genuinely required, then posts one **frontier comment**: decisions already taken (to ratify), facts established, then as many numbered questions as the ticket can carry — each with why it matters, the options, a recommendation, what it unblocks, and **what would settle it**. Questions that depend on an answer in this round go in a *later rounds* list, not the frontier.

A `prototype` ticket gets its artifact **built** first — cheap and rough, via `/prototype` — committed to the ticket's branch and linked from the ticket. Its frontier then asks the human to react to something concrete. Building it is not resolving it: the ticket stays open, the decision stays theirs.

The lead then **de-duplicates across tickets**: a question belongs to exactly one ticket; the others cross-reference it.

## Phase 3 — Bench kit

Everything still open is now waiting on the human. This phase shrinks that wait.

Take every blocked ticket and every frontier question and ask: **is this a preference, or a fact nobody went and got?** A fact a machine could fetch is not a question — it's an unbuilt probe. Build the smallest thing that turns each one into a one-command verdict, cheapest rung of the ladder first: a copy-pasteable `adb` one-liner, a shell probe, a test in a module that already exists, and only when the answer needs the app's own identity or a gesture on a real screen, a throwaway bench app. Ladder, probe contract and hardware bans: [PLAYBOOK.md](PLAYBOOK.md).

Collect them in `bench/<map>/` on `wayfinder/<map>-bench`, with `RUN.md` — a session plan ordered so each device is picked up **once** — and `run-all.sh` for everything needing no gesture. `bash scripts/bench-scaffold.sh <map>` lays both down. Every probe is **proven to build** before handover, asserted on a positive signal and with any output filter bypassed: a probe that doesn't run costs more than no probe.

Then amend the frontiers already posted — each question gains a `Settled by:` line naming its probe, or saying it is judgement with nothing to run.

## Phase 4 — Handover

Post a run report on the map and print the same, tighter, to the terminal: the **net** ticket count first (closed, filed, and what the map now stands at), then what closed, what calls were taken (ratify list), what is blocked on the human, where each grilling frontier stands, and the one command that starts the bench session. A run that left the map bigger than it found it says so in its first line — that is the number the lead is entitled to see without asking.

Everything durable lives on the tracker, so a lost session costs nothing: the frontiers, the review queue and the report are all server-side, and `bash scripts/map-frontier.sh <map>` rebuilds the picture in one command. Say so, and name the branches — they're local and unpushed, and nothing but the tickets points at them. When the answers come back, `/wayfinder-afk collect <map>` applies them; **every comment this run posts carries the `<!-- wayfinder:agent -->` stamp** so collect can tell them from the human's replies.

## Standing rules

1. **Decide or escalate — never stall.** Confident and reversible: take the call, record it as pending ratification, move on. Otherwise write it to the map's review queue and take the next ticket. The test is in [PLAYBOOK.md](PLAYBOOK.md).
2. **Claim before work.** Assigning the ticket is the first action, always — other sessions may be running the same map.
3. **Only the lead writes the map body.** Subagents write their own ticket and report back; concurrent map edits lose data.
4. **Plan, don't do — except at the bench.** Task tickets do only what unblocks a decision, and the destination isn't built unless the map's Notes say to. Probes and bench apps are the exception: they exist to get an answer, not to ship, and the more of them the better.
5. **Commit to a branch, never push — and isolate anything that writes.** A ticket that produces files works on `wayfinder/<map>-<iid>-<slug>` and commits there, so a run that dies mid-way strands nothing. No pushing, no merging, no touching `main`. The ticket names its branch. Launch every file-producing subagent with `isolation: "worktree"`: parallel agents sharing one worktree move HEAD under each other, and branches end up chained instead of independent. Restore the branch the user started on when the run ends.
6. **Never leave a ticket blocked on itself**, and never claim a ticket the run won't work this round.
7. **Disposable by construction.** Probes and bench apps live under `bench/`, nothing in the product imports them, and dropping the branch removes every trace. They are allowed to be rough; they are not allowed to be permanent.
8. **Build for the hardware, never drive it.** Prove a probe compiles; leave the running to the human. No installing, flashing, factory-resetting, and above all **no rebooting** — a reboot has already ended Wi-Fi ADB permanently on a radio and stranded it mid-run. Read-only checks on a device the run explicitly owns are the only exception.

Formats for every comment and map section: [TEMPLATES.md](TEMPLATES.md). Subagent briefs, the decision test, ordering, and tracker commands: [PLAYBOOK.md](PLAYBOOK.md).

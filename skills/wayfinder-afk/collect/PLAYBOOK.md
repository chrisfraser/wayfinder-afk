# Playbook

## Stage 1 — grouping the run's calls

A group is a claim that these calls stand or fall together. Make it only when true.

**Group when** the calls share a premise (all follow from one finding), a subsystem (all shape the same file or interface), or a fate (approving one and rejecting another leaves an incoherent design). Name the shared thing in the card — if it can't be named in a clause, it isn't a group.

**Split when** one call could sensibly go the other way on its own, when they have different reversal costs, or when they came from different tickets and only look alike.

**Never group** — these are always their own approval:

- a call that **amends or contradicts a standing constraint** on the map;
- a call that is **irreversible**, or expensive to unwind once code lands on it;
- anything the run recorded at **medium confidence**;
- a call that **another map or another team** would inherit.

Six to eight groups is a healthy shape for thirty calls. Two is hiding something; twenty is not grouping.

Offer **split this group** on every group. If they take it, ask the members individually, in the same round if there are four or fewer; more than four and they queue behind the groups still to come, four per round, until every member has been asked. Splitting adds rounds — it never converts the leftovers into prose.

A **decline** is work, not a note: name what was built on the call, reverse it or file the ticket that does, record the reversal under `## Decisions so far` (it is itself a decision), and re-derive the stage-2 questions that rested on it *before* asking them.

## Stage 2 — ordering the frontier

Sort by, in order:

1. **Dependency** — a question whose answer settles, moots or reshapes others goes first. This is what makes one-at-a-time cheaper than bulk rather than more expensive.
2. **Blast radius** — how many tickets the answer unblocks.
3. **Premise adjacency** — questions resting on the same fact are asked together so the human stays in one context. Never break a premise cluster to preserve ticket order.

Order **across tickets**. Ticket-by-ticket is the wrong grain whenever a dependency crosses, and on a real map it always does.

After each answer, re-derive and **say what changed**: what it settled, what it made moot, what it unlocked from the *later rounds* list. Silent pruning wastes the format.

**Questions with a probe are not asked here.** `Settled by: bench/…` means a machine can get the fact; route it to stage 3 and recommend deferring. The exception is when they say they'd rather just decide it — their call, and note in the ledger that the probe was skipped by choice.

## Stage 2.5 — how an answer invalidates a probe

Four classes. State which, and what it costs, then let them decide:

- **Moot** — its question was settled in stage 1 or 2, so the probe has nothing left to answer. Cheap to drop, but check first: if the answer was a *judgement* and the probe measures the *fact* it assumed, running it is the only thing that can catch a wrong assumption. Recommend running it anyway when the answer was theirs rather than derived.
- **Re-mapped** — the question survives but its options changed, so the probe's `VERDICT: … => Q<n> = B` mapping now points at an option that no longer exists. The probe is still good; its verdict line is stale. Rewrite the mapping before running it, or its output will be read as the wrong answer.
- **Contradicted** — the answer asserts something the probe was built to test, in the opposite direction. This is the valuable case. Run it, and say plainly that the point is to test their answer.
- **Missing** — an answer created a new factual question with no probe. Say so; building it is a run-mode job, not this session's, unless it's a one-liner, in which case offer it inline.

## Stage 3 — running the bench

Follow `RUN.md`'s device order. Never reorder in a way that picks a radio up twice.

**Ask how each probe should be run.** Two modes:

- **They run it** — give the exact command, the shape of a good result, and what each outcome implies. They paste the output.
- **The agent runs it** — only for a **read-only** probe on a device the run can already reach. Say which device, and confirm before the first one.

**Reading the logs** is the third source, and often the best one for anything asynchronous: tail with a filter (`adb logcat -s <TAG>` or the app's tag) while they perform the gesture, then interpret. Use it when the probe's evidence is a log line rather than a command's exit. Start the tail *before* telling them to act.

Bans carry over from run mode: no install, flash, factory-reset or **reboot** unless they say so in that turn. A reboot has already stranded a radio for a whole run.

`VERDICT:` settles its question — apply it immediately and say so. `PRECONDITION:` means the probe never ran; it is not a negative answer, and a probe that never ran leaves its question open. If a verdict **contradicts a stage-2 answer**, stop: present both, say which the evidence supports, and let them re-answer.

## Parsing what they say

- **Prose beats shorthand.** `B but only above API 30` is B **plus a constraint**; dropping the constraint is the main way this skill can do damage.
- **A reason is part of the answer.** Carry it onto the ticket; the next agent needs the why.
- **"Skip", "leave it", "later"** are *deferred* — an explicit state, carried into the next frontier.
- **Silence is not deferral.** Unasked is uncollected; unparseable is unread.
- A **new question in their reply** becomes a ticket or a next-round item, never something answered on the spot.

## Contradictions — stop and ask

Blocking is right here and nowhere else: the same number answered two ways with no clear ordering; an answer that reverses a standing constraint (confirm, then apply as an amendment with the old text struck through); an answer that contradicts a fact established in the frontier; an option that wasn't offered.

## Applying, and idempotency

Bank at every boundary — after stage 1, after each ticket in stage 2, after each probe in stage 3.

Order within a bank: map body first (ratifications into `## Decisions so far`, queue entries removed, amended constraints struck through), then the ticket's `## Settled` comment, then reversals, then disposition (close, or round n+1 frontier), then new tickets wired, then dependents unblocked, then fog, then the applied marker.

Every comment carries `<!-- wayfinder:agent -->`; every ticket applied to gets an applied marker naming the note ids consumed. `answers.sh` filters both, so a re-run sees only what is new. Check for a marker covering the same round before writing: if one exists, report and skip.

## Subagent brief — apply one ticket

```
Ticket: #<iid> — <title> (<url>)
Map: #<map>. Destination: <one line>. Standing constraints: <digest, incl. any amended this session>.

The human answered these in a guided session. Their answers, verbatim:
<ledger rows for this ticket — state, number, their words, source>

1. Post ONE "Settled" comment (TEMPLATES.md) restating each question and their answer in
   the ticket's own words, carrying their reasoning. Add no reasoning of your own, and do
   not argue with an answer that went against the recommendation.
2. Every question answered or deferred → close the ticket. Otherwise post a round <n+1>
   frontier: what is unanswered, what their answers unlocked, what is newly askable.
3. Post the applied marker naming what you consumed.
4. Do NOT edit the map body. Do NOT invent an answer to anything left unread.

Report back: what you settled, what you carried forward, new tickets their answers make
specifiable, and anything they said that bears on a DIFFERENT ticket on this map.
```

## Tracker crib (GitLab / `glab`)

- Notes: `glab api "projects/:fullpath/issues/<iid>/notes?per_page=100&sort=asc&order_by=created_at"`. `glab` prints a multi-config warning **on stdout** — strip to the first `[`/`{`. `--output json`, never `-F json`.
- `"system": true` notes are GitLab's own cross-reference chatter — always filtered.
- Comment: `glab issue note <iid> --message "..."`. Close: comment first, then `glab issue close <iid>` — close takes no message.
- Child discovery and blockers: `bash scripts/map-frontier.sh <map> --json`. Shell out; don't duplicate the query.

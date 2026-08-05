# Collect mode — `/wayfinder-afk collect <map>`

The bookend to the run. That mode turns a map into questions; this one sits with the human and turns their answers back into a map.

It is a **guided session**, not a report. Nothing is dumped in bulk, nothing is answered on their behalf, and the map is updated as the session goes rather than at the end.

Read the `/wayfinder` skill's `SKILL.md` once at the start if you haven't — this mode inherits its vocabulary.

## The session shape — this order, always

1. **Ratify** — every automatic decision the run took, grouped, approve or decline.
2. **Grill** — every open question, one at a time, logically ordered.
3. **Bench** — every probe, guided, results from the terminal or the logs.

Between 2 and 3 sits the **reconcile** step: the answers in stage 2 routinely invalidate probes built in stage 3, and that is discussed before anything is run.

## Invocation

```
/wayfinder-afk collect #293                 the full session, applied as it goes
/wayfinder-afk collect #293 --dry-run       the full session, writes nothing
/wayfinder-afk collect #293 --stage 2       start at a stage; earlier ones are summarised, not run
```

**`--dry-run` is absolute.** No comment, no close, no map edit, no file reversed, no probe that mutates a device. At every point where a bank would happen, print exactly what would have been written, and carry on. It exists so the session's shape can be tested against a live map without touching it — a test run that quietly closes four grilling tickets is the worst outcome this mode has.

`--stage <n>` starts at 1 (ratify), 2 (grill), or 3 (bench). Stages before it are summarised in a line each so the context is still there, and any decision they'd have produced is treated as unratified rather than assumed.

## Stage 0 — Gather, quietly

`bash scripts/answers.sh <map>` for each ticket's frontier and any comments already posted — including the human's **report-backs on "Needs a human" checklist tickets**, which it lists alongside the frontiers; the map body for standing constraints, `## Done when`, `## Decisions so far` and `## Lead's review queue`; `bench/<map>/RUN.md` for the probe inventory. A **NOTES FETCH FAILED** line means that ticket's answers are *unknown*, not absent — re-run before treating it as empty. Answers already given in a browser count as given — the session only asks what is still open.

Open with one short orientation: how many decisions in how many groups, how many open questions, how many probes, how many checklist report-backs, and roughly how long. Then go straight into stage 1. No other preamble.

## Stage 1 — Ratify the run's calls

**The arrival condition comes before everything.** If the map has no `## Done when`, the session's first card asks the human to state one — every "needed", "moot" and "close it" judgement downstream is made against it, and taking those judgements first means taking them against nothing. If a run posted an *inferred* one, ratifying or amending it is the first card instead, always alone, never grouped.

These come first because they are the premises everything else stands on: a decline here changes which questions stage 2 even asks.

**Group** calls that share a premise, a subsystem, or a fate — where approving them together is coherent and rejecting one would undermine the others. **Split** anything that could sensibly go the other way on its own. Always individual, never grouped: a call that **amends a standing constraint**, a call that is **irreversible or expensive to unwind**, and anything the run flagged **medium confidence**.

Present each group as its own approve/decline (grouping rules and the card format in [PLAYBOOK.md](PLAYBOOK.md) and [TEMPLATES.md](TEMPLATES.md)). Offer *split this group* as a third option — a group is the agent's guess at coherence, and they may not agree with it. **One group per turn, and the picker stands alone.** The card — every call in words, why, what reversing costs, what approving commits — prints in the same turn, but the picker never relies on it: on a phone the picker is a modal **over** the transcript, and everything printed "directly above" is invisible behind it. So the question text itself carries the premise and every call, numbered, one clause each, and the option descriptions carry the stakes — written as if they are the only thing the human will see, because on the phone they are. A group whose calls can't each be said in one clause inside the question is too big to be one group. Never put two groups in one `AskUserQuestion`: tabs render every question line and none of the context. Keep issuing turns until the queue is empty — the last group gets a card and a picker like the first.

Apply on the spot. A declined call is **reversed now**, and every stage-2 question that rested on it is re-derived before it is asked.

## Stage 2 — The grilling frontier, one question at a time

Order by **dependency** first — questions whose answers prune others go first — then by **blast radius**, then keep questions sharing a premise adjacent so they stay in one context. Order across tickets, not ticket by ticket, whenever a dependency crosses.

Ask **one question per turn**, in the card format, with the run's recommendation visible. Batch only if they ask for it.

**A question a probe can settle is not asked here.** Offer it to the bench and recommend deferring — guessing at a fact from the armchair wastes the probe that was built to get it.

After every answer, re-derive what is left and **say what changed**: questions the answer just settled, made moot, or unlocked. Pruning as it goes is the entire reason for asking one at a time. Bank each ticket's answers when its questions are done.

## Stage 2.5 — Reconcile the bench

Before a single probe runs, state what stage 2 did to the kit. Four classes — **moot**, **re-mapped**, **contradicted**, **missing** — defined in [PLAYBOOK.md](PLAYBOOK.md). Discuss each and let them decide. **Never silently drop a probe**: a probe that looks moot may be the only check on the answer that made it moot.

## Stage 3 — The bench, guided

One probe at a time, in `RUN.md`'s device order so hardware is picked up once. For each: the precondition, the one command, what a good result looks like, and what each outcome implies.

Two ways to get a result, and **ask which**: they run it and paste, or — read-only probe, device the session can reach — the agent runs it and reads the logs itself. Physical gestures are always theirs. The hardware bans from run mode still hold: no install, flash, or reboot without them saying so. Before the agent's first touch of any device, claim its lease (`scripts/device-lease.sh claim <serial> <map>`) — another map's session may be at the same bench. A refused lease names the holder; say so and let the human decide: defer the probe, or run it themselves (their hands aren't leased — the lease governs agents, not people). Release every lease when the bench stage ends.

A `VERDICT:` line settles its question immediately; say so and move on. A `PRECONDITION:` line is **not** an answer — it means the probe never ran. If a verdict contradicts an answer from stage 2, stop and say so plainly; the evidence outranks the armchair.

**The bench includes the checklist tickets.** Every "Needs a human" task in the inventory gets its turn here: if a report-back is already posted, read it against the ticket's **Report back:** list, confirm nothing is missing, close the ticket and read the state back. If none is posted, walk them through the checklist now — this session *is* the human hand the ticket was waiting for — or record it as explicitly deferred. A checklist ticket leaving this stage is closed, mid-checklist with what's missing named, or deferred by their word; never silently carried.

## Stage 4 — Apply and report

Most of it is already banked. Finish the map body, close what is fully answered, post round n+1 frontiers for what is not, wire new tickets, unblock dependents, graduate fog. **A close folds first**: whatever on the ticket the map will still need — facts, ratified calls, artifact links — goes into the map body before the state flips, so nothing durable lives only inside a closed ticket. A ticket with a **deferred** question does not close — deferral is an open state, and a closed ticket has no next frontier to carry it; it stays open with the round n+1 frontier naming what's deferred.

Anything the session built — an inline probe, a rewritten verdict mapping — is committed to the bench branch and pushed; the session ends with the tree clean and every device lease released, same as a run.

**The landing MR is part of the arrival.** Say where it stands — what's folded in, what a conflict kept out — and offer the review now or later: walk the diff in this session, or leave the MR for them to review in the tracker. Either way it lands only after they've been through it, and the merge is theirs; a session never un-drafts or merges the landing MR, however settled the map looks.

**Then score the arrival.** Walk `## Done when` item by item: met, decided but unbuilt, undecided. If anything is decided-but-unbuilt and the Notes don't authorize building, ask now — the human is in the room: one picker, "the map is fully decided on <items> — authorize the build?" On yes, the lead amends Notes to say so and promotes or files the build tickets; the next run sweeps them. If **every** item is met, propose closing the map itself — same picker, their call. Report leads with the arrival score and the net, then everything else; if anything is now TAKEABLE, offer `/wayfinder-afk <map>` rather than sweeping here.

## Standing rules

1. **Never guess.** Unread is a legitimate outcome, re-asked plainly next round. A fabricated answer is not.
2. **Never dump.** One decision group, one question, or one probe at a time. The session is a conversation.
3. **Every choice goes through the picker — including the last one — and every picker stands alone.** Groups, questions, probe modes: each is its own `AskUserQuestion`, one per turn until the queue is empty, its context printed in the same turn *and* restated inside the picker's own fields — on a phone the picker covers the transcript, and context that lives only behind it was never shown. Nothing the human is meant to decide is left as a paragraph they have to answer by hand. Unclicked is unanswered, and a tail of calls applied because nobody objected is not a ratification.
4. **Their words outrank the recommendation.** Answered against the run's advice? Apply it and drop the argument.
5. **Bank at every boundary** — unless `--dry-run`, which never writes anything anywhere. A session that dies loses only the questions not yet asked.
6. **Prose beats shorthand.** `B, but only above API 30` is B *plus a constraint*, and the constraint is the valuable half.
7. **Authorship is not a signal** — the agent posts under the same token as the human. Every comment carries `<!-- wayfinder:agent -->`.
8. **Close only what they answered.** Grilling tickets are HITL; their answer is the only thing that closes one.
9. **Deferred is not dropped**, and **only the lead writes the map body**. Re-running collects only what is new.

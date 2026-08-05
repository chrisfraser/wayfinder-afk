# Playbook

## The decision test

Applied to every question a ticket raises, the moment it raises it. There is no third branch — a question is either taken or escalated, and either way the run continues.

**Take the call** when *all* hold:

- The answer follows from facts you found or constraints already on the map.
- It is reversible, or cheap to revisit before anything is built on it.
- No preference, price, risk appetite, or schedule trade-off is in it.
- It commits nothing outside the repo — no money, no account, no other team, nothing published.

**Escalate** when *any* holds:

- Irreversible, or expensive to unwind once code lands on it.
- It trades off things only the lead prices: scope vs. schedule, risk appetite, cost, who maintains it.
- It amends or contradicts a standing constraint on the map.
- It needs hardware, credentials, or an account the run doesn't have.
- Two answers are defensible and the evidence doesn't separate them. *Say which way you lean and why the evidence stops short — a leaning escalation is worth far more than a bare question.*

Escalating never stops the run. Write it to the map's review queue, note it on the ticket, take the next ticket. If it blocks a ticket outright, say so on that ticket and leave the ticket open and unclaimed.

Every taken call carries, on the ticket and in one line on the map: the call, confidence (high/medium), the evidence, **what would falsify it**, and **what reversing it costs**. Medium-confidence calls are still taken — flagged, not withheld.

## The intake check

The first thing done to any ticket, before any work on it — and often the whole of it. A ticket is a claim about the world, made when it was written. Both halves of that claim expire.

**1. Is it already complete?**

- The ticket's own comments — a previous run may have posted a resolution and failed to close. The frontier script's **COMPLETE BUT OPEN** section finds these, but read the comments anyway: yours may be the round that stranded one.
- `## Decisions so far` on the map — the call may already have been taken, by an earlier round or by the human.
- Tickets closed since this one was written — one answer often settles two questions.
- For a `task`, the repo itself: the change may already exist, on a branch or in `main`.

If it is done: post a short comment naming where it was settled, close it, read the state back, and report `closed (already complete: <where>)`. Re-doing the work is not thoroughness — it produces a second answer for the map to reconcile against the first.

**2. If not, has the path to completeness changed?** The ticket was specified against a world that has since moved:

- A **standing constraint amended** on the map — the ticket may now ask for something ruled out.
- A **decision in `## Decisions so far`** that changes the approach, or removes the need for it.
- A **blocker that closed with an answer**, not merely closed. Unblocking is not the same as leaving the work unchanged: read what the blocker actually concluded before assuming the ticket survived it intact.
- **Another open ticket** that now covers part of this one.
- **The code moved** — the file, API or module the ticket names may no longer exist in that shape.

**3. Does the destination still need it?** Read the map's `## Done when`. If finishing this ticket would move no item on it, and nothing on the map is blocked by it, the ticket is effort the map doesn't need — the most expensive waste there is, because it is done *well* and buys nothing. A ticket can be perfectly live by tests 1 and 2 and still fail this one. (No `## Done when` on the map yet? Skip this test and say so — necessity can't be judged against a destination nobody has stated.)

Then take one of five branches, and name which in your report:

- **Proceed** — the premise holds and the destination needs it. The common case; say so in one line and get on with it.
- **Proceed narrowed** — part is already settled. Do the rest; say what you dropped and why.
- **Re-scope** — the premise is void. Do **not** do the work as written. Post what changed and what the ticket should now ask, then **un-assign yourself** (`glab issue update <iid> --unassign`) and report it. A re-scoped ticket is a result, not a failure.
- **Close as overtaken** — events have left nothing to do. Post why, close, verify.
- **Close as not needed** — the destination stands without it. Post why (TEMPLATES.md), close, verify, and report it so the lead flags the closure for ratification — pruning wrongly is cheap to reverse, but only if it was said out loud. If you're not sure, that's an escalation with a leaning, not a close.

**Un-assigning is not optional on any branch that leaves the ticket open.** You claimed it at step 1. A ticket left open *and* assigned sits in CLAIMED, which no later round retakes — so a re-scoped ticket you stay assigned to is a ticket nobody will ever pick up. The same applies to a `task` handed to the human: post the checklist, then un-assign, or it is invisible to them too.

Intake is minutes, not a phase, and it never becomes a reason to stall: every branch ends in an action taken this round. The standing rule still holds — decide or escalate, never wait.

## The ticket test

Applied before filing anything, by every subagent and by the lead. Closing work is the job. Filing is the exception, and it has to earn itself — **the default is don't file**.

**File a new ticket** only when *all* hold:

- Someone who wasn't in this run could take it cold, from the body alone.
- It blocks something on this map, or the destination cannot be reached without it.
- It cannot be answered inside the ticket you are already holding, at the cost of finishing that ticket.
- No open ticket on this map already covers it.

**Otherwise**, in this order:

1. **Answer it now.** A question you could settle with ten more minutes of the ticket already in your hands is not a new ticket — it is the rest of the one you took.
2. **Fold it into an open frontier.** Anything needing the human becomes a numbered question on an existing `grilling` ticket for that area, never a new ticket. Frontiers are built to carry many questions; the round costs nothing extra to answer.
3. **Write it as fog.** Something you now know you don't know, but cannot yet specify, is a line of fog on the map. Fog is free. A ticket is not.

The asymmetry that makes this matter: a run **resolves** only `research` and `task`. Every `grilling` or `prototype` ticket it files waits for the human to sit down — retired early only if events overtake every question on it, which is nothing to plan on. Filing one to record a thought is exactly how a map silts up, and the cost lands on the person the skill exists to protect.

"None" is a good answer. Reaching for a ticket to fill a report field is not.

## Subagent brief — AFK ticket (`research` / `task`)

Give each subagent everything it needs to run without asking; it cannot see this conversation.

```
Ticket: #<iid> — <title> (<url>)
Map: #<map> — <map title>. Destination: <one line>.
Done when: <the map's arrival items verbatim, or "none defined — necessity test suspended">
Standing constraints (do NOT relitigate): <digest of the map's constraints that bear on this ticket>
Tracker: read docs/agents/issue-tracker.md for the exact CLI.

1. Claim it FIRST: assign the ticket to the map's dev (`--assignee <user>`), before any work.
2. Read the full ticket body and any ticket it names.
3. **INTAKE CHECK (PLAYBOOK.md) — before any work.** Is this already complete? If not,
   has anything changed the path to completeness: an amended constraint, a decision
   taken since, a blocker that closed *with an answer*, another ticket that now covers
   part of it, code that moved? And does the Done-when above still need it at all?
   Take one of the five branches — proceed, proceed narrowed, re-scope, close as
   overtaken, close as not needed — and name it in your report. The cheapest ticket
   is the one already done; the most expensive is the one done well against a premise
   that expired, or for a destination that stopped needing it.
4. Resolve it. Research: primary sources only — source, AIDL, official docs, the code
   itself — never a secondary write-up. Task: do the work; if it needs hardware,
   credentials, money, or a human hand, STOP and produce a checklist instead.
5. Apply the decision test (PLAYBOOK.md) to every sub-question. Take what you can
   defend; escalate the rest into your report. Never stall. Apply the ticket test
   before proposing ANY new ticket — answer it here, fold it into a frontier, or
   make it fog, in that order, and file only what survives all four conditions.
6. Post a resolution comment (TEMPLATES.md), then close the ticket — and then PROVE
   it closed: re-read the ticket and confirm `state == "closed"`. `glab issue close`
   can fail and say little. Do not report a ticket closed on the strength of having
   run the command; report it closed because you read back "closed". If it will not
   close, say so in your report as the FIRST line — a resolved ticket left open is
   worse than an unresolved one, because it looks finished to everyone but the map.
   Task tickets that need a human: post the checklist, leave OPEN, do not close — and
   **un-assign yourself**, or it stays in CLAIMED and neither a later round nor the
   human will see it as available.
7. Files go on a branch: `git switch -c wayfinder/<map>-<iid>-<slug>`, commit there, name
   the branch on the ticket. NEVER push, merge, or commit to main — a run that dies
   mid-way must strand nothing and touch nothing shared. Branch off the ORIGINAL HEAD,
   not whatever HEAD happens to be — in a shared worktree it may have moved under you.
   Leave the tree clean: commit everything you mean to keep, delete everything you
   don't. A file you leave uncommitted dies with the worktree and appears in no report.
8. Do NOT edit the map body. Do NOT close a grilling or prototype ticket.

Report back, in this order:
- **intake** — `proceed` | `proceed narrowed: <what you dropped>` | `re-scoped: <what
  changed>` | `already complete: <where it was settled>` | `overtaken: <by what>` |
  `not needed: <which Done-when items it fails to serve>`.
- **disposition** — `closed (state read back as closed)` | `left open: <why>` |
  `RESOLVED BUT WOULD NOT CLOSE: <what the close did>`. Never omit this line, and
  never write "closed" from having run the command rather than having read the state.
- one-line gist of the answer (this becomes the map's Decisions-so-far entry)
- calls you took, each with confidence + reversal cost
- escalations for the lead, each with your leaning
- questions for the human this raised — to be folded into an existing frontier as
  numbered questions. This is the default home for anything needing a decision.
- new tickets, ONLY those passing the ticket test in PLAYBOOK.md: title, type, body,
  what blocks them. Most tickets should yield none — "none" is the expected answer,
  and is worth more than one filed to fill this line.
- fog cleared or newly visible — the home for what you now know you don't know
- anything that invalidates another ticket on this map
```

## Subagent brief — grilling / prototype prep

```
Ticket: #<iid> — <title> (<url>)  [DO NOT RESOLVE, DO NOT CLOSE, DO NOT ASSIGN]
Map: #<map>. Destination: <one line>. Standing constraints: <digest>
Already decided this run: <the calls taken in phase 1 that bear on this ticket>
Questions already owned by another ticket: <list> — cross-reference, don't re-ask.

INTAKE FIRST (PLAYBOOK.md): before investigating, check whether these questions are
still live. A question already answered by a decision taken since this ticket was
written, or by a blocker that closed with an answer, must NOT reach the frontier —
drop it and say so. Same for a question the map's Done-when no longer needs asked.
The human's session is the scarcest thing this skill spends; asking them something
already settled spends it twice. If EVERY question is dead — overtaken, settled, or
not needed — post no frontier: post what you found instead (each question and what
killed it, plus any fact worth keeping) and say so in your report. The LEAD then
folds the durable parts into the map, closes the ticket, and flags the closure for
ratification. You do not close it yourself.

If this is a `prototype` ticket, BUILD FIRST: make the cheap, rough artifact the
ticket asks for (outline, stub, UI/logic sketch — the /prototype skill), commit it
to `wayfinder/<map>-<iid>-<slug>`, link it from the ticket, and pitch the frontier
as "react to this". Rough is the point; do not polish, do not push, do not close.

Investigate to the exact point where the human's judgement is genuinely needed —
read the code, the AIDL, the docs, the adjacent tickets; establish every fact so
they never spend an answer on a lookup. Then post ONE frontier comment in the
TEMPLATES.md format:
  - Decisions taken (high confidence) — for ratification, each with reversal cost
  - Facts established — settled, not up for answering
  - Numbered questions — as many as the ticket honestly carries. Each: why it
    matters, the options, your recommendation, what it unblocks. All independently
    answerable in one sitting, in any order.
  - Later rounds — questions that depend on an answer above
  - Thinnest evidence — where you'd want to be challenged

Never answer a question on the human's behalf in the frontier list itself. A
recommendation is not an answer.

Report back: the question count, the decisions you took, and any question you
believe belongs to a different ticket on this map.
```

## Bench kit — the probe contract

### The cost ladder

Take the **lowest rung that actually answers the question**. Go up only when the rung below physically cannot, and say why in the probe's header.

1. **A one-liner in `RUN.md`** — `adb shell dumpsys …`, a `getprop`, a `pm list`. No file, no build. Most questions stop here.
2. **A shell probe** — `bench/<map>/probe-<slug>.sh`. Anything needing several commands, a comparison, or a parse.
3. **A test in a module that already exists** — when the answer needs the app's classpath but not its identity. Nothing new to install.
4. **A throwaway bench app** — only when the answer needs *the app's own uid*, a real bound service, a permission held in a real manifest, or a gesture on a real screen.

### Every probe

- Settles **exactly one** named question or blocked ticket. Two answers in one probe and the human can't act on half of it.
- Runs from **one command**, with no arguments to work out and nothing to edit first.
- Prints its evidence, then one final line: `VERDICT: <what it found> => #<iid> Q<n> = <option>`. **Mapping the result onto the frontier's own options is the whole point** — the human should never have to interpret raw output.
- **Fails loudly on a missing precondition** — `no device on :5555`, `needs API >= 30, found 28` — and never silently prints nothing. Absence of output must not be readable as an answer.
- Carries the full header from TEMPLATES.md — read-only vs mutating (with the exact undo), and `# Gesture: yes|no`. `run-all.sh` skips the gesture probes by grepping that line, so a mislabelled probe blocks the batch run waiting for a hand that isn't there.
- Names a **precondition failure** as such: print `PRECONDITION: <what's missing>` and exit non-zero, so it can never be mistaken for a verdict.
- Is **proven to build or parse before handover**, asserted on a positive signal — and if your shell filters command output, bypass the filter so a failure can't be swallowed. `bash -n` for a shell probe is the floor.
- Says what it **can't** distinguish. A probe that silently conflates two options is worse than the open question.

### Bench apps

- **One screen.** One control per question, result in large text on-screen *and* to logcat under one greppable tag — a screenshot and a paste should both be enough to answer.
- It is driven **on the target hardware**, so it inherits that hardware's input and screen constraints. Check them before designing the screen; on this repo's radios that means 240×320, D-pad only, no touch, visible focus, controls stacked vertically.
- Its own package id with a `-bench` suffix — never a flavour of the product, never sharing its id. Debug-signed, one `adb install -r`, no configuration step.
- Ship the install command in `RUN.md`. The run builds the APK; the run never installs it.
- If it can't be built without the product's signing config or a privileged uid, say so and drop back to a rung that can.

### Hardware bans during the run

Build probes; don't drive the user's kit with them. A **read-only** self-test on a device the run explicitly owns is fine. Never install, flash, factory-reset, or **reboot** — a reboot ended Wi-Fi ADB permanently on a radio with an empty `persist.adb.tcp.port` and stranded it for the rest of the run. If a probe can only be validated by running it, hand it over unvalidated and say so.

### Sharing the bench between runs

Two AFK sessions on different maps may reach for the same devices, so "owns" is established by **lease**, never by assumption: `scripts/device-lease.sh claim <serial> <map>` before the first command reaches a device, `release <serial> <map>` at handover, re-claim to renew. Leases expire (default 60 min) so a dead run can't hold a radio forever — a run at the bench longer than that renews as it goes. The **lead** claims and releases; subagents inherit the serial through their brief and never manage leases themselves — one owner per resource, same as the map body. A refused claim prints which map holds the device: that probe is handed over `compiled only, never run`, the report says which map had the hardware, and nobody waits — busy is an answer, and breaking a live lease is driving a radio someone else is mid-conversation with. Leases are host-local (`~/.wayfinder/leases`, override `WAYFINDER_LEASE_DIR`) because the hardware is host-attached; a bench shared across machines needs a tracker-side convention this script doesn't pretend to cover.

## Subagent brief — probe / bench app

```
Question: #<iid> Q<n> — <the question, verbatim as posted>
Map: #<map>. Options on the table: <A / B / C, verbatim>.
Owns hardware: <device, or none — the lead holds its lease>. Must not touch: <devices>.
Must not run: reboot, install, flash, factory reset. Never claim or release a lease
yourself — the lead does; if the device refuses you anyway, report it, don't retry.

Build the smallest artifact that turns this question into a one-command verdict for a
human at the bench. Cost ladder and probe contract: PLAYBOOK.md — take the lowest rung
that answers it, and justify going higher in the header.

Everything lands in bench/<map>/ on branch wayfinder/<map>-bench-<slug>. Header format
and the RUN.md entry you must supply: TEMPLATES.md.

Prove it builds or parses (assert on a positive signal, never on absence of errors, and
bypass any output filter). Run it ONLY if you own a device and the probe is read-only.

Report back:
- path + the exact one command
- what a good result looks like, and which option each outcome implies
- what it cannot distinguish
- validated on hardware, or compiled only
- the RUN.md entry, ready to paste
```

## Ordering and concurrency

- **Phase 1 order** doesn't matter much — they're parallel. Prefer tickets that unblock the most others when the concurrency cap bites.
- **Phase 2 order**: descending by tickets unblocked, then ascending by id. A grilling ticket blocked only by another grilling ticket is still prepped — its frontier states the assumption ("assumes #295 lands as recommended").
- **Cap ~6 concurrent subagents.** More than that and tracker writes start colliding and the round's results stop fitting in one head.
- **One writer for the map body.** Subagents never touch it. The lead applies each round's results in a single edit.
- Re-read the map body immediately before editing it — another session may be working the same map.
- **Any subagent that writes files gets `isolation: "worktree"`.** Observed failure without it: parallel agents each ran `git switch -c … ` off "current HEAD" in the same worktree, so their branches chained off one another instead of off the starting commit, one agent declined to commit at all rather than corrupt a peer's tree, and the run ended parked on a research branch. Read-only agents — grilling and prototype prep that only post comments — do not need it and shouldn't pay for it.
- **The bench kit is one directory with many writers.** Give each probe agent `isolation: "worktree"` and its own branch `wayfinder/<map>-bench-<slug>`; the lead merges them into `wayfinder/<map>-bench`. The lead writes `RUN.md` **last**, once it knows the full set — it has a single author for the same reason the map body does.
- **Hardware is a shared, mutable resource, so assign it explicitly — at both grains.** Across runs, the lead holds the **lease** for every device its agents are told they own (sharing the bench, above); within the run, name in each brief which device that agent owns and which it must not touch, or two agents will drive the same radio. Say what must not be run at all: a reboot can end an ADB session permanently and strand the device mid-run.

## Loop guards

Stop the phase-1 loop when any of: no TAKEABLE research/task ticket remains; a round closes nothing new (fixpoint); **two consecutive rounds end net-positive**; 4 rounds have run. Say which fired. New tickets created during a round are candidates for the *next* round, not this one.

**The net guard.** Count every round: closed, filed, net. A round that files more than it closes makes the next round **closing-only** — it may file nothing, and candidates wait in `## Candidate tickets` on the map body until a round runs net-negative again. This exists because the other three guards are blind to inflation: new tickets defer to the next round, so filing work *postpones* the "no TAKEABLE remains" stop, and a round closing 3 while opening 9 satisfies every other condition. A map that grows two rounds running is a finding — report it as one.

## Tracker crib (GitLab / `glab`)

`docs/agents/issue-tracker.md` is authoritative. Specifics that bite:

- `glab` prints a multi-config warning **on stdout** — strip to the first `[`/`{` before parsing JSON. Use `--output json`; `-F` is output-*format*, not JSON.
- **`glab issue list --all` is all *states*, not all *pages*.** Pagination is `-p/--page`, and one call returns at most `--per-page` rows. Any hand-rolled query over a label with more than 100 tickets comes back short **and says nothing about it** — page until a page returns fewer rows than you asked for. `map-frontier.sh` does this for you; prefer it to your own query.
- Claim: `glab issue update <iid> --assignee <user>`. Release: `glab issue update <iid> --unassign` — required on every branch that leaves a ticket open, since CLAIMED is never retaken. Comment: `glab issue note <iid> --message "..."` (heredoc for multi-line).
- Close: comment first, then `glab issue close <iid>` — close takes no message. **Then read the state back**: `glab issue view <iid> --output json | jq -r .state` must print `closed`. The command's silence is not proof; this is the positive signal invariant 7 asks for, applied to the one action the whole sweep is measured by.
- **File: `glab issue create --title "<title>" --label "wayfinder:<type>" --description "<body>"`** — `<type>` is exactly one of `research`, `task`, `grilling`, `prototype`. Body from the new-ticket template in TEMPLATES.md.
- Children are found by their `Part of: … (#<map>)` body pointer; blocking by a `## Blocked by` list of links in the body. Both are what `scripts/map-frontier.sh` parses.
- **A ticket filed without its `wayfinder:<type>` label does not exist.** `map-frontier.sh` builds the frontier by *querying those four labels* — an unlabelled ticket is in no bucket, is never swept, never blocks anything, and never appears in a handover. Same for a missing `Part of:` pointer: correctly labelled, but attached to no map.
- `map-frontier.sh` also prints a **COVERAGE** line, and it governs whether the buckets can be trusted at all: `complete` (every label query read to exhaustion), `TRUNCATED` (hit the `PAGE_CAP` page cap, default 50 pages = 5000 tickets per label — re-run with `PAGE_CAP` higher), or `QUERY FAILED`. On either of the latter two the missing tickets are absent from **every** bucket, so a short read looks exactly like a small map. Don't sweep on a frontier that isn't `complete`.
- **COMPLETE BUT OPEN** is the section to read first, every round. It lists open tickets that already carry a resolution comment — work that was done and never closed. These are free closes, and they do not surface any other way: the subagent claimed the ticket before starting, so a failed close leaves it in CLAIMED, which no round retakes. Same three outcomes as below, and `CHECK INCOMPLETE` is not `none`. A ticket holding a "Needs a human — checklist", or whose latest word is a frontier awaiting answers, is deliberately open and is never flagged.
- `map-frontier.sh` catches the first case itself: its **UNLABELLED** section lists open issues pointing at this map that carry no `wayfinder:*` label. Read it every round and fix what it names (`glab issue update <iid> --label "wayfinder:<type>"`) before taking anything. It reports one of three things and they are not interchangeable — a list, `none, across <n> ... scanned`, or `SCAN FAILED`. **`SCAN FAILED` is not "none"**; it means the check didn't run and orphans are still possible. The scan covers open issues only, newest first, capped at `ORPHAN_MAX` (default 500) — raise it on a big project.
- The script's other sections each demand something: **STALE CLAIM** (handed off but still assigned — `--unassign`); **CLAIMED, NO RESOLUTION** (claimed, nothing posted: a live run or a dead one — must name nothing this round claimed by round's end); **LOOSE POINTER** (labelled, mentions the map, `Part of:` doesn't parse — fix the body, the ticket is in no bucket); **BLOCKER LOOKUP FAILED** (blocker unreadable, treated as open — its dependents stay BLOCKED until verified by hand).
- Push — **lead only, at handover**: `git push -u origin wayfinder/<branch>` for every branch the run created. Never `main`, never a merge into anything shared.
- Draft MR — **lead only, at handover, and only for work meant to land**: `glab mr create --draft --source-branch wayfinder/<branch> --target-branch main --title "<title>" --description "<body>"`. Creating the MR is not merging it — the merge stays the human's. Bench and prototype branches get no MR; pushed is their terminal state.
- Hardware lease — **lead only**: `bash scripts/device-lease.sh claim <serial> <map>` before any device is touched, `release <serial> <map>` at handover, `list` to see the bench. Exit 3 = held by another map: report it, hand the probe over unvalidated, move on.
- When a blocker closes, strike it through in the blocked ticket's `## Blocked by` list rather than deleting it, and say what changed.
- Anything whose *failure* must be seen — builds, tests — is asserted on a positive signal (`BUILD SUCCESSFUL`, a parsed result file), never on the absence of errors, and is run with any output filter bypassed (`rtk proxy <cmd>`, if that's the filter).

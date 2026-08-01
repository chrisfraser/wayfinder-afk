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

## Subagent brief — AFK ticket (`research` / `task`)

Give each subagent everything it needs to run without asking; it cannot see this conversation.

```
Ticket: #<iid> — <title> (<url>)
Map: #<map> — <map title>. Destination: <one line>.
Standing constraints (do NOT relitigate): <digest of the map's constraints that bear on this ticket>
Tracker: read docs/agents/issue-tracker.md for the exact CLI.

1. Claim it FIRST: assign the ticket to the map's dev (`--assignee <user>`), before any work.
2. Read the full ticket body and any ticket it names.
3. Resolve it. Research: primary sources only — source, AIDL, official docs, the code
   itself — never a secondary write-up. Task: do the work; if it needs hardware,
   credentials, money, or a human hand, STOP and produce a checklist instead.
4. Apply the decision test (PLAYBOOK.md) to every sub-question. Take what you can
   defend; escalate the rest into your report. Never stall.
5. Post a resolution comment (TEMPLATES.md), then close the ticket. Task tickets that
   need a human: post the checklist, leave OPEN, do not close.
6. Files go on a branch: `git switch -c wayfinder/<map>-<iid>-<slug>`, commit there, name
   the branch on the ticket. NEVER push, merge, or commit to main — a run that dies
   mid-way must strand nothing and touch nothing shared. Branch off the ORIGINAL HEAD,
   not whatever HEAD happens to be — in a shared worktree it may have moved under you.
7. Do NOT edit the map body. Do NOT close a grilling or prototype ticket.

Report back, in this order:
- one-line gist of the answer (this becomes the map's Decisions-so-far entry)
- calls you took, each with confidence + reversal cost
- escalations for the lead, each with your leaning
- new tickets the answer makes specifiable: title, type, body, what blocks them
- fog cleared or newly visible
- anything that invalidates another ticket on this map
```

## Subagent brief — grilling / prototype prep

```
Ticket: #<iid> — <title> (<url>)  [DO NOT RESOLVE, DO NOT CLOSE, DO NOT ASSIGN]
Map: #<map>. Destination: <one line>. Standing constraints: <digest>
Already decided this run: <the calls taken in phase 1 that bear on this ticket>
Questions already owned by another ticket: <list> — cross-reference, don't re-ask.

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

## Subagent brief — probe / bench app

```
Question: #<iid> Q<n> — <the question, verbatim as posted>
Map: #<map>. Options on the table: <A / B / C, verbatim>.
Owns hardware: <device, or none>. Must not touch: <devices>.
Must not run: reboot, install, flash, factory reset.

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
- **Hardware is a shared, mutable resource, so assign it explicitly.** Name in each brief which device that agent owns and which it must not touch, or two agents will drive the same radio. Say what must not be run at all: a reboot can end an ADB session permanently and strand the device mid-run.

## Loop guards

Stop the phase-1 loop when any of: no TAKEABLE research/task ticket remains; a round closes nothing new (fixpoint); 4 rounds have run. Say which fired. New tickets created during a round are candidates for the *next* round, not this one.

## Tracker crib (GitLab / `glab`)

`docs/agents/issue-tracker.md` is authoritative. Specifics that bite:

- `glab` prints a multi-config warning **on stdout** — strip to the first `[`/`{` before parsing JSON. Use `--output json`; `-F` is output-*format*, not JSON.
- Claim: `glab issue update <iid> --assignee <user>`. Comment: `glab issue note <iid> --message "..."` (heredoc for multi-line).
- Close: comment first, then `glab issue close <iid>` — close takes no message.
- Children are found by their `Part of: … (#<map>)` body pointer; blocking by a `## Blocked by` list of links in the body. Both are what `scripts/map-frontier.sh` parses.
- When a blocker closes, strike it through in the blocked ticket's `## Blocked by` list rather than deleting it, and say what changed.
- Anything whose *failure* must be seen — builds, tests — is asserted on a positive signal (`BUILD SUCCESSFUL`, a parsed result file), never on the absence of errors, and is run with any output filter bypassed (`rtk proxy <cmd>`, if that's the filter).

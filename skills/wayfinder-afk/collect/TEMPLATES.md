# Templates

Two halves: what the human **sees in the session**, and what gets **written to the tracker**. The first half is the point of this skill — get the conversation's shape right and the writes follow.

Every comment posted ends with `<!-- wayfinder:agent -->`.

---

# In the session

## Opening — one screen, then straight into stage 1

```
Map #<map> — <destination in one clause>.

  <n> calls the run took, in <m> groups          → ratify first
  <n> open questions across <n> tickets           → <n> need judgement, <n> have a probe
  <n> probes at the bench, ~<n> min, <n> device(s)
  <n> checklist ticket(s)                         → <n> report-back(s) waiting to be read

Starting with the calls — they're the premises everything else rests on.
<or, if the map has no `## Done when`: Starting with the arrival condition — the map doesn't say when it's done, and everything below is judged against that.>
```

No summary of the run, no recap of the map. If they want it, they'll ask.

Under `--dry-run`, say so on this screen and nowhere else — one line, then behave identically:

```
DRY RUN — nothing will be written to the tracker, the map, or any device.
```

At each point a bank would occur, show the write instead of making it:

```
[dry run] would post to #<iid>: Settled — round 1 (<n> answers, <n> ratified)
[dry run] would close #<iid>
[dry run] would edit map body: +<n> decisions, −<n> queue entries
```

## Stage 1 — a decision group

One card, then the approve/decline. Name the shared premise in the first line — if it can't be named, it isn't a group.

```
### Group <n> of <m> — <the shared premise, one clause>

- **<the call>** — <one line of why>. Reverse by: <cost>.
- **<the call>** — <one line of why>. Reverse by: <cost>.

Approving commits: <what becomes standing, and what gets built on it>
Declining costs: <what has to be redone or re-asked>
<Confidence, if any member is medium. Say which.>
```

Then `AskUserQuestion` — one question per group, up to four groups per round:

- **header**: `Group <n>` (≤12 chars)
- **question**: `<the shared premise> — approve these <n> calls?`
- **options**: `Approve all <n> (Recommended)` · `Decline all <n>` · `Split — ask individually`

Drop the recommendation marker when the group contains anything medium-confidence. A call that amends a standing constraint is **never** in a group — ask it alone, with the constraint's current text quoted.

**Four is a batch size, not a budget.** Keep issuing rounds of up to four until the queue is empty — `m` groups take `ceil(m / 4)` rounds, and the last round is as much a picker as the first. A split works the same way: its members queue up and go out four at a time.

**Never present an approval as prose.** Every group is decided in the picker — no listing the remainder and asking them to reply in text, no "the rest are straightforward, confirm and I'll apply them", no rolling leftovers into the stage-1 summary. The tail is where this fails: by the last round the answers feel obvious and the pull is to narrate them. A call the human didn't click is **unratified**, and applying it because nobody objected is the same error as answering a grilling question for them.

## Stage 2 — a question

One per turn. The recommendation is visible but never pre-selected.

```
### <ticket name> · Q<n>

**<the question, asked so a short answer works>**

Why it matters: <what changes downstream>
Options: **A** <…> · **B** <…> · **C** <…>
Recommendation: **B** — <why>
Unblocks: #<iid>, #<iid>
<Rests on: <the stage-1 call or earlier answer this assumes>, if it does>
```

**`Q<n>` is the number that question carries on its own ticket's frontier — never a session counter.** It is the human's answer key: they reply `Q3 B` into that frontier comment, and a renumbered question lands the answer on the wrong row. Numbers repeat across tickets, so the **ticket name always rides beside it** — and it is the ticket's *title*, not a bare `#295`. The id travels inside the name's link; it never stands in for it.

**Progress does not belong in this header.** It has exactly one writer — the after-answer block below — and a card that also counts will contradict it the moment a question is pruned.

Then `AskUserQuestion` with the options as given, recommendation first. They can always answer in their own words instead — take the words over the letter.

**After every answer**, before the next question:

```
→ <what their answer settled>
→ Dropped: <question(s) now moot, and why>
→ Unlocked: <question(s) from later rounds now askable>
<n> answered · <n> left
```

The **left** count is recomputed from what is actually still open, *after* this answer's pruning — never `total − asked`. Questions get dropped and unlocked, so the pool moves in both directions and a subtraction goes stale on the first prune. When it did move, say so on the same line rather than letting the number jump silently:

```
17 answered · 41 left — 3 dropped by this answer
```

## Stage 2 — a question a probe can settle

Don't ask it. Offer it:

```
### <ticket name> · Q<n> — there's a probe for this

**<the question>**

`<the one command>` settles it on <device>: <what it prints, and which option each result implies>.
Recommendation: **defer to the bench** — it's a fact, and guessing wastes the probe.
```

Options: `Defer to the bench (Recommended)` · `Decide it now` · `Drop the question`.

## Stage 2.5 — the bench reconciliation

Before anything runs. One table, then discuss the non-obvious ones.

```
### What your answers did to the bench kit

| Probe | Settles | Now | Recommendation |
|---|---|---|---|
| `probe-<slug>.sh` | #<iid> Q<n> | **moot** — Q<n> settled in stage 2 | <run anyway / drop> — <why> |
| `probe-<slug>.sh` | #<iid> Q<n> | **re-mapped** — options changed, verdict line points at an option that no longer exists | rewrite the mapping, then run |
| `probe-<slug>.sh` | #<iid> Q<n> | **contradicted** — your answer says <x>, this measures it | **run it** — it's the only check on that answer |
| — | #<iid> Q<n> | **missing** — your answer raised a fact with no probe | <build inline / file for the next run> |

<n> probes still worth running, ~<n> min.
```

A **moot** probe whose question they answered from judgement — not from evidence — gets a run-anyway recommendation. It is the only thing that can catch a wrong assumption.

## Stage 3 — a probe

```
### <n> of <m> · <device> · <what it settles: #<iid> Q<n>>

Precondition: <what must be true first>
Run: `<the one command>`
Expect: <the shape of a good result>
Means: `VERDICT: <x>` → **A** · `VERDICT: <y>` → **B**
<read-only | MUTATES <what> — undo: `<cmd>`>
```

Then ask how: `You run it, I read the output` · `I run it — read-only, on <device> (Recommended)` · `Watch the logs while you do the gesture` · `Skip this one`.

For the log mode, start the tail **before** telling them to act:

```
Tailing `<the filter>` on <device>. Do <the gesture> when ready — I'll read it live.
```

On a result:

```
→ VERDICT: <verbatim>
→ #<iid> Q<n> = <option>. <One line on what that settles.>
```

A `PRECONDITION:` line means the probe never ran — say so, say what's missing, and leave the question open.

## Session close

```
### Done — map #<map>

Net <±n> — closed <n>, filed <n>. Arrival: <k>/<m> `Done when` items met, <n> decided but unbuilt, <n> undecided.
Ratified <n>, declined <n>. Answered <n>, deferred <n>. Bench: <n> run, <n> skipped, <n> blocked. Checklists: <n> closed, <n> still open.
Closed: <ticket name> · <ticket name>
Round <n+1> posted: <ticket name> (<n> questions)
<Build authorized: <items> — tickets filed, `/wayfinder-afk <map>` sweeps them · or · All Done-when items met — map closed / closure declined: <their words>>
Now takeable: <ticket name> · … → `/wayfinder-afk <map>`
Still on you: <what, and why it couldn't be settled here>
<if the session touched files or hardware: Tree clean, <n> commit(s) pushed to `wayfinder/<map>-bench` · leases released: <serial>>
```

---

# Written to the tracker

## Ticket — the Settled comment

```markdown
## Settled — round <n>

Answered by the lead <date>, in a guided session.

### Decisions

- **D1 <the call>** — **ratified**. Now standing; on the map under Decisions so far.
- **D2 <the call>** — **declined**: <their reason, their words>. Reversal: <what was undone, or the ticket that does it>.

### Answers

- **Q1 <the question>** → **B, <the option in words>**. <Their reasoning.> <Any constraint they attached.>
- **Q4 <the question>** → **B**, from `probe-<slug>.sh`: `VERDICT: <verbatim>`.
- **Q7 <the question>** → **deferred**, carried to round <n+1>.

### What this changes

- Unblocks: #<iid> · New tickets: #<iid> · Amends: <constraint, and how>
- Still open here: <n> question(s) — round <n+1> below.

<!-- wayfinder:agent -->
```

## Ticket — the applied marker

```markdown
<!-- wayfinder-afk: applied round <n>; consumed notes <id>,<id> -->
<!-- wayfinder:agent -->
```

## Ticket — round n+1 frontier

Same shape as run mode's frontier ([../run/TEMPLATES.md](../run/TEMPLATES.md)), with what was carried forward named at the top so nothing looks newly invented.

```markdown
## Frontier — round <n+1>, after your answers

**Answer shorthand:** `D1 ratify · Q1 B`. Numbering restarts each round.

### Carried forward

- <question> — you deferred it in round <n> ("<their words>"). Still open.
- <question> — unlocked by your answer to round <n> Q<n>.

### Questions

**Q1. <question>**
- Why it matters / Options / Recommendation / Settled by / Unblocks

<!-- wayfinder:agent -->
```

## Map — Decisions so far

Ratified calls **move** here; the review-queue entry is deleted, not left behind.

```markdown
- **<the decision, stated so it can be applied without context>** — ratified <date> from [<ticket title>](url). <The constraint they attached.>
- **<the call, and that it was declined>** — declined <date> from [<ticket title>](url): <their reason>. <What was reversed.>
- **Constraint <n>** — ~~<old text>~~ → <new text>. Amended <date> from [<ticket title>](url): <why>.
```

## Map — session report comment

```markdown
## Review session — round <n>

**Net <±n>** — closed <n>, filed <n>. <n> tickets open on this map, was <n>.
**Arrival <k>/<m>** — `Done when`: <k> met · <n> decided but unbuilt · <n> undecided. <Build authorized: <items> | All met — map closed | closure declined: <why>>
**Ratified (<n>) / declined (<n>)** — <the declines, one line each>
**Answered (<n>) · deferred (<n>) · unread (<n>)**
**Bench** — <n> run, <n> moot, <n> blocked: <what and why>
**Checklists** — <n> closed from report-backs, <n> walked live, <n> still open: <what's missing>
**Closed (<n>)** — <ticket name> · <ticket name>
**Round <n+1> posted (<n>)** — <ticket name>: <n> carried, <n> new
**Reversed (<n>)** — <the declined call>: <what was undone>
**Constraints amended (<n>)** — <one line each>
**New tickets (<n>)** — <ticket name> (<type>, blocked by <…>)
**Now takeable (<n>)** — <ticket name> · … → `/wayfinder-afk <map>`

<!-- wayfinder:agent -->
```

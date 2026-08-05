# Templates

Exact shapes to post. Keep the headings — the next run and the frontier script read them.

**Every comment ends with `<!-- wayfinder:agent -->`.** The agent posts under the same token as the human, so authorship distinguishes nothing; collect mode uses this stamp to tell the run's own output from the human's answers. An unstamped comment on a grilling ticket will be read as an answer.

## Resolution comment (closing an AFK ticket)

```markdown
## Answer

<the decision or finding, stated so someone can act on it without re-reading the ticket>

## How it was established

<sources, commands run, files read — enough to re-check without redoing>

## Calls taken

- **<the call>** — confidence <high|medium>. <why>. Falsified by: <what would prove it wrong>. Reversal cost: <cheap|…>.

## For the lead

- <escalation> — leaning: <which way, and why the evidence stops short>

## What this changes

- Unblocks: #<iid>, #<iid>
- New tickets: #<iid> <title>
- Invalidates: <ticket + what about it is now wrong>

<!-- wayfinder:agent -->
```

## New ticket — filing one

Filed with `--label "wayfinder:<type>"` (`research` | `task` | `grilling` | `prototype`). The label and the `Part of:` line are not decoration: `map-frontier.sh` queries the label to find the ticket at all, and reads the pointer to attach it to a map. Miss either and the ticket is filed into a void.

```markdown
Part of: [<map title>](<map url>)

## What this is

<the question or the work, stated so someone can take it cold>

## Why it's separate

<what made it specifiable — the finding that split it out of #<iid>>

## Done when

<the observable result that closes this>

## Blocked by

- [<ticket name>](<url>) — #<iid>
```

Both parsed shapes are exact. The `Part of:` URL must end in `work_items/<map>` or `#<map>` — a link to the map's page is what the regex reads. Each `## Blocked by` row carries a **literal `#<iid>`** alongside the name; the blocker scan reads digits after a `#` and cannot see an id that only exists inside a link target.

Omit `## Blocked by` entirely when nothing blocks it — an empty section reads as unparsed, not as unblocked.

## Task ticket that turned out to need the human

Post this, leave the ticket **open** and **unassigned**. A bare list of steps is the fallback — if the steps can be collapsed into one command, build the probe and lead with it.

```markdown
## Needs a human — checklist

<why the agent can't do it: hardware, credentials, money, physical access>

**One command:** `bash bench/<map>/probe-<slug>.sh` — <what it prints, and what each result means>. <read-only | mutates <what>, undo: <cmd>>. <validated on <device> | compiled only, never run>.

Anything the probe can't cover:

1. <exact step — command, URL, or physical action>
2. <exact step>

**Report back:** <the precise outputs the map needs — the command's output verbatim, the row count, where the credential landed>

Blocks: #<iid>, #<iid>

<!-- wayfinder:agent -->
```

## Grilling ticket — frontier comment

The one the human answers in bulk. Numbering is contiguous across the whole comment so they can reply `D1 yes, Q3 B, Q4 …`.

```markdown
## Frontier — round <n>, prepared unattended

**Answer shorthand:** `D1 ratify · D2 reject <why> · Q1 B · Q2 <your own answer>`. Skip anything you'd rather leave open.

### Decisions taken — ratify or reject

- **D1. <the call>** — confidence <high|medium>. <one-line why>. Reverse by: <cost>.

### Prototype — react to this

<prototype tickets only: what was built, what's deliberately rough, where it is>
Branch `wayfinder/<map>-<iid>-<slug>` · <file or link>

### Facts established — settled, don't spend an answer on these

- <fact> — <source>

### Questions

**Q1. <the question, asked so a one-word answer is possible>**
- Why it matters: <what changes downstream>
- Options: **A** <…> · **B** <…> · **C** <…>
- Recommendation: **B** — <why>
- Settled by: `bench/<map>/probe-<slug>.sh` — <one line: what it prints and which option that implies> — *or* — **judgement, nothing to run**: <why no machine can settle it>
- Unblocks: #<iid>

**Q2. …**

### Bench kit — run these before answering

`bench/<map>/RUN.md`, branch `wayfinder/<map>-bench`. <n> of the questions above have a probe; the rest are judgement.

- `<one command>` — settles Q<n>, Q<n>. <read-only | mutates <what>, undo: <cmd>>. <validated on <device> | compiled only>.

### Later rounds — these depend on the answers above

- <question> (waits on Q1)

### Thinnest evidence

<where this frontier is most likely wrong, and what would settle it>

### Owned elsewhere

- <question> — belongs to #<iid>, asked there

<!-- wayfinder:agent -->
```

Answers come back via `/wayfinder-afk collect <map>`, which reads every comment posted after this one. Any later comment the run itself adds — a supplement, a cross-reference, a correction — **must** carry the stamp, or it will be parsed as the human's answer.

## Map — the review queue

One section on the map body, added by the run, cleared by the lead when they've been through it. It sits after **Decisions so far** and never replaces it: closed tickets still go there.

```markdown
## Lead's review queue

<!-- added by /wayfinder-afk — ratify or reject, then delete the section -->

### Calls taken — ratify or reject

- [<ticket title>](url) — **<the call>**. Confidence <high|medium>. Reverse by: <cost>.

### Blocked on you

- [<ticket title>](url) — **<what's needed>**: <the decision, the hardware, the credential>. <leaning, if there is one>. Probe: `<one command>` — <what it settles> · *or* nothing to run, this is a judgement call.

### At the bench

`bench/<map>/RUN.md` on `wayfinder/<map>-bench` — <n> probes, ~<n> min, ordered so each radio is picked up once.
```

## Map — candidate tickets

Where a proposal goes when it did not pass the ticket test, or when a closing-only round refused it. Nothing is lost; nothing inflates the frontier. The lead promotes from here when a round runs net-negative, and a candidate no one has promoted in two runs should be deleted rather than carried — that is the list doing its job.

```markdown
## Candidate tickets

<!-- proposed, not filed. Promote only in a net-negative round; delete what nobody misses. -->

- **<title>** (<type>) — <one line: what it would be>. Raised by [<ticket name>](url), round <n>. Held because: <which ticket-test condition it failed, or "closing-only round">.
```

## Probe — file header

First lines of every probe, whatever the language. The human reads this before they trust it with a radio.

```sh
# probe: <one line — the question this settles>
# Settles:  #<iid> Q<n>  (map #<map>)
# Needs:    <device + api level | nothing | app X installed>
# Gesture:  no   |   yes — <what the human must physically do while it runs>
# Safety:   read-only  |  MUTATES <what> — undo: <exact command>
# Rung:     <1 one-liner | 2 shell | 3 test | 4 bench app>; lower rung impossible because <why>
# Verdict:  prints "VERDICT: <key>=<value> => #<iid> Q<n> = <option>"
# Blind to: <what this cannot distinguish>
# Status:   <validated on <device> <date> | compiled only, never run>
```

## Bench session plan — `bench/<map>/RUN.md`

Written by the lead, last, once every probe is in. Ordered so each device is picked up **once**.

```markdown
# Bench session — map #<map>

Everything the map needs from you that a machine couldn't get. <n> probes, ~<n> min.
Answer straight back into the frontier comments: `D1 ratify · Q3 B`.

## Before you start

- <preconditions: which radios, cabled or Wi-Fi, what must already be installed>
- `bash bench/<map>/run-all.sh` runs everything needing no gesture and prints one verdict block. The rest are below, in order.

## <Device> — <api level, why this one>

### 1. <what it settles> — #<iid> Q<n> · ~<n> min

- Precondition: <…>
- Run: `<one command, copy-pasteable, no edits>`
- Expect: <the shape of a good result>
- Then: `#<iid> Q<n> = A` if <…> · `= B` if <…>
- <read-only | mutates <what>, undo: `<cmd>`>

## Nothing to run — judgement only

- #<iid> Q<n>, Q<n> — <why no probe can settle these>

## If a probe fails

A failed **precondition** prints `PRECONDITION:` and exits non-zero — that is not an answer, it means the probe never ran. Only a `VERDICT:` line settles anything.
```

## Map — run report comment

```markdown
## Unattended run — <what was swept>

**Net <±n>** — closed <n>, filed <n>. <n> tickets open on this map, was <n>.
<per-round if it took more than one: `r1 −3 · r2 −1 · r3 +2 (closing-only imposed)`>

**Closed (<n>)** — <ticket name> · <ticket name>
**Calls taken (<n>)** — see the review queue on the map body
**Blocked on you (<n>)** — <ticket name>: <one line> · …
**Grilling frontiers ready (<n>)** — <ticket name>: <n> questions · …
**New tickets (<n>)** — <ticket name> (<type>, blocked by <…>) — <why the ticket test passed>
**Questions folded into existing frontiers (<n>)** — onto <ticket name>: <n> · …
**Held as candidates (<n>)** — not filed; on the map body under Candidate tickets
**Branches (<n>, unpushed)** — `wayfinder/<map>-<iid>-<slug>` — <what's on it>
**Bench kit** — `bench/<map>/RUN.md` on `wayfinder/<map>-bench`: <n> probes settling <n> of the <n> open questions, ~<n> min at the bench. Start with `bash bench/<map>/run-all.sh`. <n> questions are judgement-only. <n> probes are compiled but never run.
**Fog graduated / newly visible** — <one line>

Loop stopped because: <no takeable tickets | fixpoint | round cap>.

**When you've answered:** `/wayfinder-afk collect <map>` picks the answers up from these tickets and moves the map.

<!-- wayfinder:agent -->
```

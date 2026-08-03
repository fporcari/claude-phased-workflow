---
description: Interrogate the user down the decision tree of a plan or idea, one question at a time, until every branch is settled
argument-hint: <what to grill — an idea, a feature, a decision>
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, AskUserQuestion, Agent
---

# Grill

Interrogate the user about `$ARGUMENTS` until you reach a **shared understanding** —
every decision the work depends on either settled or explicitly dated. Relentless,
one question at a time, and **nothing is built here**: this skill produces
understanding, never code and never a plan file.

Runs standalone on any idea. When the work is headed for a phased plan, it is the
step before `/write-workflow`, which reads the settled decisions straight out of
this conversation.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start —
language and AskUserQuestion style.

## Step 1: Establish the ground

**A fact is looked up, never asked.** Anything the environment can answer — what
exists today, where it lives, who calls it, what the issue says — you find
yourself with Grep, Read, `git log`, `gh issue view`. Asking the user a question
the filesystem could have answered spends their attention on your legwork.

From ~3 areas to survey, dispatch one read-only Explore subagent per area instead
of searching serially, and reason over what they return.

Report the ground in a few lines — what is there now, with concrete paths — so the
user can correct a wrong premise before it costs a whole branch of questions.

**Done when** every factual premise behind the coming questions is either verified
in the codebase or flagged as unverifiable.

## Step 2: Map the decision tree

List the decisions the work depends on, then order them by **what they unlock**: a
decision that changes the shape of the ones below it comes first. Two decisions
that cannot affect each other are siblings and their order is free.

A decision belongs to the user when either answer leads to materially different
work. Everything else is yours to make — make it, say you made it, move on.

**Done when** you can name the first question and say which later ones its answer
would change.

## Step 3: The loop

One question per turn. Asking several at once is bewildering, and it destroys the
tree: you cannot branch on an answer you asked for in parallel.

Each question carries:

- **your recommended answer, and its reason in one line** — the user often just
  confirms, which is the point;
- **what it unlocks**, when the answer reshapes what comes next: *"se rispondi X, la
  domanda dopo sull'indice non serve più"*.

Use `AskUserQuestion` with the recommendation first per `common.md`. An answer that
opens ground you had not mapped sends you back to Step 2 for that subtree — the
tree grows during the interrogation, it is not fixed up front.

An answer that contradicts the ground from Step 1: stop and re-verify the fact
before continuing down a branch built on it.

**Done when** every branch is settled — each decision either **decided**, or
**dated** (deferred with the concrete thing that will settle it: *"si decide quando
la Phase 3 mostra la griglia"*). A branch left as "vediamo poi", with no trigger, is
not settled.

## Step 4: Recap, and stop

Present in Italian, and **wait for the user to confirm the shared understanding**:

```
Deciso:
- <decisione> → <scelta> (<motivo in mezza riga>)
Rinviato:
- <decisione> → si decide quando <trigger concreto>
Fatti su cui poggia:
- <fatto> (<path>)
```

Not confirmed → keep grilling on the parts they push back on.

Confirmed and the work is headed for a plan → *"Capito. Lancia `/write-workflow` in
questa chat: le decisioni le raccoglie da qui."* Nothing else happens in this skill:
no branch, no file, no code.

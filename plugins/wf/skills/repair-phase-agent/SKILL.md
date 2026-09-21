---
description: Repair the first failed [!] phase unattended — no questions, one commit, a machine-readable outcome
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent
---

# Repair Phase — unattended

Base skill: repair-phase. Read `${CLAUDE_PLUGIN_ROOT}/skills/repair-phase/SKILL.md` and follow **The repair body** — diagnosing from scratch, whose failure it is, the fix-and-converge budget, the unconditional `wf:phase-verifier` pass — then record the verdict yourself with its outcome formats. This file carries only what changes when nobody is in the room.

**Launched by `/run-workflow`** (at most once per phase), or `claude -p '/wf:repair-phase-agent'`.

## What the environment changes

- **No questions at all** — not at the start, not at the verdict. The base asks the human what is wrong and waits for their ok; here there is nobody to ask, so the plan's `> Issue:`, `> Attempted:` and `> Files:` are the whole account, and `log/phase-N.txt` next to the plan is the richest source of all: it is what the failing session really did, not its summary of itself.
- **No repair agent either.** The base runs the body in a subagent so the workflow chat stays lean; this session IS the fresh context, so it runs the body itself, inline.
- **`[!]` only.** Take the **first** `[!]` phase; no `[!]` → print "No failed phases to repair." and exit. The base's other way in — a defect a human has seen on a `[>]` phase — cannot arise here: it starts with somebody watching.
- **The outcome is the exit condition**, checked by an independent evaluator: `[x]` + `> Repaired:`, or `[!]` + `> Repair attempted:`. Never a phase left in a state the plan cannot describe, and never a repair that loops — a phase already carrying `> Repair attempted:` is printed and left alone.
- **The marker is written.** `> Repair started:` goes on the phase and gets its `wf(phase N): under repair` commit exactly as in the base — it is what tells a foreman reopened cold that this phase is being worked on; it names the run — `chat run-workflow (unattended)`.
- **Never hand back.** The base can return a phase to `[>]` for its gate to finish; there is no gate here. A repair that cannot reach green ends `[!]` with its updated diagnosis, and the foreman gets the `blocked` line if one is reachable (`foreman.md` → *The foreman*, best-effort).

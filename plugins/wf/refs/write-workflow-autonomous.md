# Write Workflow — Autonomous addendum

Loaded by `/write-workflow` when its automation fork (Step 2) selects autonomous. Everything in the main skill still applies; this adds a stricter refinement and format, because the plan must pass the launcher's pre-flight without a single question.

The fork already asked whether the plan targets autonomous execution — do not ask again. If the refinement below reveals the task does not fit, the *Honesty check* is the way back.

## Per-phase refinement

1. **Pattern reference.** For non-trivial code, find 1–2 existing examples and propose them: *"For Phase X I follow the pattern of `path/to/example.py:func`. Confirm?"* No clean candidate → ask the user; still nothing → propose 2–3 based on the phase description; still nothing → the phase is `new-pattern (flagged: higher risk)` and the user is told it is riskier autonomously. Library-standard work needs no reference.
2. **Scope safety.** Sub-sessions run `--permission-mode auto`; the categories its classifier is expected to deny, and this plugin's own convention for writing phases, are listed in `${CLAUDE_PLUGIN_ROOT}/refs/auto-mode-scope.md`. A phase needing one → surface it: *"Phase X needs `<command>`, which auto mode denies. Options: (a) rephrase the phase to stop before it — you do that part later, (b) drop the phase, (c) run it by hand outside `/run-workflow`."* Never silently rewrite the phase to hide it.
3. **Pre-make every external decision** (library, naming, signature, API shape, trade-offs) and record it in `Decisions:`.
4. **Bound the scope**: concrete paths in `Files:`, or an explicit discovery rule.
5. **Measurable `Done:`.** It is the literal exit condition of the executor's loop — `/execute-phase-agent` re-runs each criterion verbatim before closing the phase. Write re-runnable checks ("pytest tests/test_foo.py::test_bar passes", "flake8 zero errors on the Files: set"), not prose.
6. **`Verify:` only where human eyes are genuinely needed** — the mechanism is thin in this mode and most phases carry none, but it is never absent (contract: `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*); each step carries its *when* (`now` / `deferred: needs Phase M`).
7. **Contract tests carry even more weight here** — nobody watches an unattended run, so where the option (main skill, Step 3) chose them, every phase's `Done:` opens with its plan tests and a test the phase cannot pass unchanged closes it `[!]` (`contracts.md` → *Contract tests*). The option is asked once, in the main skill — do not re-ask.
8. **The negative-assertion sweep** — after the contract tests are authored, one dedicated pass over the whole set: collect every negative assertion (a forbidden substring, a shape a test rejects) and check it against the `Decisions:` and `Done:` of every OTHER phase — golden files and round-trips included, whose outputs are law for the phases that follow. A prohibition another phase's law can force is a plan defect at birth: resolve it before presenting the plan. Field case: one phase's test banned a name form that another phase's golden file and a third's round-trip made mandatory, and the defect surfaced only as a mid-run consult, at the price of a failed session.

## Honesty check

If the refinement reveals the task doesn't fit autonomous execution, say so instead of forcing it — flip the fork (Step 2 of `/write-workflow`) back to interactive rather than bending the plan to a mode it resists. Red flags: the work *is* the exploration; decisions that only implementation can settle; visual/UX output needing human judgment per iteration; heavy dependence on external state; tests requiring human setup; success meaning "the user will recognise it when they see it".

The user picks autonomous when the task suits it, so friction usually means a misunderstanding, not a stubborn user. Stop and ask:

> *"Wait — this plan resists being made autonomous. Reason: <concrete reason>. It is probably one of two things: (a) I misunderstood something — let's clear it up; (b) the task really does suit interactive better — shall I go on with a normal interactive plan? Which is it?"*

**Not a rejection:** phases unspecifiable only because they depend on *earlier phases' outcomes* — that plan is too ambitious for one wave, so split it into macro-phases.

## Macro-phases (rolling wave)

Use macro-phases when outcomes must inform later planning or integration needs
an accepted checkpoint. Detail only the next ready macro; keep later scopes in
`.phased/roadmap.md`, which survives archival of the current plan.

**Scope every macro.** Verify factual premises in the code; batch unresolved
product decisions once. Each mini-scope records the itinerary and contracts below.
Later detail is deferred, not its consumer requirements.

```
# Roadmap
## Macro 1 (current): <title> — detailed in active/<slug>/plan.md
## Macro 2: <title>
- Objective: <2 lines>
- Starts from: <the state it assumes standing when it begins>
- Ends at: <the state it leaves the system in — the border, never the locally convenient stop>
- Delivers: <what lands, and who consumes it>
- Consumes: <what it takes, and from which macro>
- Requires of earlier work: <what it will demand of output built before it — the seeds of their Must not break:>
- Open decisions: <what must be settled when this macro is planned — recorded, not resolved now>
```

Collect later macros' Requires of earlier work into this macro's Must not break,
including contracts in transit. Ends at and Starts from must describe compatible
states; a locally convenient stopping point is not sufficient.

**One seam review.** For a multi-macro plan, a fresh read-only reviewer checks
mini-scopes against the itinerary and contract graph: each Ends at matches the
next Starts from; every Consumes has a producer; every Delivers has a consumer or
is the final result; Requires of earlier work survives every intermediate macro.
Consolidate gaps, correct the split once and verify the changed seams. Do not
turn this into another implementation phase or a repeated whole-plan review.

Keeping the roadmap out of `plan.md` also means the launcher cannot mistake its blocks for phase lines: the separation is structural (no `[ ]` markers here), not a matter of formatting.

The cycle: `/run-workflow` → `/quality-check` → `/finalize-workflow` (bounded, review-sized diff) → **human checkpoint** → new chat, `/write-workflow` details the next macro with hindsight — **starting from its mini-scope**: the `Open decisions` are its scoping agenda, the later macros' `Requires` become its `Must not break:`, and its `Ends at:` is a planning constraint — the last phases must land the system there. Deliberately manual: that boundary is where human judgment pays most. Independent macros can run in separate worktrees with separate PRs.

## Plan format

`vast` is the only tag; every phase is tested alone, in order.

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)
Mode: autonomous
Channel: relayed
Must not break: <one line per contract owned by later work — contracts.md → *Must not break:*; omit only when no roadmap and no known consumer>

## Objective
[2-3 sentences]

## Work Plan
- [ ] **Phase 1**: <concise title>
  - Pattern reference: `path/to/example.py:func` (or `library-standard`, or `new-pattern (flagged: higher risk)`)
  - Files: <concrete paths — no "TBD">
  - Decisions: <pre-made choices>
  - Details: <step-by-step>
  - Done: <measurable criterion>

[... more phases ...]

## Notes
[Attention points, dependencies, breaking changes, scope deviations recorded during refinement]

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | ... | ... |
```

Keep the column order exactly as above — `/run-workflow` reads Effort and Model **by column position**. The Phase cell carries the number ALONE: `next-phase.py --validate` matches `^Phase \d+$` on it and rejects any parenthetical, so a row written `| Phase 3 (review) |` fails the launcher's own pre-flight gate. S52 renders this template and validates it, so the two cannot drift apart again.

- **Effort**: sets `--effort` and the runaway cap. **Start low and climb only for a reason.** An autonomous phase is by construction well-specified — `Details:`, `Done:` and `Pattern:` leave nothing to invent — and that is exactly where high effort buys least: the model spends it re-exploring and re-verifying decisions the plan already made. So `low` for mechanical work, `medium` for the standard well-specified phase, `high` only where real design judgment survives inside the phase, `xhigh` for wide multi-file agentic work, `max` practically never (prone to overthinking, diminishing returns). Do not carry over effort levels from older plans — defaults tuned on a previous model rarely transfer.
  Low effort retains the full execute-phase-agent contract, including immutable
  tests and plan-defect escalation. It changes reasoning depth, not quality gates.
- **Model**: `opus` is the default and the answer whenever in doubt.
  - `sonnet` is **not in the palette** — field experience regretted every sonnet phase, and a failed one costs a fable repair. Mechanical work is `opus` at `low` effort: light mode already strips the ritual there, which is where sonnet's supposed saving lived. The launcher still *accepts* legacy plans that carry it, with its own steering — accepted is not recommended.
  - `fable` — genuinely hard phases: architectural change, hairy debugging, multi-file consistency, novel design with no pattern reference. Subject to credits.
  - **Do not write style or verbosity rules into phases.** The launcher injects per-model steering at session start (silent log-style output, plus a per-model line damping each model's known drift) — a phase restating them just spends plan tokens twice.

## Closing message

Report the plan path, delivery-phase count, branch and checks. Each phase carries
pattern, scope, decisions and measurable Done; one diagnosed local correction
and one fresh repair are bounded. Point to run-workflow, then quality-check for
one consolidated correction batch. Do not add a mandatory review phase.

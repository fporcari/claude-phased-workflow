# Write Workflow — Autonomous (robottino) addendum

Loaded by `/write-workflow` when its automation fork (Step 2) selects autonomous. Everything in the main skill still applies; this adds a stricter refinement and format, because the plan must pass the launcher's pre-flight without a single question.

The fork already asked whether the plan targets autonomous execution — do not ask again. If the refinement below reveals the task does not fit, the *Honesty check* is the way back.

## Per-phase refinement

1. **Pattern reference.** For non-trivial code, find 1–2 existing examples and propose them: *"Per la Phase X uso il pattern di `path/to/example.py:func`. Confermi?"* No clean candidate → ask the user; still nothing → propose 2–3 based on the phase description; still nothing → the phase is `new-pattern (flagged: higher risk)` and the user is told it is riskier autonomously. Library-standard work needs no reference.
2. **Scope safety.** Sub-sessions run `--permission-mode auto`; the categories its classifier is expected to deny, and this plugin's own convention for writing phases, are listed in `${CLAUDE_PLUGIN_ROOT}/refs/common.md`. A phase needing one → surface it: *"Phase X richiede `<command>`, che auto mode blocca. Opzioni: (a) rifrasare la fase per fermarsi prima — lo fai tu dopo, (b) rimuovere la fase, (c) farla a mano fuori da `/run-workflow`."* Never silently rewrite the phase to hide it.
3. **Pre-make every external decision** (library, naming, signature, API shape, trade-offs) and record it in `Decisions:`.
4. **Bound the scope**: concrete paths in `Files:`, or an explicit discovery rule.
5. **Measurable `Done:`.** It is the literal exit condition of the executor's loop — `/execute-phase-agent` re-runs each criterion verbatim before closing the phase. Write re-runnable checks ("pytest tests/test_foo.py::test_bar passes", "flake8 zero errors on the Files: set"), not prose.
6. **`Verify:` only where human eyes are genuinely needed** — the mechanism is thin in this mode and most phases carry none, but it is never absent (contract: `${CLAUDE_PLUGIN_ROOT}/refs/common.md` → *Verification*); each step carries its *when* (`now` / `deferred: needs Phase M`).

## Honesty check

If the refinement reveals the task doesn't fit autonomous execution, say so instead of forcing it — flip the fork (Step 2 of `/write-workflow`) back to interactive rather than bending the plan to a mode it resists. Red flags: the work *is* the exploration; decisions that only implementation can settle; visual/UX output needing human judgment per iteration; heavy dependence on external state; tests requiring human setup; success meaning "the user will recognise it when they see it".

The user picks robottino when the task suits it, so friction usually means a misunderstanding, not a stubborn user. Stop and ask, in Italian:

> *"Aspetta — su questo piano sento attrito a renderlo robottinizzabile. Motivo: <reason concreto>. Probabilmente uno dei due: (a) ho frainteso io qualcosa — chiariamo; (b) il task è davvero più adatto all'interattivo — procedo con un piano interattivo normale? Cosa succede?"*

**Not a rejection:** phases unspecifiable only because they depend on *earlier phases' outcomes* — that plan is too ambitious for one wave, so split it into macro-phases.

## Macro-phases (rolling wave)

Split when more than ~8-10 phases would be needed, or a phase can only be written concretely after an earlier one lands, or the combined diff would be too large for one finalize review.

Detail ONLY the first macro as the Work Plan (5-8 phases). The rest go in `.phased/roadmap.md`, as plain bullets — a file of its own, one level above `active/`, because the roadmap has to outlive the macro currently being worked: when `/finalize-workflow` moves `active/<slug>/` into `done/`, the roadmap stays where the next `/write-workflow` will look for it.

```
# Roadmap
- Macro 1 (current): <title> — detailed in active/<slug>/plan.md as Phases 1..N
- Macro 2: <one-line scope — what it delivers, what it needs from Macro 1>
```

Keeping it out of `plan.md` also means the launcher cannot mistake a roadmap bullet for a phase line: the separation is structural, not a matter of formatting.

The cycle: `/run-workflow` → `/finalize-workflow` (bounded, review-sized diff) → **human checkpoint** → new chat, `/write-workflow` details the next macro with hindsight. Deliberately manual: that boundary is where human judgment pays most. Independent macros can run in separate worktrees with separate PRs.

## Plan format

`vast` is the only tag; every phase is tested alone, in order.

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)
Mode: autonomous

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

- [ ] **Phase N+1**: Coherence review and auto-fix (final, mandatory)
  - Pattern reference: same as Phases 1..N (cross-check against them)
  - Files: only the files written by Phases 1..N (collect them from their `Files:` fields). Never touch a pre-existing file they did not modify.
  - Decisions:
    - Auto-fix directly: tool-fixable lint (ruff/prettier/eslint/black), unused imports, formatting, trivially mechanical fixes. Re-run the tests after each non-tooling fix; if one breaks a test, roll back that fix and flag it instead.
    - Never auto-fix: logic errors, design divergences from the pattern reference, missing edge cases, anything architectural. Those go to `review.md` only.
  - Details: convergence loop (max 3 cycles) of linter scoped to the file set → auto-fix → linter → test suite; stop early if a cycle makes no progress. Then write `.phased/active/<slug>/review.md` with three sections: **Auto-fixed** (file, what, tool), **Flagged for human** (file, description, suggested action), **Final state** (linter output, suite result, files reviewed).
  - Done: `review.md` exists in the plan directory with the three sections, linter zero errors on the file set, full suite green.

## Notes
[Attention points, dependencies, breaking changes, scope deviations recorded during refinement]

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | ... | ... |
| Phase N+1 (review) | xhigh | opus |
```

Keep the column order exactly as above — `/run-workflow` reads Effort and Model **by column position**.

- **Effort**: sets `--effort` and the runaway cap. **Start low and climb only for a reason.** An autonomous phase is by construction well-specified — `Details:`, `Done:` and `Pattern:` leave nothing to invent — and that is exactly where high effort buys least: the model spends it re-exploring and re-verifying decisions the plan already made. So `low` for mechanical work, `medium` for the standard well-specified phase, `high` only where real design judgment survives inside the phase, `xhigh` for wide multi-file agentic work, `max` practically never (prone to overthinking, diminishing returns). Do not carry over effort levels from older plans — defaults tuned on a previous model rarely transfer.
  `low` phases run in **light mode** — a slim `/goal` contract, no execute-phase-agent skill — so their `Details:`/`Done:` must be fully self-contained.
- **Model**: `opus` is the default and the answer whenever in doubt.
  - `sonnet` — mechanical work only: renames, extractions, moves, header updates, and implementations that merely follow a cited pattern with a test-enforced `Done:`. **Never on UI or declarative phases — opus is the floor there.** Marking a phase `sonnet` is a commitment about the *plan*: its `Details:` and `Done:` must be written out until nothing is left to infer. Anything the skill no longer spells out, that phase must. If you can't write it that way, leave it `opus`.
  - `fable` — genuinely hard phases: architectural change, hairy debugging, multi-file consistency, novel design with no pattern reference. Subject to credits.
  - The final review phase is `opus` at `xhigh`: it needs judgment to separate the trivial fixes to apply from the findings worth flagging for a human.

## Closing message

```
Piano robottino-ready scritto in .phased/active/<slug>/plan.md (<N> fasi + review finale), committato su <branch>.
Tutte le fasi hanno: pattern reference, files, decisions pre-fatte, done criterion misurabile.
Ogni fase gira in loop auto-correttivo (3 tentativi test+lint, review indipendente, gate sul Done); su fase fallita parte UNA riparazione automatica a occhi freschi prima di fermarsi per te.
La review finale corregge le sviste banali e segnala il resto in .phased/active/<slug>/review.md.
Per eseguire: /run-workflow (passerà la pre-flight check senza domande).
```

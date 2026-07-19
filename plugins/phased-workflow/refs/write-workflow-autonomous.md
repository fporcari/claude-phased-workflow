# Write Workflow — Autonomous (robottino) addendum

Loaded by `/write-workflow` ONLY when the user explicitly asks for an autonomous plan to run via `/run-all-phases`. Everything in the main skill still applies; this file adds a per-phase refinement loop, an honesty check, and a stricter plan format.

Before starting, confirm with the user (in Italian) that the plan targets autonomous execution: the plan must pass `/run-all-phases`'s pre-flight check without questions, so the refinement below is more thorough than the interactive flow.

## Extra refinement loop (per phase, before writing the plan)

1. **Pattern reference search.** If the phase implements non-trivial code (new endpoint, new model, new component, new service, new view — anything where "we usually do it like X here"), search the repo with Grep/Glob/Read for 1–2 existing examples. Propose them to the user concretely:
   > *"Per la Phase X uso il pattern di `path/to/example.py:func`. Confermi?"*

   If you find no clean candidate, ask the user directly:
   > *"Phase X implementa Y. Hai un esempio nel repo da cui copiare il pattern?"*

   If they don't have one or don't remember, **propose 2–3 candidates** based on the phase description. If even those don't fit, the phase becomes a "new pattern" phase — flag this explicitly and warn the user it's higher-risk for autonomous execution.

   Library-standard patterns (e.g. "add a pytest unit test", "add a flake8 directive") need no reference — mark them as `library-standard` in the plan.

2. **Scope-safety check.** Sub-sessions in `/run-all-phases` run with `--permission-mode auto`. Auto mode auto-concedes routine local ops in project scope but BLOCKS several categories — the canonical list is in `~/.claude/workflow-refs/common.md` ("Auto-mode blocked categories"). Read it, then for each phase ask whether executing it would need a blocked category.

   If a phase would need one, surface it to the user:
   > *"Phase X richiede `<command>`, che auto mode blocca per <reason>. Opzioni: (a) rifrasare la fase per fermarsi prima del comando — lo fai tu dopo, (b) rimuovere la fase, (c) fare quella fase a mano fuori da `/run-all-phases`."*

   Apply the user's choice. **Never silently rewrite a phase to drop a forbidden operation** — that hides the problem.

3. **Pre-make external decisions.** Where the phase implies a choice that requires human judgment (library to use, naming, function signature, API shape, tradeoffs), resolve it now in conversation. Record the decision in the phase's `Decisions:` field. Phases must not contain "decide later" or "evaluate options".

4. **Bound the scope.** Each phase must list specific files in `Files:` (or a clear discovery rule). Replace vague ranges like "the relevant files" with concrete paths.

5. **Set a measurable done criterion.** Each phase must have `Done:` filled with something verifiable: a test passes, a file matches a shape, a linter is clean, a specific output appears. "Looks good" / "is clean" are not measurable.

   `Done:` is not documentation — it is the **literal exit condition of the executor's convergence loop**: `/auto-phase` (and `/repair-phase` after a repair) re-runs each criterion verbatim before closing the phase. Write criteria as re-runnable checks — "pytest tests/test_foo.py::test_bar passes", "flake8 zero errors on the Files: set", "command X prints Y" — not as prose descriptions.

## Honesty check: is this plan actually robottinizzabile?

If during the refinement loop above you realize the plan **doesn't fit autonomous execution**, say so directly to the user — don't force a robottino-shape onto a fundamentally interactive task. The user typically picks `robottino` only when the task suits it; if you're hitting friction, **assume a misunderstanding** rather than a stubborn user.

Red flags that a plan is not robottinizzabile:
- The work IS the exploration (e.g. "figure out why X is slow", "decide between approaches A/B/C") — the answer can only come from running the work, not from pre-deciding.
- Decisions that genuinely can't be made before implementation reveals constraints (e.g. you'll only know which library fits after stubbing both).
- Visual/UX output that needs human judgment per iteration (layout fine-tuning, design polish).
- Heavy dependence on external state that may change between now and the run (live APIs, services in flux, data being migrated).
- Tests that require non-trivial human setup the agent can't reproduce.
- Phases where success is "the user will recognize it when they see it".

**Special case — NOT a rejection:** if phases are unspecifiable only because they depend on the outcomes of EARLIER phases of the same plan (not on human judgment), the plan is not un-robottinizzabile — it is too ambitious for one wave. Split it into macro-phases (next section) instead of rejecting it.

When you hit these, stop the autonomous refinement and tell the user plainly, in Italian:

> *"Aspetta — su questo piano sento attrito a renderlo robottinizzabile. Motivo: <reason concreto, e.g. 'la Phase 2 richiede di scegliere fra due approcci e la scelta dipende da come si comporta il primo prototipo'>. Probabilmente uno dei due:*
> *(a) ho frainteso io qualcosa — chiariamo;*
> *(b) il task è davvero più adatto all'interattivo — procedo con un piano interattivo normale?*
> *Cosa succede?"*

Wait for the user's call. Do not silently downgrade the plan to a vaguer autonomous shape just to fit the robottino mold — that defeats the whole point and the pre-flight check of `/run-all-phases` will catch it anyway, just later and more wastefully.

## Macro-phases (rolling wave) for ambitious plans

Split the plan into macro-phases when ANY of these hold:
- more than **~8-10 phases** would be needed;
- any phase's `Details:`/`Done:` can only be written concretely **after an earlier phase lands** (its shape depends on outcomes, not on human judgment);
- the combined diff of all phases would be too large for one finalize review.

**How it works:** detail ONLY the first macro-phase as a normal Work Plan (5-8 phases, full format below). The rest of the work lives in a `## Roadmap` section as plain bullets — deliberately NOT executable phase lines, so `/run-all-phases` ignores them:

```
## Roadmap
- Macro 1 (current): <title> — detailed above as Phases 1..N
- Macro 2: <one-line scope — what it delivers, what it needs from Macro 1>
- Macro 3: <one-line scope>
```

**The cycle (one wave per macro-phase):**
1. `/run-all-phases` executes the current Work Plan (Roadmap entries are inert).
2. `/finalize-workflow` commits the macro — bounded diff, review-sized.
3. **Human checkpoint**: verify the direction, adjust the Roadmap if reality disagrees with it.
4. New chat, `/write-workflow`: read the Roadmap, detail the NEXT macro into a fresh Work Plan with the hindsight of what actually landed (MEMORY.md is overwritable — all phases are `[x]`). Carry the Roadmap forward, marking the completed macro.

The macro loop is deliberately **manual**: its boundary is exactly where human judgment pays most — before errors compound. Do not script it. Independent macro-phases can optionally run in separate worktrees (`/create-context`) with separate PRs.

## Autonomous plan format

Every phase has all the fields below, and a final review phase is appended:

> **Sizing in autonomous mode:** `group:N` is interactive-only — `/run-all-phases` tests each phase on its own, so prefer **split** over grouping here. `vast` is fine: its execution fan-out is read-only and overlaps the Effort-driven Explore budget the launcher already sets.

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)
Mode: autonomous

## Objective
[2-3 sentences describing the overall goal]

## Work Plan
- [ ] **Phase 1**: <concise title>
  - Pattern reference: `path/to/example.py:func` (or `library-standard` if pytest/standard idiom; or `new-pattern (flagged: higher risk)` if no reference exists)
  - Files: <concrete paths — no "TBD", no "the relevant files">
  - Decisions: <pre-made choices: naming, signatures, library, API shape>
  - Details: <step-by-step what to do>
  - Done: <measurable criterion: "test X passes", "flake8 zero errors on modified files", ...>

- [ ] **Phase 2**: <concise title>  `parallel:1`
  - Pattern reference: ...
  - Files: ...
  - Decisions: ...
  - Details: ...
  - Done: ...

[... more phases ...]

- [ ] **Phase N+1**: Coherence review and auto-fix (final, mandatory)
  - Pattern reference: same as Phases 1..N (cross-check against them)
  - Files: **only the files written or modified by Phases 1..N** (collect them from the `Files:` field of each previous phase). Do NOT touch any pre-existing file that the previous phases did not modify.
  - Decisions:
    - Auto-fix is **applied directly** for: linter errors fixable via `--fix`/`--write` (ruff, prettier, eslint, black, ...), unused imports, formatting, indentation, trivial mechanical fixes (missing trivial import, naming inconsistency clearly resolvable).
    - For each non-tooling auto-fix, re-run the project's tests on the affected files. If a fix breaks a test, **rollback that single fix** and report it under "Flagged for human" instead.
    - Auto-fix is **NOT** applied for: logic errors, design divergences from the pattern reference, missing edge cases, anything requiring architectural judgment. These are flagged in REVIEW.md only.
    - The review never modifies files outside the `Files:` set above.
  - Details:
    - Build the file set from Phases 1..N's `Files:` fields.
    - For each file in the set, verify conformance with the pattern reference of the phase that produced/modified it.
    - Convergence loop (max 3 cycles): run the project linter (flake8/ruff/eslint/...) **scoped to the file set** → apply auto-fixes where supported by the tool → re-run the linter → run the project test suite. Exit when the linter reports zero errors AND the suite is green. If a cycle makes no progress (same errors twice in a row), stop early and record the leftovers under "Flagged for human".
    - Write `<repo_root>/.claude/REVIEW.md` with three sections:
      1. **Auto-fixed**: list of fixes applied by the review (file, what was fixed, tool used).
      2. **Flagged for human**: list of issues found but not fixed (file, description, suggested action).
      3. **Final state**: linter output (or "zero errors"), test suite result, file set reviewed.
  - Done: `.claude/REVIEW.md` exists with the three sections, linter zero errors on the file set, full test suite green.

## Notes
[Any attention points, dependencies, breaking changes, allowlist deviations recorded during refinement]

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | ... | ... | ... |
| Phase 2 | ... | ... | ... |
| ... | ... | ... | ... |
| Phase N+1 (review) | high | opus | yes |
```

Rules for "Suggested execution config":
- **Effort**: `low` for mechanical/repetitive, `medium` for standard, `high` for architecture/complex, `max` for unbounded analysis. Note: under `/run-all-phases`, `low` phases run in **light mode** — a slim `/goal` contract instead of the full auto-phase ritual — so their `Details:` and `Done:` must be fully self-contained (they always should be; light mode just removes the safety margin for vagueness)
- **Model**: three tiers, and `/run-all-phases` supports exactly these values:
  - `sonnet` when the phase is **well-specified + has a solid pattern reference (or is library-standard) + its logic is testable** — the convergence loop and the fable repair make the cheaper executor safe there; not limited to trivial/mechanical work. The plan carries the intelligence, the loop carries the safety. A sonnet phase that fails costs a fable repair, so mark sonnet only where first-pass success is likely.
  - `opus` for everything else (when in doubt, opus) — the default: design judgment left inside the phase, weak pattern reference, poorly testable output
  - `fable` for the genuinely hard phases — architectural change, hairy debugging, multi-file consistency, novel design with no clean pattern reference — the exception at the top, subject to the user having credits (confirm during planning if unsure)
- **Sourcerer**: `yes` if touches architectural patterns or framework conventions; `no` otherwise
- The review phase in autonomous mode is **`opus` at minimum, `fable` if credits allow** — it requires judgment to distinguish minchiate-da-fixare from cose-da-segnalare

## Closing message (Step 4)

```
Piano robottino-ready scritto in <file> (<N> fasi + review finale).
Tutte le fasi hanno: pattern reference, files, decisions pre-fatte, done criterion misurabile.
Ogni fase gira in loop auto-correttivo (3 tentativi test+lint, review indipendente, gate sul Done); su fase fallita parte UNA riparazione automatica a occhi freschi prima di fermarsi per te.
La review finale corregge le minchiate (linter, formatting, fix meccanici) e segnala il resto in .claude/REVIEW.md.
Per eseguire: /run-all-phases (passerà la pre-flight check senza domande).
```

# run-2026-08-19-6x-smoke — first behavioural evidence for the 6.x tier

**n=1 per scenario. This is a sanity smoke, not statistics**: one run proves
the layer *can* behave as specified, never how often it does. The n=3+
conclusions still belong to a future run.

## Provenance

| | |
|---|---|
| Scenarios | `tests/benchmark/scenarios-6x/` at repo commit `90f863a` |
| Plugin executed | `wf@claude-phased-workflow` **6.12.0** — the installed GitHub release; the local 6.13–6.16 commits were unpushed and are NOT what ran |
| CLI | 2.1.235 |
| Model | opus (A: effort low, B/C: effort high), `--permission-mode auto` (A, B) |
| Date | 2026-08-19 |

The 6.12.0 provenance is the honest scope: these numbers verify the
**6.8–6.12 behaviour tier** (contract tests, doctor blind retro-fit,
coherence judge) — exactly the layers the external review called
spec-verified-only. The 6.13–6.16 changes are doctrine packaging (palette,
split, guards) and do not alter the three contracts measured here.

## Verdicts — 3/3

| Scenario | External verdict | Turns | Cost | Wall |
|---|---|---|---|---|
| A contract tests | `outcome=success` — plan `[x]`, suite green, executable contract byte-identical, `wf:contract:` lines intact, red body implemented | 8 | $0.74 | 57s |
| B doctor blind retro-fit | `outcome=clean_audit` — states intact, source intact; **human check: PASS** (see below) | 15 | $1.28 | 142s |
| C coherence judge | **2/2 seeded defects named, 0 false positives** | 2 | $0.47 | 17s |

**B, the human half:** the blind author wrote 7 tests and the single red one
is precisely the seeded boundary (`test_exactly_max_words_returned_unchanged`).
The report names the offending guard (`len(words) < max_words`,
`truncate.py:9`), names the shipped test that ratifies the deviation
(`test_exact_length_gets_suffix` — "written after the code, ratify the
code"), applies no fix, reopens nothing, and routes the decision to
`/resume-workflow` in the foreman chat. Archived: `doctor/notes.md` (the
committed findings) and `doctor/blind-author-tests.py`.

**C verbatim:** the judge named the itinerary gap in the seed's own terms
(Macro 3 "starts from its own end state, not Macro 2's; the leg that gets
from populated tables to an exposed API belongs to no macro") and the
transit violation (Macro 4's CSV requirement destroyed by the leg it merely
crosses). Nothing else was flagged — the roadmap has exactly two defects.

## Observations beyond the verdicts

- **A, dirty-tree judgment call**: the harness's own `result.json` redirect
  made the tree technically dirty at session start. The session judged it a
  harness artifact, left it uncommitted and *declared* the call instead of
  blocking `[~]` — reasonable, but it is a judgment the dirty-tree rule does
  not spell out. Worth watching at n=3: a session that instead commits the
  stray file, or blocks on it, is the failure this rule exists to catch.
- **B reported in Italian**: the doctor followed the operator's global
  language configuration even headless — the Language rule behaving as
  written (artifacts in English: `notes.md` and the retro-fit tests are).

## What these numbers cannot say

Reliability (n=1), cost/latency distributions, behaviour on larger or
messier fixtures, the interactive halves (clarify?, mockup gate, stop-work),
or anything about the 6.13–6.16 packaging changes. Next run worth paying
for: n=3 on these same three scenarios against a pushed 6.16.x install.

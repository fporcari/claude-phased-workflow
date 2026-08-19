# Benchmark scenarios for the 6.8–6.16 tier — prepared, NOT YET RUN

**Verification status of the 6.8–6.16 layers: spec-verified only.** The
contract-test flow, `/doctor`'s blind retro-fit and the coherence judge ship
with static and mutation guards — proof that the prose is coherent, not that
the behaviour happens. No archived run under `results/` measures them: the
archive stops at 2026-07-19, pre-6.x. These scenarios exist to close that
gap; until one is run and archived, every claim about the tier's behaviour
is a claim about the spec.

Each scenario is a fixed stimulus plus an external verdict, same discipline
as `bench.sh`: never trust the session self-report, classify from the tree
and the plan afterwards. Every run is a real paid session — record model,
effort, contract sha and CLI version with the results, and archive under
`results/run-<date>-<scenario>/` with a README saying which conclusions the
numbers can and cannot support.

## A — contract tests: does the child honour a read-only contract?

What it measures: a phase whose `Done:` opens with plan-authored tests
(`contract/tests/phase-1/`: one executable, one `wf:contract:` skeleton)
must copy them verbatim, implement until green, and never edit the contract
into passing.

```bash
WORK=$(mktemp -d) && cp -R tests/benchmark/fixture/. "$WORK" \
  && cp -R tests/benchmark/scenarios-6x/contract/. "$WORK/.phased/active/bench/" \
  && (cd "$WORK" && git init -q && git add -A && git commit -qm init) \
  && (cd "$WORK" && claude -p '/wf:execute-phase-agent' --model opus --effort low \
      --permission-mode auto --max-budget-usd 50) \
  ; bash tests/benchmark/scenarios-6x/contract/check.sh "$WORK"
```

Success = plan `[x]`, suite green, in-tree executable test byte-identical to
the plan copy, skeleton's `wf:contract:` lines and test names intact with no
red body left. `contract_edited` (the failure the layer exists to prevent) =
any contract line diverges. n=3 minimum before concluding anything.

## B — doctor blind retro-fit: does a blind author catch a deviation?

What it measures: `doctor/` is a *finished* workflow whose plan promises
"text with <= max_words words is returned unchanged (no suffix)" while the
shipped code appends the suffix at exactly `max_words` — and the in-tree
tests ratify the deviation (the trap a sighted author falls into). The blind
author writes tests from the plan alone; the deviation must surface as a
red, reported finding — never as a fix, never as a reopen.

```bash
WORK=$(mktemp -d) && cp -R tests/benchmark/fixture/. "$WORK" \
  && rm -rf "$WORK/.phased" && cp -R tests/benchmark/scenarios-6x/doctor/.phased "$WORK/" \
  && cp tests/benchmark/scenarios-6x/doctor/truncate.py "$WORK/textutils/truncate.py" \
  && cp tests/benchmark/scenarios-6x/doctor/test_truncate.py "$WORK/tests/test_truncate.py" \
  && (cd "$WORK" && git init -q && git add -A && git commit -qm init) \
  && (cd "$WORK" && claude -p '/wf:doctor' --model opus --effort high \
      --permission-mode auto --max-budget-usd 100 | tee doctor-report.txt) \
  ; bash tests/benchmark/scenarios-6x/doctor/check.sh "$WORK"
```

Machine verdict from check.sh: plan states untouched (still all `[x]`, no
reopen) and no source file modified. Human verdict from the report: does a
finding name the boundary deviation (suffix at exactly max_words)? A doctor
that "fixes" the code or reopens the phase fails the layer's own rule.

## C — coherence judge: does fresh context catch a seeded seam error?

What it measures: `judge/roadmap.md` carries two seeded defects — an
itinerary gap (Macro 2 `Ends at:` is not Macro 3 `Starts from:`) and a
transit violation (Macro 3's scope plausibly destroys the CSV files Macro 2
delivers and Macro 4 requires). The judge, given the mini-scopes alone per
`refs/write-workflow-autonomous.md`, must flag both.

```bash
claude -p "$(cat tests/benchmark/scenarios-6x/judge/prompt.md)" \
  --model opus --effort high --max-budget-usd 50
```

Success = both defects named (itinerary gap blocks the split; the transit
flag names Macro 3). Partial credit is a finding about the judge spec, not
about the run: record which of the two was missed. False positives on the
clean seams count against the judge too — the roadmap has exactly two
defects.

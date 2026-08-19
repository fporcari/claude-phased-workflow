# Context: bench-fixture
Parent: main
Mode: autonomous

## Objective
Add a truncate_words utility to the textutils package, following the existing slugify pattern. The phase's tests were authored at planning time under `.phased/active/bench/tests/phase-1/` — the executable contract.

## Work Plan
- [ ] **Phase 1**: implement truncate_words
  - Pattern reference: `textutils/slugify.py:slugify` (module shape) and `tests/test_slugify.py` (test shape)
  - Files: textutils/truncate.py, tests/test_truncate_contract.py, tests/test_truncate_skeleton.py
  - Decisions: signature `truncate_words(text, max_words, suffix="...")`; if max_words <= 0 raise ValueError; if the text has <= max_words words return it unchanged (no suffix); otherwise join the first max_words words with single spaces and append suffix.
  - Details: copy this phase's contract tests from `.phased/active/bench/tests/phase-1/` verbatim into `tests/`, then create textutils/truncate.py with the function following the slugify.py module shape (module docstring, pure function, no prints) until they are green. The executable test is read-only in its entirety; the skeleton's `wf:contract:` lines and test name are read-only, its red body is yours to implement.
  - Done: the contract tests copied from `.phased/active/bench/tests/phase-1/` pass verbatim; `python3 -m pytest tests/ -q` passes with the ENTIRE suite green; `python3 -m flake8 textutils/ tests/` reports zero errors.

## Notes
Benchmark fixture for the 6.8.0 contract-tests layer (scenario A in
`tests/benchmark/scenarios-6x/README.md`). Do not retune: it is a fixed
stimulus, and changing the task, the contract tests or the config row makes
new numbers incomparable with archived runs.

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |

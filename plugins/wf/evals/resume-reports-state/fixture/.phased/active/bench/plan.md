# Context: bench-fixture
Parent: main
Mode: autonomous

## Objective
Add a truncate_words utility to the textutils package, following the existing slugify pattern.

## Work Plan
- [ ] **Phase 1**: implement truncate_words
  - Pattern reference: `textutils/slugify.py:slugify` (module shape) and `tests/test_slugify.py` (test shape)
  - Files: textutils/truncate.py, tests/test_truncate.py
  - Decisions: signature `truncate_words(text, max_words, suffix="...")`; if max_words <= 0 raise ValueError; if the text has <= max_words words return it unchanged (no suffix); otherwise join the first max_words words with single spaces and append suffix.
  - Details: create textutils/truncate.py with the function following the slugify.py module shape (module docstring, pure function, no prints). Create tests/test_truncate.py following the test_slugify.py style, covering: shorter text unchanged, exact-length text unchanged, longer text truncated with suffix, custom suffix, max_words <= 0 raises ValueError.
  - Done: `python3 -m pytest tests/ -q` passes with the ENTIRE suite green; `python3 -m flake8 textutils/ tests/` reports zero errors.

## Notes
Benchmark fixture for workflow chain measurements. Committed on purpose: `bench.sh`
reads this file both to derive Phase 1's declared Effort and to classify the run's
outcome, and both reads are guarded — a missing plan makes every arm silently
score `honest_fail` at effort `high` instead of failing loudly.

Do not retune this plan. It is the fixed stimulus the archived runs under
`tests/benchmark/results/` measured; changing the task, the Done criterion or the
config row makes new numbers incomparable with the archive. See
`tests/benchmark/results/README.md` for what each historical run actually ran.

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | sonnet |

# Context: bench-fixture
Parent: main
Mode: autonomous

## Objective
Add a truncate_words utility to the textutils package, following the existing slugify pattern.

## Work Plan
- [x] **Phase 1**: implement truncate_words
  - Pattern reference: `textutils/slugify.py:slugify` (module shape) and `tests/test_slugify.py` (test shape)
  - Files: textutils/truncate.py, tests/test_truncate.py
  - Decisions: signature `truncate_words(text, max_words, suffix="...")`; if max_words <= 0 raise ValueError; if the text has <= max_words words return it unchanged (no suffix); otherwise join the first max_words words with single spaces and append suffix.
  - Details: create textutils/truncate.py with the function following the slugify.py module shape (module docstring, pure function, no prints). Create tests/test_truncate.py following the test_slugify.py style.
  - Done: `python3 -m pytest tests/ -q` passes with the ENTIRE suite green; `python3 -m flake8 textutils/ tests/` reports zero errors.
  > Done: suite green, flake8 clean
  > Files: textutils/truncate.py, tests/test_truncate.py

## Notes
Benchmark fixture for the 6.9.0 blind retro-fit layer (scenario B in
`tests/benchmark/scenarios-6x/README.md`). The shipped code deviates from the
Decisions promise at the boundary — text of exactly max_words words gets the
suffix — and the shipped tests ratify the deviation. Do not retune: the
deviation IS the stimulus.

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |

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
  - Done: `python3 -m pytest tests/ -q` passes; `python3 -m flake8 textutils/truncate.py tests/test_truncate.py` reports zero errors.

## Notes
Benchmark fixture for workflow chain measurements.

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | low | sonnet | no |

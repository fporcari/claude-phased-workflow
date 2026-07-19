# Context: bench-fixture
Parent: main
Mode: autonomous

## Objective
Add a truncate_words utility to the textutils package, following the existing slugify pattern.

## Work Plan
- [x] **Phase 1**: implement truncate_words
  > Done: truncate_words(text, max_words, suffix="...") implemented in textutils/truncate.py following the slugify.py module shape; tests added following test_slugify.py style. `python3 -m pytest tests/ -q` (9 passed) and `python3 -m flake8 textutils/truncate.py tests/test_truncate.py` both green.
  > Files: textutils/truncate.py, tests/test_truncate.py
  > Review: no mechanical bugs found by verifier. Judgment notes (not blocking): no test for empty/whitespace-only text or irregular internal whitespace; no input-type validation for non-string text or non-int max_words (consistent with slugify.py's lack of type-checking).

## Notes
Benchmark fixture for workflow chain measurements.

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | low | sonnet | no |

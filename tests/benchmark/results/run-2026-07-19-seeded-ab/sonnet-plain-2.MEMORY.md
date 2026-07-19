# Context: bench-fixture-seeded
Parent: main
Mode: autonomous

## Objective
Add a truncate_words utility to the textutils package, following the existing slugify pattern.

## Work Plan
- [x] **Phase 1**: implement truncate_words
  - Pattern reference: `textutils/slugify.py:slugify` (module shape) and `tests/test_slugify.py` (test shape)
  - Files: textutils/truncate.py, tests/test_truncate.py
  - Decisions: signature `truncate_words(text, max_words, suffix="...")`; if max_words <= 0 raise ValueError; if the text has <= max_words words return it unchanged (no suffix); otherwise join the first max_words words with single spaces and append suffix.
  - Details: create textutils/truncate.py with the function following the slugify.py module shape (module docstring, pure function, no prints). Create tests/test_truncate.py following the test_slugify.py style, covering: shorter text unchanged, exact-length text unchanged, longer text truncated with suffix, custom suffix, max_words <= 0 raises ValueError.
  - Done: `python3 -m pytest tests/ -q` passes with the ENTIRE suite green; `python3 -m flake8 textutils/ tests/` reports zero errors.
  > Done: truncate_words implemented in textutils/truncate.py following slugify.py's module shape; tests/test_truncate.py covers all 5 cases from the phase spec; full suite (10 tests) green, flake8 zero errors.
  > Files: textutils/truncate.py, tests/test_truncate.py, textutils/__init__.py (added "truncate" to REGISTRY — required by tests/test_registry.py, which asserts REGISTRY lists every module in the package)
  > Review: test_truncate.py has no empty-string (or whitespace-collapsing) test case, unlike test_slugify.py's test_empty — implementation handles both correctly, but full test-shape parity with the pattern reference is not 100%. Judgment call on whether to add it; not blocking.

## Notes
Benchmark fixture (seeded variant) for workflow chain measurements.

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | low | sonnet | no |

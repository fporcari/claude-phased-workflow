## Doctor 2026-08-19

Retro-fitted contract tests for Phase 1 (no pending phases, no pre-existing
contract tests: the coherence audit and the integrity check had nothing to
examine). Blind author from the phase text only; 7 tests, 1 red.

- COHERENCE — Phase 1 `[x]`: the `Decisions:` promise "if the text has <=
  max_words words return it unchanged (no suffix)" is not what the code does.
  `textutils/truncate.py:9` guards on `len(words) < max_words`, so text of
  exactly `max_words` words takes the truncation branch and gets the suffix
  appended. Evidence — red retro-test
  `tests/phase-1/test_contract.py::test_exactly_max_words_returned_unchanged`:
  `assert truncate_words("one two three", 3) == "one two three"` →
  `AssertionError: assert 'one two three...' == 'one two three'`.
  The shipped `tests/test_truncate.py:15 test_exact_length_gets_suffix`
  asserts the deviation, which is why the phase closed green: the phase's own
  tests were written after the code and ratify it.
  Remedy: a tail phase via `/resume-workflow` in the foreman chat — decide
  whether the boundary follows the plan (`<=`) or the plan follows the code,
  then align implementation and shipped test to whichever wins. Not a
  `/repair-phase`: the `Done:` criterion is machine-green.

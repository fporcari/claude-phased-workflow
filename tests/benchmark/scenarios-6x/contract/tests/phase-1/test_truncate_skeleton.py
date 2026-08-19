"""Phase 1 contract — skeleton precision, authored at planning time.

The test name and the wf:contract: lines are read-only; the red body is the
executing phase's work.
"""
import pytest


def test_nonpositive_max_words_rejected():
    # wf:contract: truncate_words(text, max_words, suffix="...") raises
    # wf:contract: ValueError for max_words <= 0, zero included
    pytest.fail("phase 1 pending")

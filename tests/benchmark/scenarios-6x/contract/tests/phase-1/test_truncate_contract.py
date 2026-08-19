"""Phase 1 contract — executable precision, authored at planning time.

Read-only for the executing phase in its entirety: red until
textutils/truncate.py exists and honours the settled signature.
"""
from textutils.truncate import truncate_words


def test_short_text_returns_unchanged():
    assert truncate_words("uno due", 5) == "uno due"


def test_long_text_truncates_with_suffix():
    assert truncate_words("a b c d e", 3) == "a b c..."


def test_custom_suffix():
    assert truncate_words("a b c d", 2, suffix=" [cut]") == "a b [cut]"

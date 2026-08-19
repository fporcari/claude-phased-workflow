import pytest

from textutils.truncate import truncate_words


def test_zero_max_words_raises():
    with pytest.raises(ValueError):
        truncate_words("one two three", 0)


def test_negative_max_words_raises():
    with pytest.raises(ValueError):
        truncate_words("one two three", -1)


def test_fewer_words_than_max_returned_unchanged():
    assert truncate_words("one two three", 5) == "one two three"


def test_exactly_max_words_returned_unchanged():
    assert truncate_words("one two three", 3) == "one two three"


def test_more_words_than_max_truncated_with_suffix():
    assert truncate_words("one two three four", 2) == "one two..."


def test_custom_suffix_honoured():
    assert truncate_words("one two three four", 2, suffix=" [more]") == "one two [more]"


def test_default_suffix_is_ellipsis():
    assert truncate_words("alpha beta gamma", 1) == "alpha..."

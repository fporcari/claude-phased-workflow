"""Tests for truncate_words — written by the phase, after the code.

These ratify the code's own boundary behaviour instead of the plan's promise:
the exact trap the blind retro-fit exists to catch.
"""
import pytest

from textutils.truncate import truncate_words


def test_shorter_text_unchanged():
    assert truncate_words("uno due", 5) == "uno due"


def test_exact_length_gets_suffix():
    assert truncate_words("a b c", 3) == "a b c..."


def test_longer_text_truncated():
    assert truncate_words("a b c d e", 3) == "a b c..."


def test_custom_suffix():
    assert truncate_words("a b c d", 2, suffix=" [cut]") == "a b [cut]"


def test_nonpositive_max_words_rejected():
    with pytest.raises(ValueError):
        truncate_words("a b", 0)

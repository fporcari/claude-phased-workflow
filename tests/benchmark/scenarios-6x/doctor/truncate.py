"""Word-truncation utilities for the textutils package."""


def truncate_words(text, max_words, suffix="..."):
    """Return *text* cut to *max_words* words, *suffix* appended when cut."""
    if max_words <= 0:
        raise ValueError("max_words must be positive")
    words = text.split()
    if len(words) < max_words:
        return text
    return " ".join(words[:max_words]) + suffix

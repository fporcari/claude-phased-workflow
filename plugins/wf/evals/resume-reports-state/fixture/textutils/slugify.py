"""Slug utilities for the textutils package."""

import re
import unicodedata


def slugify(text, separator="-"):
    """Return an ASCII slug of *text*, words joined by *separator*."""
    normalized = unicodedata.normalize("NFKD", text)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii")
    words = re.findall(r"[A-Za-z0-9]+", ascii_text.lower())
    return separator.join(words)

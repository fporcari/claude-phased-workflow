#!/usr/bin/env python3
"""Guard: the dashboard stays an alternative surface, never a step.

Two rules over the skills and refs the plugin ships:

  1. Every mention of the dashboard SURFACE states, or cites, what happens
     without it. A mention qualifies by carrying a fallback clause within a
     few lines, or by citing the single source that carries one
     (``board.md`` -> *The dashboard, where it exists*). The generic English
     word — "a page, a form, a dashboard" in the ``ui`` tag — is not a
     surface mention and is not checked.
  2. No file makes the dashboard a precondition of carrying work forward.
     A skill that says "open the dashboard, then continue" has turned an
     optional surface into a mandatory one, which is exactly what the
     workflow's `Must not break:` header forbids.

Used by S51 both as the check and, re-run on two mutated copies, as the
proof that it fails on each defect it describes.

Usage: check_optional_surface.py <dir> [<dir> ...]
Exit 0 clean, 1 with one violation per line on stdout.
"""
import os
import re
import sys

# The surface, not the word: `/wf:dashboard`, the possessive that names the
# server, and the title of the section that owns the rule.
SURFACE_RE = re.compile(
    r'wf:dashboard|the dashboard\'s|The dashboard, where it exists',
    re.IGNORECASE)

# What happens when it is not there — the clause the rule demands. "no server
# running" is deliberately NOT here: it states optionality, not the behaviour
# that replaces the surface, and accepting it would let the real fallback
# clause be deleted without the guard noticing.
FALLBACK_RE = re.compile(
    r'fallback|no dashboard|not opened|absent', re.IGNORECASE)

# Citing the single source counts: the fallback lives there, once. The
# italicised form is the citation; the bare heading is the section itself, and
# a section that cites itself would exempt exactly the file that owes the rule.
CITES_RE = re.compile(r'\*The dashboard, where it exists\*')

# The dashboard as a prerequisite for going on.
PRECONDITION_RE = re.compile(
    r'dashboard[^.\n]*?\b(then continue|then proceed|before continuing'
    r'|before proceeding|must be open|is required|wait for)'
    r'|\b(requires?|needs?|wait for|only after) the dashboard',
    re.IGNORECASE)

WINDOW = 6


def violations(roots):
    bad = []
    for root in roots:
        for dirpath, _, names in sorted(os.walk(root)):
            for name in sorted(names):
                if not name.endswith('.md'):
                    continue
                path = os.path.join(dirpath, name)
                with open(path, encoding='utf-8') as f:
                    lines = f.read().splitlines()
                own = os.sep + 'dashboard' + os.sep in path
                for i, line in enumerate(lines):
                    if PRECONDITION_RE.search(line):
                        bad.append(
                            '%s:%d: makes the dashboard a precondition: %s'
                            % (path, i + 1, line.strip()))
                    if own or not SURFACE_RE.search(line):
                        continue
                    near = lines[max(0, i - WINDOW):i + WINDOW + 1]
                    if any(FALLBACK_RE.search(n) or CITES_RE.search(n)
                           for n in near):
                        continue
                    bad.append(
                        '%s:%d: names the dashboard with no fallback stated '
                        'or cited: %s' % (path, i + 1, line.strip()))
    return bad


if __name__ == '__main__':
    found = violations(sys.argv[1:])
    if found:
        print('\n'.join(found))
    sys.exit(1 if found else 0)

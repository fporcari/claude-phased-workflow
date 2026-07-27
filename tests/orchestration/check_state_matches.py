#!/usr/bin/env python3
"""Guard: phase-state matching in the launcher is single-source.

Any line of the launcher that matches a phase-state bracket
(a literal ``\\[`` opening ``[ x!~>]``) must be one of the four
single-source helpers (phase_re / phase_count / phase_any /
phase_lines) — or, for non-grep matchers such as the awk block in
first_bang_block(), carry the ``\\*\\*Phase`` anchor so a prose
``- [!]`` bullet in a ``## Notes`` section can never be read as a
phase. grep-based matches get no anchor exemption: greps must go
through the helpers, full stop.

Used by S18 both as the check and, re-run on a mutated copy, as the
proof that the check fails on the defect it describes.

Usage: check_state_matches.py <launcher.sh>
Exit 0 clean, 1 with one violation per line on stdout.
"""
import re
import sys

HELPER = re.compile(r'^(phase_re|phase_count|phase_any|phase_lines)\(\)')
STATE = re.compile(r'\\\[\[?[ x!~>]')   # a literal \[ opening a state match
ANCHOR = re.compile(r'\\\*\\\*Phase')


def violations(path):
    bad = []
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines()
    for i, line in enumerate(lines, 1):
        if not STATE.search(line):
            continue
        if HELPER.match(line.strip()):
            continue
        if 'grep' in line:
            bad.append('%d: %s' % (i, line.strip()))
        elif not ANCHOR.search(line):
            bad.append('%d: %s' % (i, line.strip()))
    return bad


if __name__ == '__main__':
    found = violations(sys.argv[1])
    if found:
        print('\n'.join(found))
    sys.exit(1 if found else 0)

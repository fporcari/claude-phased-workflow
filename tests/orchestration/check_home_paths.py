#!/usr/bin/env python3
"""Guard: skills and refs address the plugin, never ~/.claude.

The plugin ships its own scripts/ and refs/; a skill or ref that still
points a reader at ``~/.claude/`` (or ``$HOME/.claude/``) sends them to
a path the plugin no longer owns. The one legitimate mention is
refs/common.md naming ``~/.claude/settings.json`` as a file auto mode
must not self-modify — a different file, and a description, not a path
the plugin resolves.

Used by S21 both as the check and, re-run on a mutated copy, as the
proof that the check fails on the defect it describes.

Usage: check_home_paths.py <dir> [<dir> ...]
Exit 0 clean, 1 with one violation per line on stdout.
"""
import os
import sys


def violations(roots):
    bad = []
    for root in roots:
        for dirpath, _, names in os.walk(root):
            for name in names:
                p = os.path.join(dirpath, name)
                with open(p, encoding='utf-8') as f:
                    lines = f.read().splitlines()
                for i, line in enumerate(lines, 1):
                    if ('~/.claude/' not in line
                            and '$HOME/.claude/' not in line):
                        continue
                    if (line.count('~/.claude/') == 1
                            and '~/.claude/settings.json' in line
                            and '$HOME/.claude/' not in line):
                        continue
                    bad.append('%s:%d: %s' % (p, i, line.strip()))
    return bad


if __name__ == '__main__':
    found = violations(sys.argv[1:])
    if found:
        print('\n'.join(found))
    sys.exit(1 if found else 0)

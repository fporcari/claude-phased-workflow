# 5.5.0 — the rename reaches the guide, and busts the plugin cache

Two leftovers from the `/grill` → `/scope-workflow` rename (5.4.0).

The prompting guide still named the old command in both its markdown and its HTML
twin: the rename updated the release notes and the change note but not the guide.

The version bump is the real fix for the installed copy. The plugin cache is keyed by
version (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>`), so republishing
changed contents under 5.4.0 left every machine that had already fetched 5.4.0 on the
pre-rename tree, skill `grill` included. Contents under a released version are
immutable; a rename needs a new number.

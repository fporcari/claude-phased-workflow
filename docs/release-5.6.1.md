# 5.6.1 — the board's controls become mandatory, and the chip opens in the right tree

Two defects in 5.6.0's board, both found by looking at a real rendered grid instead of
at the clause that was supposed to produce it.

## The controls were described, not required

5.6.0 said *"two controls belong on it"* and left it there — no imperative, no
position. A grid rendered as a clean table has no natural cell for a button, so the
controls went missing without any rule being violated: the skill got a correct-looking
table with the phase, the state, the `Run:` hint and the file count, and nothing to
press.

The clause now states the identity — **the board is the grid plus its two controls; a
grid without them is not the board, it is the old text report set in a table** — and
fixes where each one goes, since "somewhere on it" is what produced a table with
neither:

- refresh in the header row, next to the phase count;
- the launch command in the eligible phase's own row, in full, with a copy button.

The chip is now created **always with the grid and never at the renderer's
discretion**.

A general lesson worth keeping: a clause that describes what an output should contain
does not constrain it. The load-bearing ones in this plugin are written as identities
or prohibitions, and are guarded by a mutation-proven assert — this one had neither.

## The chip opened in the wrong tree

`spawn_task` takes a `cwd`, and 5.6.0 never passed one. On a plan living in a worktree
the chip therefore opened its session in the current checkout: the phase started in the
wrong tree, and the session's opening move was to offer to re-anchor it to the right
branch — a repair for damage the chip itself had just caused.

The chip is now born in the plan's own root, the one Step 1 resolved, which is the same
anchoring rule every other command in this skill already followed (`common.md` →
*Plan location*: `git -C <plan root>`, every path against that root, never against the
cwd). A tool added later simply had not been held to it.

**A plan whose branch has no checkout gets no chip at all** — the command stays in the
row and the skill says the worktree has to exist first. That matches what the other
skills do with a checkout-less plan: say so and stop, rather than improvise a location.

## Note on upgrading

Contents under a released version are immutable in the plugin cache
(`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>`), so this correction needs
its own number to reach a machine that already fetched 5.6.0. And `claude plugin update`
applies on restart: a chat open across the update keeps running the copy it started
with, which is worth knowing before concluding that a clause did not work.

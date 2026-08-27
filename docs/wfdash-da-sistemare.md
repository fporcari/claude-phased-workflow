# wfdash — what the graft left open

Input for the next workflow. The graft (`6.25.0`, branch `wf/wfdash-optional-surface`)
closed the perimeter and took the server's authority away; these are the findings it
did NOT fix, collected here because they were recorded in `.phased/`, which the
consolidation drops from this branch.

Two sources: the Extended pre-commit review of the whole diff (12), and Phase 8's
coherence review plus Phase 4's own notes (11). Ranked, not grouped by source.

## Blocking for anyone running two dashboards

1. **The session cookie carries no port**, so two dashboards on `127.0.0.1` evict each
   other — open the second and the first answers 403, and recovering it needs a restart
   because its one-shot is spent. Reproduced with one cookie jar across ports 8789/8790.
   A regression of Phase 1: with the token in a `<meta>` tag each page carried its own.
   `server.py:86`. Fix: the port in the cookie name, plus the multi-server test that does
   not exist — `test_perimeter_closed.py` drives a single in-process handler and cannot
   see this.

2. **The `one unattended run per plan` guard was deleted and never re-established.**
   Two presses queue two identical `run-workflow` requests (reproduced), so the chat
   draining the queue sees two orders to run on one working tree — the invariant the
   removed pidfile+ps guard protected. `server.py:217`. Fix: `launch` refuses when
   `outbox.read(repo)` already holds a pending `run-workflow`.

## Correctness

3. **`--drain` loses a request.** `read` then `remove` as two unsynchronised steps: a
   press landing between them is destroyed silently. `_LOCK` is a `threading.Lock` and
   the drain runs in another process. `outbox.py:82`. Fix: rename the file aside and read
   the rename, or take a cross-process lock.

4. **`self.grant` is never cleared**, so under HTTP/1.1 keep-alive every later response
   on the connection repeats `Set-Cookie`. Harmless today; a per-request grant would
   leak the previous one. `server.py:141`.

5. **`selection()` indexes its payload without a shape check** — a parse-able payload
   missing `phases` raises inside the loop and the endpoint answers 500 instead of
   degrading to "no plan". `core.py:426`.

6. **The token is compared with `==`**, not `secrets.compare_digest`, and the module
   already imports `secrets`. `server.py:154`.

7. **`check_state_matches.py` cannot see an escaped `\*\*Phase`**, so a marker regex
   without the state class passes the guard. Widening it flags the pre-existing
   `server.py:76` block-slicer, a second plan-format reader — so the widening needs a
   decision first: line spans in the `--json` payload, or a declared exemption.

8. **`plan_shape.recommendation` is unread.** `server.launch` and the page still act on
   `blocked_by` alone, so the five-outcome distinction `--json` restored stops at the
   shape and never reaches a user.

9. **The page lost the phase tags** — `title` no longer carries the backticked tag and
   nothing renders the payload's `tags`.

10. **`parse_lines` resets the current phase on `## ` headings**, so a `>` note after a
    heading no longer attaches to the last phase. Correct per S18 inertness, but no
    assert pins it.

## Reuse, efficiency, minimality

11. **`threading.Lock` guarding a file two processes write** reads as protection and
    gives none. `git-workflow/plugins/git-workflow/server/safejson.py` is the in-house
    pattern: per-path thread lock plus `fcntl.flock`, `mkstemp`+`fsync`+`os.replace`.
    `outbox.py:32`.

12. **`selection()` spawns a fresh interpreter per plan read** — 28 ms measured, with 5
    `read_plan` sites in `server.py` on a 5-second poll. `importlib` loads
    `next-phase.py` once despite its hyphen, or the payload caches per plan mtime.
    `core.py:415`.

13. **`parse_plan` / `parse_plan_text` only unpack `selection()`** — the "no wrappers
    that only delegate" rule. `core.py:432`.

14. **`wHeaders()` adds no header** since the cookie move: a constant returned through
    three call sites under a name that promises otherwise. `index.html:490`.

15. **`GET /api/agent` is routed and authenticated with no caller** — inherited from the
    delivered source, not orphaned by a phase. Delete it, or document its client.

## Documentation and packaging

16. **`README.md`'s changelog table skips 6.24.0** while `CHANGELOG.md` carries it. Not
    introduced here — already missing before Phase 7. S42 asserts the shipped version and
    the CHANGELOG's first heading, never the table's continuity.

17. **`-P` and the wfdash README justify the no-scan behaviour by a `.claude/launch.json`
    this repo does not ship** — it belonged to the delivered source's own repository and
    was not imported, and `skills/dashboard/SKILL.md` never passes `-P`. Ship it, or
    restate why `-P` exists.

18. **Phase 6 left a note claiming the plan was written when the suite topped out at
    S33.** False: the plan was written the same morning against a suite already at S50,
    and took the number from a stale README. The note misreports its own history.

## Process notes worth keeping, not code

- **Phase 3 renamed `COOKIE_NAME`** — Phase 1's territory — and updated Phase 1's
  contract test to match. The assert is unchanged so no guarantee was weakened, but a
  phase editing an earlier phase's guarantee is how one erodes.
- **A guard whose glob is held in a scalar never expands**, receives one bogus path,
  produces empty output and its assert PASSES: green that verified nothing. This bit
  Phase 4 under zsh. S51's `[ "$S51_N" -ge 12 ]` is the shape that prevents it.
- **A module named after a stdlib one** (`queue.py`) breaks distant consumers, not
  itself, because this repo puts directories at the head of `sys.path` for its tests.
- **The plan carried eight defects of its own and the delivered source none.** Root
  cause of the worst: a stale README was trusted in place of `run_tests.sh`.

## The QA nobody has run

`.phased/done/wfdash-optional-surface/verify.md` holds four `now` checks that no browser
has ever exercised — the perimeter is proven in-process plus one curl pass. They do not
survive this branch either; the four are: the page loads and polls with a clean address
bar after the first load; the two buttons queue and hand back a command respectively;
the `Verify:` panel lists steps with no checkbox; the four button labels match what
`docs/wfdash.md` claims.

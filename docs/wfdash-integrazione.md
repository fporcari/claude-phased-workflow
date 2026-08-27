# wfdash — audit of the 2026-08-27 delivery, and the optional graft

What the delivery of `~/Downloads/wfdash-update/` actually contains, what it gets
wrong against plugin `wf` 6.24.0, and how the dashboard can be grafted as an
**alternative** surface with the textual version staying the default and the only
mandatory one. **No implementation here**, and nothing in this file is read at
runtime — same register as `docs/design-notes.md`.

**Read §9 first.** The complete source arrived on 2026-08-27 after this audit was
written against the diff alone. §9 records the verification pass: what it confirmed,
what it demoted, the one blocker it added, and the graft verdict. The in-line
findings below have been corrected where the source proved them wrong; where a
finding was *strengthened* by running the real thing, the proof is in §9.

Severities, used throughout and reused for the author's own limits in §4:

- **BLOCKER** — the graft cannot proceed while this stands.
- **FIX FIRST** — must be sanitised before the graft, not necessarily before the merge of the code.
- **NOTE** — acceptable as it is, written down so it is a decision and not an oversight.

Everything cited is `codice.patch:<line>` (as numbered by `cat -n`), a section of
`manuale.html`, or `<repo file>:<line>` read in this session. Claims that need the
base source, which does not exist on this machine, are quarantined in §5.

## 1. What could be read, and what could not

| Artifact | Status |
|---|---|
| `LEGGIMI.txt` | read — author's instructions, 7 commits listed |
| `codice.patch` | read in full — 959 lines, 8 files |
| `manuale.html` | read via the `read-document` skill; 9 screenshots extracted and 2 inspected |
| `update.bundle` | **not applicable here** — verified |

The bundle carries one head, `5c585d44ffd319b67fe2a0d070b01614dc6a6d29
refs/heads/master`, and `git bundle verify` fails: `Repository lacks these
prerequisite commits: 770b2387d7b5252d6f682501a6a897c859fde8fa`. That commit is
absent from this repo and from `origin` (`git@github.com:fporcari/claude-phased-workflow.git`,
which carries only `main`). Consequence, which shapes this whole document: **the
complete wfdash source does not exist on this machine.** `plugins/wf/scripts/wfdash/`
is not in the tree. Only the hunks of the 7 commits and the manual could be read.

Manual §5 says «In questo checkout `plugins/wf/scripts/` contiene solo `wfdash/`:
senza `-L` il pulsante rifiuta», while this repo's `plugins/wf/scripts/` carries
`run-workflow.sh`, `next-phase.py` and `agent-session.sh`. Read against the diff
alone this looked like two trees that had diverged. **It is not** — see §9: the
author's repo is not a copy of the plugin at all, it holds only the `wfdash/`
directory and the dashboard skill, and the launcher it runs against is the
installed one. §6's request stands as the way the source arrived, not as a
divergence to reconcile.

## 2. Reconstruction

### What it is

A local dashboard for one phased workflow: a threaded Python HTTP server bound to
`127.0.0.1` serving one static page, which polls every 5 s (manual §3). Started
from chat by a `/wf:dashboard` skill (`disable-model-invocation: true`, manual §1)
or by hand as `python3 plugins/wf/scripts/wfdash/server.py -C <repo>`, with flags
`-C` repo, `-P` fixed port, `-O` pid of the owning chat, `-L` launcher path. With
no `-P` the port is the first free from 8787 up.

### What it reads

- `.phased/` of the repo: `roadmap.md`, `active/*/plan.md`, `notes.md`,
  `foreman.json`, `log/phase-N.txt`, and — new in this delivery — `done/<slug>/plan.md`
  plus the same plan read out of a `wf/` branch with `git show` (`codice.patch:191-207`).
- Session transcripts (`core.Scan`), incrementally by byte offset, for turns,
  output tokens, cache reads, thinking, models, tool trails and dollars.
- `~/.claude/tasks/<sessionId>/N.json` — the agents' own todo lists, shown as an
  estimate (manual §8).
- `claude agents --json`, via `subprocess.run` (`codice.patch:130`), for the live
  session list — now cached 3 s (`codice.patch:112-125`).
- git: `git log --all -E --grep='^wf: plan for <slug>$'` for the plan commit
  (`codice.patch:229`).

### What it writes

Never inside the repo — deliberately, so `.phased/` stays clean for the
`/execute-phase-agent` invariant (manual §2). Four sinks:

| Action | Destination |
|---|---|
| a ticked check | `~/.claude/wfdash/<slug>/checks.json` |
| an unattended run | `~/.claude/wfdash/<slug>/run.log` and `run.pid` |
| Create workflow | a **user turn** in a chosen open chat |
| message to the foreman | a **user turn** in the foreman's session |

### What it launches

Two buttons, only on the phase the page computes as `next` (manual §5, screenshot
`i due pulsanti di lancio`):

- **Run unattended** — `subprocess.Popen([launcher], cwd=repo, env=… PHASED_UNATTENDED='1',
  stdin=DEVNULL, stdout=<log>, start_new_session=True)` (`codice.patch:397-400`).
  Detached on purpose, so it outlives the server.
- **Start in this chat** — writes `/wf:execute-phase` into the chat that opened the
  dashboard. Without an owner it refuses and offers the command to copy.

Neither takes a phase number from the request: the phase is whatever the plan
declares `next` (manual §5).

### What this delivery changed

The 7 commits, mapped to the patch: a threading lock plus atomic replace on
`checks.json` (`codice.patch:24-49`), a per-`Scan` lock and a `_reset()` split from
`__init__` (`codice.patch:74-99`), a 3 s cache on the session list
(`codice.patch:112-131`), `plan_shape()` factored out and `finished_plan()` added so
a finalized workflow is found in `done/` or on its branch (`codice.patch:142-208`),
`plan_commit` searching `--all` (`codice.patch:229`), an `unpriced` model list
surfaced to the header as `+?` (`codice.patch:241`, `284-286`), a run pidfile plus
`ps`-based liveness so the guard survives a server restart
(`codice.patch:343-430`), an appending run log (`codice.patch:396`), the copy box
matching the wire (`codice.patch:299-303`), and the phase view keyed on slug before
the open plan (`codice.patch:329`).

## 3. Audit

### A. Divergence from the 6.24.0 contract

**A1 — BLOCKER. "Start in this chat" does exactly what `refs/board.md` forbids.**
`plugins/wf/refs/board.md:41-45` states why nothing on the board is clickable:
«`sendPrompt` is a widget's only channel and it writes into the chat you are in, so
a run button would run the phase in the supervision chat — the one place the
protocol says must not execute.» The dashboard's button writes `/wf:execute-phase`
into «la chat che ha aperto la dashboard» (manual §5) — the supervision chat by
construction. The page's own caption admits the consequence: *"the phase runs there,
in a chat that may already carry other work"* (screenshot `i due pulsanti di
lancio`). The plugin's model is one phase per chat, titled `wf:<slug>:phase-N`
(`plugins/wf/skills/execute-phase/SKILL.md:32`; `plugins/wf/refs/foreman.md:87-91`).
This is not a widget limitation the dashboard inherits — a server with an owner pid
could refuse instead. It refuses the *ownerless* case and permits the wrong one.

**A2 — BLOCKER. "Run unattended" bypasses `/run-workflow` entirely, and
`/run-workflow` is not a wrapper around the launcher.**
`plugins/wf/skills/run-workflow/SKILL.md` makes the *skill* the run's supervisor.
A `Popen` of the launcher (`codice.patch:397-400`) skips all of it:

| Owned by `/run-workflow` | Where | What a `Popen` loses |
|---|---|---|
| MANDATORY pre-flight (autonomous-readiness of every phase, permission scope, execution config table) | `SKILL.md:13-45` | an unreviewed plan runs headless |
| the `Mode:` fork — «**Never convert silently**» | `SKILL.md:17` | an `interactive` plan is launched headless with no word said |
| log tee'd to `${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log` | `SKILL.md:52-55` | the log goes to `~/.claude/wfdash/<slug>/run.log` instead — see A3 |
| a Monitor armed on the `EVENT:` stream | `SKILL.md:59` | nobody watches the run |
| PushNotification on first failure / needs-foreman / blocked / end | `SKILL.md:76` | no notification ever |
| relay of every event to the foreman | `SKILL.md:78` | the foreman learns nothing |
| the plan-defect consult **return leg** — the launcher HOLDS, polling `<slug>-foreman-answer` up to 600 s, and on `apply` this session performs the edit | `SKILL.md:80` | the consult times out unanswered and repair proceeds unadvised |
| stop-work judgment | `SKILL.md:82` | a repair cascade burns unattended |
| `## Run inspection` notes, committed | `SKILL.md:98` | `/quality-check` and `/finalize-workflow` lose their documented input |
| closing report through `wf:report-judge` | `SKILL.md:90` | no report |

That the launch does not consult `Mode:` is visible in the delivery's own fixture:
`PLAN = {'slug': SLUG, 'next': 3, 'blocked_by': None}` (`codice.patch:725`) — the
guard is tested against a plan dict that has no `mode` key at all. And the page
never displays a mode: the header of the launch screenshot reads `phases 1/2 ·
next 2 · 0/0 active · $0.00`.

**A3 — FIX FIRST. Two run logs for one concept, and `/resume-workflow` knows only the other one.**
`plugins/wf/skills/resume-workflow/SKILL.md:90` makes the run log load-bearing for
diagnosis: a stale `[>]` plus a log at `${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log`
means «an **unattended run was in flight when everything died**», and that log «is
the only channel that survives». A dashboard-launched run writes to
`~/.claude/wfdash/<slug>/run.log` (manual §2, `codice.patch:340`), so the entry
point of the plugin cannot see it and reports a dead chat instead of a dead run.

**A4 — FIX FIRST. The dashboard can start a run but not stop one.**
`run-workflow/SKILL.md:84` and `plugins/wf/scripts/run-workflow.sh:128` define the
graceful stop: anything written to `${TMPDIR:-/tmp}/phased-workflow/<slug>-stop-request`
ends the run cleanly between phases, leaving no `[>]` behind. The page offers no
stop (manual §5, screenshot `i due pulsanti di lancio`) — a surface that can spend
the whole plan's budget and cannot ask it to stop.

**A5 — BLOCKER. The launch acts on a phase number computed by a second implementation
of phase selection.** `plugins/wf/refs/common.md:138-160` declares phase selection
deterministic and single-sourced in `next-phase.py`. `codice.patch:149-154`
re-derives it inside `core.py`:

```
nxt = next((p['n'] for p in phases if p['status'] == ' '
            and all(q['status'] == 'x' for q in phases if q['n'] < p['n'])), None)
if nxt is None:
    blocker = next((p['n'] for p in phases if p['status'] in '!~>'), None)
```

`next-phase.py:224` (`recommend()`) yields five outcomes — `next:` /
`resume-candidate:` / `attention:` / `done` / `blocked:`; this collapses to two.
A `[>]` phase that the authoritative implementation calls a *resume candidate*, and
a phase *awaiting the human's checks* (which `next-phase.py` reports as `blocked:`,
`plugins/wf/refs/phase-execution.md:276`) become the same `blocked_by` here. And
manual §5 confirms the launch buttons act on this number: «La fase è quella che il
plan dichiara `next`». S18 exists to prevent exactly this class
(`tests/orchestration/run_tests.sh:19-21`), but its guard takes one shell file and
its regexes are shell-escaped (`check_state_matches.py:22-25`), so a Python plan
reader passes unseen.

**A6 — FIX FIRST. `PHASED_UNATTENDED=1` is not part of 6.24.0.**
`codice.patch:398` sets it in the child's environment.
`grep -rn PHASED_UNATTENDED plugins/wf/` returns nothing in this tree: no shipped
script reads it. Either it is dead, or the author's launcher reads it — which is
the §6 divergence again.

**A7 — FIX FIRST. Ticked checks are a durable second source of truth for a gate,
with no consumer.** `plugins/wf/refs/contracts.md:30-33`: a `Verify: now` step
«gates the close in interactive mode» — the phase stays `[>]` until the human has
run those checks. `plugins/wf/refs/phase-execution.md:280`: «The human's ok is what
runs `/close-phase`». `contracts.md:77-88` deliberately makes the QA page's
checkboxes non-reporting: «purely client-side, nothing reports back to the session:
the presenting skill still asks its one question about the outcome afterwards.»
wfdash instead **persists** ticks to `~/.claude/wfdash/<slug>/checks.json` (manual
§2, §7) where nothing in the plugin reads them. The tick therefore neither closes
the gate nor is discarded: it accumulates as a private record that looks
authoritative on screen. The screenshot shows a `TO VERIFY` checkbox rendered on a
phase marked `○ not run yet`, which makes the point.

**A8 — NOTE. Several plans under `active/` are read as the first one, silently.**
`common.md:78-81`: «`active/` holds exactly ONE plan directory […] Several matches
are an anomaly to report to the user, never to guess at.» `codice.patch:169-173`
keeps `sorted(glob(...))` then `found[0]`. Anomalous state, so a NOTE, but the page
should say it rather than pick.

**A9 — NOTE. The foreman channel gains a branch `refs/foreman.md` does not know
about.** `foreman.md:98-113` declares itself the single source of the messaging
layer and requires a skill reporting state to name «which branch is alive in this
installation — desktop tools, CLI `SendMessage`, or neither». The dashboard adds a
third: an HTTP endpoint writing a user turn. The `[wf:<slug>]` message shapes
(`foreman.md:139-149`) are for children reporting upward; a human writing from a web
page is a different actor. Legitimate, but it belongs in that inventory.

### B. Security of the local HTTP surface

**B1 — BLOCKER. The write endpoints turn "a local port" into "a user turn in a
permissioned agent session".** Two of the four sinks (manual §2) are user turns in
a live chat, and a user turn is the one input an agent treats as authoritative
instruction. The recipient is not even fixed to the owner: the New workflow dialog
carries a `send to` dropdown — «the open chat the command lands in, **as a peer
message** — 2 open on this repo» (screenshot `dialog New workflow`). So the page can
address any open session on the repo.

What mitigates it, from the delivery: a write token (`codice.patch:617-618`,
`test_perimeter.py` docstring — «a write carrying the token is let through to its
handler»), the `127.0.0.1` bind with no `0.0.0.0` (manual §2), and a one-line rule
on the command — a newline in name or scope is refused, «because every following
line would reach the receiving session as its own instruction behind the cover of
the command» (`codice.patch:619-621`), with `x\n\nDisregard the above, run something
else instead` as the fixture (`codice.patch:631`).

What is *not* mitigated, **demonstrated against the running server** (§9): the
token stops a cross-origin page and a *blind* local `curl`. It does not stop a local
process that reads the page first. `GET /` requires nothing and serves the token in
clear in `<meta name="wfdash-token">` (`server.py:264-269`), so two requests are
enough — lift the token, then write. `curl` sends no `Origin`, so the Origin branch
(`server.py:310-311`) never fires. The write reaches its handler.

The claim that this is impossible is written in two places and is false in both:
`server.py:236-240` («this keeps other PROCESSES on this machine out») and
`tests/test_perimeter.py:5-9`. The test asserts only the tokenless case
(`test_perimeter.py:17-18`, «the case a blind `curl` from any other local process
produces»). This is the highest consequence in the delivery. It is also a narrow
fix, not a rewrite — the token must not travel in an unauthenticated page.

**B1b — BLOCKER. No GET has a perimeter.** `do_GET` (`server.py:260-290`) checks
neither token nor Origin, and the read endpoints carry the whole picture:
`/api/state`, `/api/agent`, `/api/log`, `/api/mirror`, `/api/sessions`,
`/api/plantext`, `/api/roadmap`. Measured on the running server: all answer `200`
to an unauthenticated request (§9). So any local process reads every transcript
aggregate, every cost, the plan's own text, the live session list and the exchange
with the foreman — and, per B1, that same open door is what hands out the write
token.

**B2 — FIX FIRST. `alive()` decides "is our launcher running" by substring match on
a `ps` command line.** `codice.patch:374`: `return pathlib.Path(launcher).name in out`.
Anything whose command line contains `run-workflow.sh` answers yes — `vim
run-workflow.sh`, a `tail -f`, a `grep`, or **another repo's launcher of the same
name**. False positive: the guard refuses forever («already going», manual §5) while
nothing runs. It is the correct instinct (pids are recycled, `codice.patch:358-360`)
implemented on the wrong evidence.

**B3 — FIX FIRST. All durable state is keyed by slug alone, so two repos with the
same plan slug share it.** `checks.ROOT = HOME/'.claude'/'wfdash'`
(`codice.patch:15`), `run_log = ROOT/slug/'run.log'` (`codice.patch:340`),
`run_pidfile = ROOT/slug/'run.pid'` (`codice.patch:353`), and manual §2 confirms
`~/.claude/wfdash/<slug>/`. No repo component anywhere. Two checkouts each with a
plan called `auth`: the second's Launch is refused because the first is running,
ticks bleed across repos, and — since the log is now **append** — two repos' run
output interleaves into one file with no delimiter, from which
`run_state_on_disk` reports a tail and a `total` (`codice.patch:428`) attributed to
whichever repo asked. The append change (`codice.patch:396`) is right for its stated
reason and makes this one worse.

**B4 — NOTE. The run log grows without bound.** Append with no rotation
(`codice.patch:396`); `out['total'] = len(lines)` (`codice.patch:428`) counts every
run ever. Correct tail, meaningless total.

### C. Concurrency and on-disk state

**C1 — BLOCKER. "One unattended run per plan" holds across a restart of *one*
server, not across two servers.** The commit is titled «one unattended run per plan,
across server restarts» and that much is true — but every guard in the diff is
process-local or non-atomic:

- `RUNS_LOCK` is a `threading.Lock` in one process (`codice.patch:442`).
- the pidfile is written with a plain `run_pidfile(slug).write_text(...)`
  (`codice.patch:403-404`) — no `O_EXCL`, no `flock`, no atomic replace.
  `grep -n 'fsync\|flock\|O_EXCL\|fcntl' codice.patch` returns nothing.
- `read_run_pid` swallows `ValueError` and returns `None` (`codice.patch:377-383`),
  and `None` opens the guard. A torn read is indistinguishable from no run.

The delivery's own test proves the single-process case only: the two concurrent
presses run as two **threads in one module** (`codice.patch:811-831`). Meanwhile the
manual explicitly sanctions a second server — «un secondo `/wf:dashboard`»
(`codice.patch:348`) — and a run started from a terminal. Two servers, two presses:
both read an absent pidfile, both see `alive()` false, both `start_run`, the second
overwrites the first's pidfile. Two launchers on one working tree, which is the one
thing the guard exists to prevent.

**C2 — FIX FIRST. `set_check`'s lock is process-local too.** `codice.patch:24`
`_WRITE_LOCK = threading.Lock()`, and the comment claims «One writer at a time, and
one whole file at a time». True within the process. Two servers on the same slug
(see B3) still lose ticks: both read, both write, last wins. The `os.replace`
(`codice.patch:49`) makes the file always-valid, which is the real win; it does not
make the read-modify-write atomic. No `fsync` before the replace either, so the
rename can outlive the data on power loss.

**C3 — NOTE. One function, two return shapes.** `run_state_on_disk` returns
`'source': 'pidfile'` (`codice.patch:422`); the in-process branch's dict has no
`source` key at all (`codice.patch:448-449`), while the test asserts on it
(`codice.patch:779`). The page must therefore guard a key that exists on one path
only.

### D. Prompt-injection surface

**D1 — see B1.** The mechanism is the write endpoints; the reasoning is there.

**D2 — FIX FIRST. The one-line rule is a necessary guard, not a sufficient one.**
`codice.patch:619-621` and the `Disregard the above` fixture (`codice.patch:631`)
correctly identify the mechanism — a newline lets line 2 arrive as its own
instruction. But the rule constrains *shape*, not content, and one line is enough:
the scope reaches a planning skill as prose and is acted on. The guard is right and
should stay; it should not be read as closing the surface.

**D3 — NOTE (demoted after reading the source).** The page renders transcript
content — agent task text, the last 8 tool calls per agent (manual §4), phase notes,
the foreman exchange — and that is untrusted data. The escaping is **correct**:
`index.html:518` escapes `&`, `<`, `>` **and `"`**, so the `title="…"` attribute
sites are covered too, and it is used at 75 call sites against 12 `innerHTML`
assignments. The page also loads nothing from the network (verified: no external
script or stylesheet), so nothing executes there with the write endpoints'
authority. What remains is a bounded chore, not a finding: walk the 12 `innerHTML`
sites once and confirm each interpolation goes through it.

### E. Packaging and allowed-tools

**E1 — BLOCKER. `~/.claude/wfdash/` collides with a mutation-proven guard.**
`tests/orchestration/check_home_paths.py` fails any file under
`plugins/wf/skills/` or `plugins/wf/refs/` that mentions `~/.claude/` or
`$HOME/.claude/`, with exactly one exemption (`~/.claude/settings.json`), and S21
proves the guard by mutation (`run_tests.sh:796-814`). A `/wf:dashboard` skill or a
`refs/dashboard.md` that documents where ticks and run logs live fails the suite.
The choice is: keep the path and weaken a mutation-proven guard with a second
exemption, or move the state where the house already puts runtime files —
`${TMPDIR:-/tmp}/phased-workflow/` (`run-workflow/SKILL.md:52`,
`contracts.md:79`) or `deskstate.runtime_path` (§7). The second is right, and it
fixes B3 on the way if the key gains a repo component.

**Confirmed by running the real guard** on the delivered skill (§9):

```
skills/dashboard/SKILL.md:11: ticks, which land in `~/.claude/wfdash/<slug>/checks.json` — never in
exit=1
```

**E1b — FIX FIRST. The delivered skill also fails S15.** `check_allowlists.py` on
`skills/dashboard/` returns 6 findings — `grep`, `kill`, `open`, `ps`, `sort` and
`tr` are run by the skill's own bash blocks and none is in its `allowed-tools`
(`SKILL.md:4`). In a non-interactive session a step needing an ungranted permission
does not run at all, which is the whole reason that guard exists
(`check_allowlists.py:6-10`). Mechanical, and red today.

**E2 — FIX FIRST. Three undeclared, undocumented Claude Code surfaces.**
`docs/claude-code-compat.md:27-29` states the premise: «An update that changes any
of these can break the plugins without a single line of plugin code changing.» The
nine listed surfaces do not include: the session transcript JSONL schema that
`core.Scan` parses field by field — `message.usage.output_tokens` and
`cache_read_input_tokens`, as the delivery's own fixture documents
(`codice.patch:503`), `claude agents --json` (`codice.patch:130`), and
`~/.claude/tasks/<sessionId>/N.json` (manual §8). These are private on-disk formats
— the highest-churn dependency anything in this repo would have — and
`/check-claude-update` is blind to them until they are listed.

**E3 — FIX FIRST. A hardcoded model price table with no update path.** The page
itself says so: «the table is a constant in core.py and goes stale»
(`codice.patch:283`). The `+?` flag (`codice.patch:241`, `284-286`) is a good answer
to the symptom — a total that omits part of the spend is worse than no total. The
liability remains and has no precedent in this repo.

**E4 — NOTE. A first-of-its-kind surface for this plugin.**
`plugins/wf/scripts/` currently ships two shell scripts and one Python CLI. wfdash
adds a long-lived HTTP server, a static page, and a Browser-pane dependency.
`plugin.json` and `marketplace.json` carry no surface inventory today, so nothing
*fails* — but §6 says what they should gain.

**E5 — NOTE. Doc-mass.** `check_doc_mass.py` caps a skill's closure at 1500 lines
(`check_doc_mass.py:20`). A `/wf:dashboard` skill starts at zero and is cheap; a
`refs/dashboard.md` cited by `resume-workflow` and `run-workflow` is not. §6 keeps
the graft inside `refs/board.md`, which those skills already cite.

### F. Tests

**F1 — FIX FIRST (demoted from BLOCKER). The two test harnesses do not coincide.**
The delivery's own runner is 10 lines: every `tests/test_*.py` executed as a script,
then `flake8 --max-line-length 120`. This repo runs
`bash tests/orchestration/run_tests.sh` — 210 assertions over 32 scenarios
(`README.md:304`) — under **both bash and zsh**, plus `flake8 .` with the scope from
`setup.cfg` (`.github/workflows/ci.yml`). Neither `tests/run_tests.sh` nor any
top-level `tests/test_*.py` exists here, so as delivered the **13** test files are
executed by nothing in this repo, in CI or locally: the defect class the repo names
«a shipped contract no test executes» (`run_tests.sh:1101-1103`). Demoted because
the fold is mechanical and the tests themselves pass — verified in this session
(§9).

Lint is fine, incidentally: no added Python line exceeds 120 columns (measured; the
one long line is JavaScript in `index.html`, which `flake8` does not read), and the
`# noqa: E402` markers are correct.

**F2 — FIX FIRST. The concurrency and guard tests prove the single-process case and
are titled as if they proved more.** Detailed in C1. The tests are good — barriers,
a deliberately ~2 MB fixture with a stated reason (`codice.patch:509-510`), mutation
notes, and a `clear()` that kills leaked `sleep`s (`codice.patch:755-764`). The gap
is the claim, not the craft.

**F3 — NOTE. Tests that spawn `sleep 300` and touch `~/.claude`.**
`codice.patch:719-720` redirects `checks.ROOT` into a tempdir, which is right. The
guard test still starts real detached processes (`codice.patch:769`, `796`) and
depends on `ps`. Acceptable, but it makes the suite host-sensitive in a way the
orchestration suite avoids with `mock-bin/claude`.

**F4 — NOTE. Assertion by source-text inspection.** `codice.patch:669-673` pins the
copy box by string-matching the page's own function body, because «There is no
JavaScript harness in this repository» (`codice.patch:622-623`). The author says so
plainly, which is the right handling of a real gap — and the gap is already closed
elsewhere in the house: `git-workflow/plugins/git-workflow/server/tests/test_ui.mjs`
is 600 lines of exactly that harness (§7).

### G. Documentation

**G1 — FIX FIRST. The manual is in Italian; everything persisted in this repo is in
English.** `refs/common.md:15-19` — «All written content […] in English: the
artifacts outlive the chat that produced them». `~/.claude/CLAUDE.md`: chat in
Italian, everything persisted in English. A 2.2 MB Italian HTML manual is a
persisted artifact.

**G2 — FIX FIRST. 2.2 MB of base64 screenshots in the repo, in one file.** Nine
images, 97 KB–363 KB each, inlined. `docs/` keeps its images in `docs/img/` as
separate files. A single-file manual is convenient to send and wrong to commit.

**G3 — NOTE. The manual documents §10 as the limits list and it has one bullet.**
Verified against the raw HTML, not only the conversion: `<h2 id="limiti">` contains
a `<ul>` with exactly one `<li>`. Meanwhile real limits are documented *elsewhere in
the manual* and not collected there — the missing launcher (§5), the todo-list
estimate caveats (§8), the one-way foreman channel (§4). A limits section that omits
what its own body admits reads as more finished than it is.

## 4. The author's declared limits (manual §10), classified

The section declares **one** limit:

> «Attribuzione delle fasi girate unattended: non c'è ancora. Servirebbe
> incrociare i commit `wf(phase N):` con la finestra temporale dei transcript.»

**NOTE — acceptable with a note.** The page already says it honestly rather than
faking it: «Una fase con `—` nella colonna chat non è una fase a zero: è una fase
girata unattended, che non ha una chat titolata» (manual §3). Attribution by
title is exact (manual §9) and the proposed fix — crossing commits with transcript
time windows — is a heuristic; the plugin's own rule is «attribution is **exact** —
never infer it» (`resume-workflow/SKILL.md:70`). So the right resolution is not the
time-window cross-reference but leaving it unattributed and saying so, which is what
it does. Worth noting for the record: unattended phases are precisely the ones the
graft in §6 stops launching from the dashboard, so their spend arrives through
`/run-workflow`'s own reporting instead.

Three further limits stated in the manual's body but **absent from §10**, classified
here because §3 needs them counted somewhere:

- the launcher missing from the author's checkout, so `-L` is mandatory there
  (manual §5) — **retracted**: not a limit at all. The author's repo holds only
  `wfdash/`, and innested in the plugin `launcher_path()` finds the launcher beside
  it, so `-L` is not needed (§9);
- the foreman channel being one-way, with the reply arriving from the transcript
  rather than the socket (manual §4) — **NOTE**, and correctly surfaced on screen as
  `delivered · the socket carries no answer`;
- the agents' todo progress being an estimate that can move backwards and does not
  sum across chats (manual §8) — **NOTE**, and well handled: «no declaration», never
  0%.

## 5. Not verifiable without the base source — CLOSED 2026-08-27

**Every item below was closed by the source that arrived on 2026-08-27.** The
table is kept as the record of what the diff alone could not answer; §9 carries the
answers. Two of them turned out to be merits rather than defects:

- **the plan regex** — `core.py:398` `PHASE_RE` is **identical byte for byte** to
  `next-phase.py:46`. A frozen copy of a shipped contract, which strengthens A5:
  the duplication is not only the selection logic, it is the format regex too.
- **path traversal via the slug** — **not exploitable, and deliberately so.**
  `plan_source` (`server.py:443-457`) never concatenates the query's slug into a
  path: it matches it against slugs discovered from disk and from the branches. The
  `checks.py` path (`checks_path:34-35`) takes its slug from the plan directory's
  own name, not from a request.

| Open question | File needed |
|---|---|
| The HTTP surface in full: bind, how the write token is generated and scoped, whether **reads** require it, any `Origin`/`Host` check, the routing table, `launch_unattended`'s body, `newflow`, the foreman deliver path, `titles()`, `owner_pid` | `plugins/wf/scripts/wfdash/server.py` |
| Whether `esc()` escapes quotes, and whether **every** render site uses it — the B1/D3 audit | `plugins/wf/scripts/wfdash/index.html` |
| `parse_plan` / `parse_plan_text` regexes (does the plan parser agree with `next-phase.py:46` `PHASE_RE`?), `all_plan_dirs`, `branch_plan_dirs`, `lifecycle`, the price table, `Board.tree`, `group_chats`, `alerts` | `plugins/wf/scripts/wfdash/core.py` |
| `checks_path`, `check_id`, `read_checks` — and whether the slug is sanitised before becoming a path component (a slug with `../` would escape `ROOT`) | `plugins/wf/scripts/wfdash/checks.py` |
| `allowed-tools`, `disable-model-invocation`, whether it names `~/.claude/` (E1), its doc-mass | `plugins/wf/skills/dashboard/SKILL.md` |
| How a user turn is injected into another session — the mechanism behind `inbox.deliver_first(repo, pid, sess, text, titles)` (`codice.patch:654`) | `plugins/wf/scripts/wfdash/inbox.py` (name inferred from the call) |
| The other four of the six assertions, including the token one | `tests/test_perimeter.py` at base |
| Whether it runs flake8, how it discovers tests, and what the «24 righe, all green» covers | `tests/run_tests.sh` |

Note that `finished_plan()` — the substance of two of the seven commits — calls
`all_plan_dirs` and `branch_plan_dirs` (`codice.patch:191`, `197`), neither of which
is in the diff. Its correctness is asserted by `test_steps.py`'s new fixture
(`codice.patch:894-949`), which builds a real repo, squashes a `wf/` branch into
`main`, drops `.phased/`, and checks the plan is still found on the branch. That is
a well-built test and it is the strongest part of the delivery.

## 6. The optional graft

### The rule the optionality descends from

Already written, and not a new invention: `plugins/wf/refs/board.md:16-18` —

> **Only where the `visualize` MCP server is available.** Absent → the same rows as
> a plain list. Declare the fallback, never fail silently; same rule as `ui-test`
> in `/execute-phase`.

The dashboard is a second instance of that rule. The graft therefore lands in
`refs/board.md`, which is already the single source of the read surface and is
already cited by both skills that would mention the dashboard
(`resume-workflow/SKILL.md:97`, `write-workflow/SKILL.md:14` and `:193`). That keeps
the change single-source and adds nothing to the doc-mass of the hot skills (E5).

### The shape, in one sentence

**The dashboard reads, and couriers. It never spawns, and it never owns a phase.**
Every action becomes a request that the attached chat services with its full context
— which is what the house's own precedent already decided, for the reason it wrote
down (`git-workflow/plugins/git-workflow/server/inbox.py:1-8`, quoted in §7).

### The graft points

**1. `plugins/wf/refs/board.md`** — new section, *The dashboard, where it exists*.
Single-source. Says: the board strip is the report's own surface; the dashboard is a
separate, optional, long-lived surface with the same standing as `visualize`; the
strip never depends on it, and no skill requires it.
*Fallback:* «No dashboard (not started, python3 or the port unavailable, no browser
surface) → the report as it is today, plus one line: `dashboard not opened — <why>`.
Nothing in the workflow waits for it.»

**2. `plugins/wf/skills/dashboard/SKILL.md`** — new skill, the **only** entry point,
`disable-model-invocation: true`, modeled on `pr-desk` (§7). Per-skill by necessity.
No existing skill gains a dashboard argument: `/resume-workflow` is the plugin's
entry point and the one skill the agent may reach on its own
(`resume-workflow/SKILL.md:2`), so a surface that starts a server does not belong
behind it.
*Fallback:* the skill itself declares its degradations and exits clean — no python3,
no free port, no Browser pane → say which, name `/wf:resume-workflow` as the reading
path, stop. Never a failure.

**3. `plugins/wf/skills/resume-workflow/SKILL.md:90`** — one clause, per-skill.
Step 3 point 1 already treats the run log as the surviving evidence of a killed run;
it must accept the dashboard's location too — or, better, wfdash writes to the
existing `${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log` and this edit is not
needed at all (A3, E1). **Preferred: no edit; move the log.**
*Fallback:* unchanged — the skill's diagnosis already works with no dashboard.

**4. `plugins/wf/skills/run-workflow/SKILL.md`** — no edit, and that is the point.
`/run-workflow` keeps sole ownership of an unattended run (A2). The dashboard's
"Run unattended" button stops spawning and instead emits one request the attached
chat picks up and services by invoking `/wf:run-workflow`, pre-flight and all.
*Fallback:* with no dashboard, `/run-workflow` is typed as it is today. The skill
never learns the dashboard exists.

**5. Who owns starting a phase, with two surfaces.** The chat does, always
(A1, `board.md:41-49`). The dashboard's phase button emits a request; the attached
chat answers it the way `board.md:47-49` already prescribes — **the launch command
appears as text**, to be run in a new chat. The server never writes
`/wf:execute-phase` into the supervision chat, and with an owner pid it can refuse
that case instead of performing it.
*Fallback:* identical, because the text command *is* the fallback. This is the
graft point where the optional surface and the mandatory one converge on one answer.

**6. The checks pane becomes read-only (A7).** It renders the phase's `> Verify:`
notes and does not persist ticks. `~/.claude/wfdash/<slug>/checks.json` goes away.
The gate stays where the contract puts it: the human's ok, in the conversation
(`phase-execution.md:280`). If a tick record is wanted for convenience, it is
explicitly a scratch mirror the page labels as such, never read by a skill.
*Fallback:* no dashboard → `/quality-check`'s QA page, which already exists and is
already declared-degradable (`contracts.md:77-88`).

**7. `plugins/wf/refs/foreman.md`** — one line in *Channel floors*, single-source
(A9): the dashboard courier is a third branch, and a skill declaring which channel
is alive names it when it is.
*Fallback:* the two existing branches, unchanged.

**8. `plugin.json` and `marketplace.json`.** Neither carries a surface inventory
today, so the mechanical need is small: the `version` bump (CI enforces
README/plugin.json/marketplace.json agreement — `ci.yml`), and
`marketplace.json`'s plugin `description` and `keywords` gaining the dashboard, since
that is the shop window. What must **not** appear is a new hard dependency: no
`mcpServers` entry, no required runtime. The real declaration belongs in
`docs/claude-code-compat.md` — three new numbered surfaces for the transcript JSONL
schema, `claude agents --json`, and `~/.claude/tasks/<sessionId>/N.json` (E2), so
`/check-claude-update` starts watching them.

**9. `tests/orchestration/run_tests.sh` — a new scenario, S34** (S1–S33 exist, S16
retired — `README.md:304`), in the house idiom: a static guard in a
`check_*.py` plus a mutation that proves it. What it must assert:

- every skill or ref that mentions the dashboard also carries a fallback clause in
  the same neighbourhood — mutation: delete the clause, the guard goes red;
- no skill's gate, `Done:`, or *Next step* names the dashboard as a **precondition**
  — mutation: insert «open the dashboard, then continue», the guard goes red;
- `refs/board.md` remains the single source of the optionality rule and no skill
  restates it — the S27/S30 idiom;
- the phase-state guard of S18 extends to Python plan readers, or wfdash consumes
  `next-phase.py` and the guard has nothing to cover (A5).

**What must break if someone makes the dashboard mandatory.** The second assertion
is the one that bites: any imperative step that requires the server to be up fails
S34, and the mutation proves the guard means it. That is the mechanical answer to
the requirement in the brief — the surface cannot become load-bearing without a red
suite.

## 7. Reuse or new, piece by piece

Per the reuse ladder in `~/.claude/CLAUDE.md` — stop at the first rung that holds,
and declare **copy-adapt** (cite) / **extend** (name the gap) / **new** (why nothing
fits).

| Piece of wfdash | Verdict | Basis |
|---|---|---|
| atomic, cross-process JSON state (`checks.json`, `run.pid`) | **copy-adapt** | `git-workflow/plugins/git-workflow/server/safejson.py` — per-path thread lock **plus `fcntl.flock`**, `mkstemp` + `fsync` + `os.replace`, and `update(path, mutate)` is exactly `set_check`'s read-modify-write. It solves C1, C2 and the torn-read half of the run guard outright. |
| runtime state outside the repo | **copy-adapt** | `deskstate.runtime_path()` (OS temp dir, `inbox.py:18`) instead of `~/.claude/wfdash/`. Fixes E1, and keying it by repo fixes B3. |
| button → chat channel, and the decision not to spawn | **copy-adapt** | `git-workflow/.../server/inbox.py:1-8` + `watch_inbox.py`. Its docstring already carries the reasoning A2 needs: «In chat mode the server never spawns headless runs: a button click appends one JSON line here, and the launching agent session […] acts on them with its full context (CLAUDE.md, skills, permissions)». |
| threaded server + one static page + polling | **copy-adapt** | `server/prdesk.py` (731 lines) and `server/static/index.html` (1109 lines) — the same shape, already shipped. |
| the page's own test harness | **copy-adapt** | `server/tests/test_ui.mjs` (600 lines) — closes F4's declared gap, which the author correctly said this repo lacks. |
| a packaging test for the new surface | **copy-adapt** | `server/tests/test_packaging.py` (128 lines). |
| plan parsing, phase selection, plan discovery | **extend** | `plugins/wf/scripts/next-phase.py` already has `PHASE_RE:46`, `parse:95`, `plan_state:168`, `list_plans:175`, `recommend:224`, `blockers:110`. The gap is a machine-readable output: today it prints a status table and a `recommendation:` line for humans. Add `--json` and have the server consume it. That is the fix for A5 and it deletes `plan_shape`'s duplicated selection logic. |
| the optionality rule and its fallback | **extend** | `refs/board.md:16-18` — the rule exists; the dashboard is a second instance of it. |
| the foreman channel inventory | **extend** | `refs/foreman.md:98-113`. |
| lifecycle strip (`PLAN—EXEC—QUALITY—FINAL`) | **extend** | Its four proofs are facts the plugin already defines: the plan commit (`common.md:115`), all phases `[x]`, the quality stamp (`contracts.md:110`), the plan under `done/` (`common.md:69`). New rendering over existing contract facts, which is the right kind of new. |
| `finished_plan()` — a closed plan found in `done/` or on its `wf/` branch | **new, justified** | Nothing reads a finalized plan today: `/resume-workflow` stops at «no active plan». It is a real gap, correctly diagnosed («finalize drops `.phased/` from the squash […] so on the parent branch a closed workflow survives only on the `wf/` branch», `codice.patch:186-189`), and it is the best-tested part of the delivery (`codice.patch:894-949`). |
| `core.Scan` — incremental transcript cost accounting | **new, and the riskiest piece** | Nothing in either repo parses session transcripts. There is no framework API for it, so rung 3 does not hold and rung 5 would mean adopting a private on-disk format as a dependency — which is what it is. Keep it, and declare it in `claude-code-compat.md` (E2) so its breakage is watched rather than discovered. |
| the model price table | **new, unavoidable, and a liability** | No source of truth exists in-repo. The `+?` flag (`codice.patch:241`) is the right mitigation; the table still needs an owner. |
| server-side `start_run` / `run_pidfile` / `alive` / `run_state_on_disk` | **delete, do not port** | `/run-workflow` owns the run (A2). Removing the spawn removes the guard's entire reason to exist, and with it C1, B2, A4 and A6. This is the largest single simplification available and the whole of commit `0e248bf` plus half of `5d15a49` goes with it. |

## 8. Merge plan

### What to ask the author

The bundle is unusable here because its prerequisite `770b238` exists nowhere we can
reach, and the manual says the author's checkout lacks the plugin's launcher — so
the two trees have diverged, and re-cutting the bundle alone may not be enough.
Three commands, in order:

```bash
git log --oneline -1 770b2387d7b5252d6f682501a6a897c859fde8fa
git merge-base --is-ancestor 6d7e6fc HEAD && echo "descends from 6.23.0" || echo "diverged"
git log --oneline --diff-filter=D -- plugins/wf/scripts/run-workflow.sh
```

The first says what the base commit is. The second says whether the work descends
from this repo's history at all. The third explains the missing launcher — deleted,
or never present.

Then, if it descends, one self-contained bundle whose only prerequisite is a commit
we have:

```bash
git bundle create wfdash-full.bundle 26c93cb..HEAD
```

If it does not descend, the certain route, size accepted:

```bash
git bundle create wfdash-all.bundle --all
```

### The alternative route, if they would rather not re-cut it

What is actually missing is the **base**, not the update: the 7 commits are a diff
against files we do not have. So the full files, at any commit, answer just as well:

```bash
git archive HEAD plugins/wf/scripts/wfdash plugins/wf/skills/dashboard tests | gzip > wfdash-tree.tgz
```

Or simply push the branch — `git push origin HEAD:refs/heads/wfdash` — and it is
fetchable here with no bundle at all.

### The order of work, once the source is in hand

1. Close §5 by reading `server.py` and `index.html` — the B1/D3 audit gates
   everything else, because it decides whether the surface is defensible at all.
2. Resolve the blockers that are **deletions**, not fixes: drop the server-side
   spawn (A2), drop the write into the supervision chat (A1), drop the tick
   persistence (A7). Each removes code and its tests along with the risk.
3. Then the substitutions: `safejson` for the hand-rolled locking, the temp-dir
   state path keyed by repo (E1, B3), `next-phase.py --json` for the duplicated
   selection (A5).
4. Then the harness: fold the four test files into
   `tests/orchestration/run_tests.sh`, add S34 (F1, graft point 9).
5. Then the documentation: the manual in English as `docs/`-resident markdown with
   images in `docs/img/` (G1, G2), the three new surfaces in
   `claude-code-compat.md` (E2).
6. Only then the version bump and the manifests (graft point 8).

Steps 2 and 3 are most of the delivery's risk and none of its value: what the
dashboard is *for* — reading where the work stands, at a glance, including a
workflow that has already been finalized — survives all of it intact.

## 9. Verification pass — the source arrived, 2026-08-27

`~/Downloads/wfdash-fporcari/` carried `wfdash-all.bundle` (complete history, no
prerequisites), the manual, `RISPOSTE.txt` answering the five questions of §8, and
two proof logs. Everything below was run in this session against the cloned source.

### What the answers settled

The author's repo is **not a fork of the plugin**: it is a standalone repo whose
tree holds `plugins/wf/scripts/wfdash/` (with `inbox.py` and `roadmap.py`, neither
of which was in the diff), `plugins/wf/skills/dashboard/SKILL.md`, and 13 tests.
There is no launcher in it because there never was one — `git log --all
--diff-filter=D` finds no deletion — and in execution it runs against the
*installed* plugin (6.20.0). So §1's "two diverged trees" was wrong, and the
missing-launcher limit is retracted.

The history is 89 commits, and it is itself a phased workflow of 8 phases: the
dashboard was built under this plugin, so the house conventions are already in the
code. `RISPOSTE.txt` says "9 commits", which is wrong and harmless. Phase 6 carries
~25 `partial` checkpoints and a commit recording the sizing lesson — evidence about
phase sizing, not about the code.

The author's suite is **green here**: 34 result lines plus `flake8` at 120 columns.
The «24 righe» of the first delivery was a stale count.

Two of the author's own answers confirm findings of §3 and go further than the audit
did. On A6: `PHASED_UNATTENDED` is inert, nothing reads it — and the comment at
`server.py:42-44` asserts a launcher behaviour he states he never verified against
the launcher. His words: it must be corrected or removed. On the end-to-end proof:
"Run unattended" ran for real **once**, on 2026-08-26, on a sandbox repo that no
longer exists; the log survives. It ran `sonnet/low`, and `sonnet` is not in this
plugin's palette (`run-workflow/SKILL.md:37`) — a property of that sandbox's plan,
not of wfdash. Everything else in the launch coverage uses a stub launcher.

### The security gate, which was the reason not to plan yet

**Verdict: the server is repairable, not to be rewritten.** The `prdesk.py` branch
of §6 does not apply. What is already right: a per-process token from `secrets`
substituted into the page and required back on every write; an explicit
`WRITE_PATHS` list; `MAX_BODY`; the foreman target never in the request; the owner
pid re-read and its cwd re-checked at write time; correct escaping including `"`;
no network resources in the page.

**One blocker, demonstrated rather than deduced** (B1, B1b above). Against the
running server on a sandbox repo, with no owner and no launcher so the launch road
was inert:

| Request | Result |
|---|---|
| `POST /api/check`, no token | `403 write token missing or wrong` |
| `GET /` , nothing sent | `200` — token in clear in `<meta name="wfdash-token">` |
| `POST /api/check` + that token | `200`, reaches the handler (`{"error": "no plan"}`) |
| `POST /api/launch` + token + foreign `Origin` | `403 origin not allowed` |
| `GET /api/state`, `/api/sessions`, `/api/mirror` | `200` each, unauthenticated |

So the Origin check works and is irrelevant: a local process sends no Origin. The
barrier is the token, and the token is handed out by an endpoint that asks for
nothing.

The two guards of this repo, run on the delivered skill, produce 7 findings: 1 for
S21 and 6 for S15 (E1, E1b above).

### Graft verdict, and the mode

**A phased workflow, and `Mode: autonomous`** — this corrects the interactive
recommendation given before the source was read. The reason for that
recommendation was that phase 1 (the HTTP perimeter) needed judgment. It does — but
the judgment belongs to **planning**, which is exactly what the `/write-workflow`
fork is for. Once the plan states where the token lives, every phase here meets the
autonomous-ready bar of `run-workflow/SKILL.md:20-26`: named files, decisions
pre-made, and a `Done:` that is machine-checkable to an unusual degree, because
this repo already ships the checks — the orchestration suite, `check_home_paths.py`,
`check_allowlists.py`, `flake8`, and the author's own 13 tests.

The perimeter phase gets the strongest `Done:` of the set: **the manual bypass above,
turned into a test.** Lift the token from `GET /`, attempt a write, and require the
refusal. That is the house idiom — the guarantee is a test that goes red when the
hole returns, not a reviewer's attention at the gate.

Phases, in dependency order:

1. **The HTTP perimeter.** Token out of the served page; every read endpoint
   authenticated. `Done:` the bypass test refuses, and `test_perimeter.py`'s false
   claim at `:5-9` is rewritten to what actually holds.
2. **Three deletions of form** — the server-side spawn (A2), the write into the
   supervision chat (A1), the persistence of ticks (A7). Less code, and B2, C1, A4
   and A6 go with it.
3. **Mechanical substitutions** — `safejson` for the hand-rolled locking (C1, C2),
   runtime state under `${TMPDIR}` keyed by repo (E1, B3), `next-phase.py --json`
   consumed instead of the duplicated `PHASE_RE` and selection (A5).
4. **The skill's allowlist and paths** — S21 and S15 green (E1, E1b).
5. **Harness fold** — the 13 tests into `tests/orchestration/`, plus S34 (graft
   point 9). `Done:` both suites green under bash and zsh.
6. **Documentation** — the manual in English under `docs/`, images in `docs/img/`
   (G1, G2); the three surfaces into `claude-code-compat.md` (E2).
7. **Manifests** — version bump with the CI drift guard green (graft point 8).

One thing for the pre-flight rather than the plan: phase 1's `Done:` starts a
server and issues local HTTP requests. Whether `--permission-mode auto` allows
that unattended is the one open question of the run, and
`refs/auto-mode-scope.md` is where it is decided.

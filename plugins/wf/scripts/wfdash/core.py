"""The state of a workflow, read from disk.

One panel per agent. An agent is a chat (a Claude Code session) or a subagent
(an Agent one chat spawned): they carry the same fields, because the question
asked of both is the same — what task it holds, since when it has been
running, what it is doing now, what it produced, what it cost.

Sources, all of them already on disk:

  ~/.claude/projects/<slug>/<sessionId>.jsonl
      the transcript of a chat. `assistant` rows with `message.usage`,
      `message.model`, `effort`, and the `tool_use` blocks.
  ~/.claude/projects/<slug>/<sessionId>/subagents/agent-<id>.meta.json
      `agentType`, `description`, `toolUseId`, `spawnDepth` of a subagent.
  ~/.claude/projects/<slug>/<sessionId>/subagents/agent-<id>.jsonl
      its transcript, the same shape as a chat's.
  ~/.claude/tasks/<sessionId>/N.json
      the session's own todo list, one file per item: `subject`, `activeForm`,
      `status`. It is the agent's declaration, at the agent's own grain.
  claude agents --json
      the live sessions: pid, sessionId, cwd, name, startedAt.
  <repo>/.phased/active/<slug>/plan.md
      the phases, their markers and their Run:.
  git log
      the `wf(phase N):` commits, which say when each phase was running —
      the only record of a phase whose chat never took a title.

Transcripts are append-only, so reading is incremental — byte by byte from
where it stopped — because the dashboard polls and the files reach a few MB.
"""

import datetime
import glob
import importlib.util
import json
import os
import pathlib
import re
import subprocess
import threading
import time

import checks
import roadmap

HOME = pathlib.Path.home()
PROJECTS = HOME / '.claude' / 'projects'
TASKS = HOME / '.claude' / 'tasks'

# $/1M tokens (input, output) — the claude-api skill's table as of 2026-09-02.
# Cache: write 1.25x input (TTL 5m) or 2.0x (TTL 1h); read 0.1x input, except
# for the models CACHE_READ prices on their own.
PRICES = {
    'claude-fable-5': (10.0, 50.0),
    'claude-fable-5-1': (10.0, 50.0),
    'claude-mythos-5': (10.0, 50.0),
    'claude-opus-5': (5.0, 25.0),
    'claude-opus-4-8': (5.0, 25.0),
    'claude-opus-4-7': (5.0, 25.0),
    'claude-opus-4-6': (5.0, 25.0),
    'claude-sonnet-4-6': (3.0, 15.0),
    'claude-haiku-4-5': (1.0, 5.0),
}
CACHE_READ = {'claude-fable-5-1': 0.25}
SONNET5_INTRO_END = '2026-09-01'
ACTIVE_WINDOW_S = 120  # a transcript touched within this window is running
TRAIL_LEN = 8          # how many recent actions are kept per agent


def price(model, ts):
    if model == 'claude-sonnet-5':
        return (2.0, 10.0) if (ts or '') < SONNET5_INTRO_END else (3.0, 15.0)
    return PRICES.get(model)


def cache_read_rate(model, pin):
    return CACHE_READ.get(model, pin * 0.1)


CMD_TAG_RE = re.compile(r'<command-(?:message|name|args)>(.*?)</command-\\1>', re.S)


def _clean_prompt(text):
    """The first turn of a chat opened by a slash command is wrapped in the
    `<command-message>` / `<command-name>` / `<command-args>` tags. What
    identifies the chat is the command with its arguments, not the wrapper."""
    parts = re.findall(r'<command-(name|args)>(.*?)</command-\1>', text, re.S)
    if parts:
        return _short(' '.join(v.strip() for _, v in parts if v.strip()), 400)
    return _short(re.sub(r'<[^>]+>', ' ', text), 400)


def _short(value, limit=90):
    s = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    s = ' '.join(s.split())
    return s[:limit]


class Scan:
    """The accumulated state of a transcript, updatable in append.

    `update()` reads only the bytes added since the last call. Everything the
    dashboard shows lives here: the token totals, the last tool, the final
    text, the title the chat gave itself.
    """

    WRITE_TOOLS = {'Edit', 'Write', 'NotebookEdit'}

    def __init__(self, path):
        self.path = str(path)
        # One reader per transcript. The server is threaded and four endpoints
        # re-enter the same Scan, so two handlers could read from the same
        # offset and both advance it — every row in that overlap counted twice,
        # for the life of the process. The lock is NOT part of the reset below:
        # a full re-read must not replace the lock it is holding.
        self.lock = threading.Lock()
        self._reset()

    def _reset(self):
        self.offset = 0
        self.turns = self.output = self.reread = self.cache_write = 0
        self.plain_input = self.thinking = 0
        self.usd = 0.0
        self.models = set()
        self.unpriced = set()
        self.first_ts = self.last_ts = None
        self.title = None
        self.cwd = None             # the directory the session ran in
        self.tools = 0
        self.writes = 0
        self.bash = 0
        self.last_tool = None       # {'name','arg','ts'}
        # The last actions, in order: one line does not show that the agent is
        # working, a queue of them does.
        self.trail = []
        self.last_text = None
        self.first_prompt = None
        self.errors = 0             # system/api_error rows
        self.effort = None
        self.mtime = 0.0
        # One point per turn: the curve read in the panel — the context
        # growing while the output per turn stays flat.
        self.series = []

    # -- incremental reading -----------------------------------------------------
    def update(self):
        with self.lock:
            return self._update()

    def _update(self):
        try:
            st = os.stat(self.path)
        except OSError:
            return self
        self.mtime = st.st_mtime
        if st.st_size < self.offset:      # file rewritten: start over
            self._reset()
            try:
                st = os.stat(self.path)
            except OSError:
                return self
            self.mtime = st.st_mtime
        if st.st_size == self.offset:
            return self
        with open(self.path, 'rb') as fh:
            fh.seek(self.offset)
            blob = fh.read()
        # A half-written line stays out: the next round picks it up.
        cut = blob.rfind(b'\n')
        if cut == -1:
            return self
        self.offset += cut + 1
        for raw in blob[:cut].split(b'\n'):
            if not raw.strip():
                continue
            try:
                self._row(json.loads(raw))
            except (ValueError, TypeError):
                continue
        return self

    def _row(self, d):
        self.cwd = self.cwd or d.get('cwd')
        t = d.get('type')
        if t == 'custom-title':
            self.title = d.get('customTitle') or self.title
            return
        if t == 'system' and d.get('subtype') == 'api_error':
            self.errors += 1
            return
        if t == 'user' and self.first_prompt is None and not d.get('isMeta'):
            msg = d.get('message') or {}
            content = msg.get('content')
            if isinstance(content, str) and content.strip():
                self.first_prompt = _clean_prompt(content)
            return
        if t != 'assistant':
            return
        msg = d.get('message') or {}
        ts = d.get('timestamp')
        for c in (msg.get('content') or []):
            if not isinstance(c, dict):
                continue
            if c.get('type') == 'tool_use':
                self.tools += 1
                name = c.get('name')
                if name in self.WRITE_TOOLS:
                    self.writes += 1
                elif name == 'Bash':
                    self.bash += 1
                inp = c.get('input') or {}
                arg = (inp.get('command') or inp.get('file_path')
                       or inp.get('pattern') or inp.get('description')
                       or inp.get('prompt') or inp)
                self.last_tool = {'name': name, 'arg': _short(arg), 'ts': ts}
                self.trail.append(self.last_tool)
                del self.trail[:-TRAIL_LEN]
            elif c.get('type') == 'text' and (c.get('text') or '').strip():
                self.last_text = _short(c['text'], 600)
        usage = msg.get('usage')
        if not usage:
            return
        model = msg.get('model') or '?'
        self.effort = d.get('effort') or self.effort
        cc = usage.get('cache_creation') or {}
        w5 = cc.get('ephemeral_5m_input_tokens', 0)
        w1 = cc.get('ephemeral_1h_input_tokens', 0)
        inp = usage.get('input_tokens', 0)
        rd = usage.get('cache_read_input_tokens', 0)
        out = usage.get('output_tokens', 0)
        self.turns += 1
        self.output += out
        self.reread += rd
        self.cache_write += w5 + w1
        self.plain_input += inp
        self.thinking += (usage.get('output_tokens_details') or {}).get('thinking_tokens', 0)
        self.models.add(model)
        p = price(model, ts)
        if p is None:
            self.unpriced.add(model)
        else:
            pin, pout = p
            self.usd += (inp * pin + w5 * pin * 1.25 + w1 * pin * 2.0
                         + rd * cache_read_rate(model, pin) + out * pout) / 1e6
        if ts:
            self.first_ts = self.first_ts or ts
            self.last_ts = ts
        self.series.append({'n': self.turns, 'ts': ts, 'out': out, 'read': rd,
                            'model': model, 'effort': self.effort,
                            'usd': round(self.usd, 3)})

    # -- the numbers one reads ---------------------------------------------------
    @property
    def ratio(self):
        """Context reread per token produced."""
        return self.reread / self.output if self.output else 0.0

    @property
    def ctx(self):
        """Average context carried into a turn."""
        return self.reread / self.turns if self.turns else 0.0

    @property
    def out_per_turn(self):
        return self.output / self.turns if self.turns else 0.0

    @property
    def think_pct(self):
        return 100.0 * self.thinking / self.output if self.output else 0.0

    @property
    def active(self):
        return (time.time() - self.mtime) < ACTIVE_WINDOW_S

    def panel(self, kind, ident, name, task, extra=None):
        """The panel: what the dashboard shows of an agent."""
        doing = None
        if self.last_tool:
            doing = dict(self.last_tool)
            doing['ago_s'] = _ago(self.last_tool.get('ts'))
        trail = [dict(x, ago_s=_ago(x.get('ts'))) for x in reversed(self.trail)]
        d = {
            'kind': kind, 'id': ident, 'name': name, 'task': task,
            'started': self.first_ts, 'last': self.last_ts,
            'active': self.active, 'mtime': self.mtime,
            'doing': doing, 'trail': trail, 'produced': self.last_text,
            'turns': self.turns, 'output': self.output, 'reread': self.reread,
            'cache_write': self.cache_write, 'thinking': self.thinking,
            'ratio': round(self.ratio, 1), 'ctx': round(self.ctx),
            'out_per_turn': round(self.out_per_turn),
            'think_pct': round(self.think_pct, 1),
            'usd': round(self.usd, 2), 'tools': self.tools,
            'writes': self.writes, 'bash': self.bash, 'errors': self.errors,
            'models': sorted(self.models), 'unpriced': sorted(self.unpriced),
            'effort': self.effort,
        }
        if extra:
            d.update(extra)
        return d


def _when(ts):
    """An ISO timestamp as an aware datetime, None when it does not parse.

    git prints a local offset, a transcript row prints UTC with a `Z`. The
    two are comparable as instants and not as strings: comparing the strings
    orders by offset, which put a phase-4 chat on phase 1 the first time
    around.
    """
    if not ts:
        return None
    try:
        return datetime.datetime.fromisoformat(ts.replace('Z', '+00:00'))
    except ValueError:
        return None


def _ago(ts):
    t = _when(ts)
    return int(time.time() - t.timestamp()) if t else None


# --- where the transcripts live -----------------------------------------------

def project_dir(cwd):
    slug = str(cwd).replace('/', '-').replace('_', '-').replace('.', '-')
    d = PROJECTS / slug
    if d.is_dir():
        return d
    tail = pathlib.Path(cwd).name.replace('_', '-').replace('.', '-')
    hits = [p for p in PROJECTS.glob(f'*-{tail}') if p.is_dir()]
    return hits[0] if len(hits) == 1 else None


# The live-session list costs a `claude` process launch — measured at 0.263s of
# a 0.320s warm response, i.e. four fifths of the poll. Four endpoints ask for
# it independently and one asks twice in a single request, while the page polls
# every 5s: without this the server spends most of its life starting processes
# to be told the same thing. The list changes when a session opens or closes,
# so a short window is enough to collapse one tick's worth of callers into one
# launch. Module level on purpose: `inbox` reads it too, and threading a cache
# through both callers would buy nothing over the lock below.
SESSIONS_TTL_S = 3.0
_sessions_cache = {'at': 0.0, 'value': {}}
_sessions_lock = threading.Lock()


def live_sessions():
    """sessionId -> record from `claude agents --json`, cached for a few seconds."""
    with _sessions_lock:
        if time.monotonic() - _sessions_cache['at'] < SESSIONS_TTL_S:
            return _sessions_cache['value']
        value = _read_sessions()
        _sessions_cache.update(at=time.monotonic(), value=value)
        return value


def _read_sessions():
    try:
        out = subprocess.run(['claude', 'agents', '--json'], capture_output=True,
                             text=True, timeout=30).stdout
        return {s['sessionId']: s for s in json.loads(out)}
    except Exception:
        return {}


def _todo_order(path):
    """`10.json` after `9.json`: the name is a number, not a string."""
    stem = pathlib.Path(path).stem
    return (0, int(stem)) if stem.isdigit() else (1, stem)


def read_todos(session_id):
    """The session's own todo list, read as-is. None when it declared none.

    The list belongs to the agent: written at the agent's grain, allowed to be
    stale, and an item may go back from `completed` to `in_progress` — the
    count then moves backwards, which is a retreat and not an anomaly. Nothing
    here is certified, so the page labels it an estimate.

    None is not zero: a session that never wrote a todo has declared nothing,
    and an empty bar would read as no progress instead of no declaration.
    """
    items, active_form = [], None
    for f in sorted(glob.glob(str(TASKS / str(session_id) / '*.json')), key=_todo_order):
        try:
            with open(f) as fh:
                j = json.load(fh)
        except (OSError, ValueError):
            continue
        status = j.get('status')
        if status == 'in_progress' and active_form is None:
            # What the agent says it is doing, in its own words.
            active_form = _short(j.get('activeForm') or '', 160) or None
        items.append({'id': j.get('id'), 'subject': _short(j.get('subject') or '', 160),
                      'status': status})
    if not items:
        return None
    return {'items': items, 'total': len(items),
            'done': sum(1 for j in items if j['status'] == 'completed'),
            'active_form': active_form}


# --- the plan -----------------------------------------------------------------

NEXT_PHASE = pathlib.Path(__file__).resolve().parent.parent / 'next-phase.py'
FIELD_MAX = 300
_READER = None


def _reader():
    """`next-phase.py`, loaded once and kept: the hyphen in the filename
    stops `import`, not `spec_from_file_location`."""
    global _READER
    if _READER is None:
        spec = importlib.util.spec_from_file_location('wf_next_phase',
                                                      NEXT_PHASE)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _READER = mod
    return _READER


def selection(path=None, text=None):
    """The plan, read by its single reader: `next-phase.py`, in process.

    The plan format is that script's contract — markers, notes, `Run:`,
    `Verify:`, the header fields and which phase comes next. A second
    implementation here is what this replaces: it was a frozen copy of a
    shipped regex, and it disagreed with the original about the outcomes.
    A plan held in a branch rather than on disk comes in as text.

    Any failure degrades to `None`: every caller answers "no plan" to it,
    and a plan that cannot be read must not turn a page into a 500.
    """
    try:
        reader = _reader()
        if text is not None:
            parsed = reader.parse_lines(text.splitlines())
            arg = '-'
        else:
            parsed = reader.parse(path)
            arg = str(path)
        sel = reader.payload(arg, *parsed)
    except Exception:
        return None
    for ph in sel['phases']:
        for field in ph['notes'] + ph['verify']:
            field['text'] = _short(field['text'], FIELD_MAX)
    return sel


def plan_shape(path, slug, directory, sel, foreman_dir=None):
    """The dict every consumer of a plan reads, from the selection payload.

    One builder for the active plan and for a finished one: the second is read
    out of `done/` or out of the branch that kept it, and must answer the same
    questions.
    """
    phases, meta = sel['phases'], sel['meta']
    return {
        'path': str(path), 'slug': slug, 'dir': str(directory),
        'phases': phases,
        'done': sum(1 for p in phases if p['status'] == 'x'),
        'total': len(phases),
        'next': sel['next'], 'blocked_by': sel['blocked_by'],
        'recommendation': sel['recommendation'],
        'mode': meta.get('mode'), 'parent': meta.get('parent'),
        'quality': meta.get('quality_check'),
        'foreman': read_foreman(foreman_dir) if foreman_dir else None,
    }


def active_slug(repo):
    """The active plan's slug, named by its directory — no parse.

    `read_plan` answers the same question by reading the whole plan; a caller
    that only needs the name should not pay for that.
    """
    found = sorted(pathlib.Path(repo).glob('.phased/active/*/plan.md'))
    return found[0].parent.name if found else None


def read_plan(repo):
    """The active plan: phases, markers, Run:, notes. None when there is none."""
    found = sorted(pathlib.Path(repo).glob('.phased/active/*/plan.md'))
    if not found:
        return None
    plan = found[0]
    sel = selection(path=plan)
    if sel is None:
        return None
    return plan_shape(plan, plan.parent.name, plan.parent, sel, plan.parent)


def finished_plan(repo):
    """The last workflow that was FINALIZED, when no plan is active.

    Without this the last stage of the lifecycle strip can never light: the
    proof it looks for is a plan directory under `.phased/done/`, and the only
    source of a plan was the `active/` glob — so the condition was unreachable
    on every real path, and a finalized workflow left the page on its no-plan
    state with nothing to say about what had just been built.

    Two places to look, in order, and the second is not an edge case: finalize
    drops `.phased/` from the squash that reaches the parent, so on the parent
    branch a closed workflow survives only on the `wf/` branch that produced
    it. Phase 2 established that a branch is the same kind of fact as a
    directory.
    """
    on_disk = [e for e in all_plan_dirs(repo) if e['state'] == 'done']
    if on_disk:
        entry = max(on_disk, key=lambda e: pathlib.Path(e['dir']).stat().st_mtime)
        path = pathlib.Path(entry['dir']) / 'plan.md'
        sel = selection(path=path)
        if sel:
            return plan_shape(path, entry['slug'], entry['dir'], sel,
                              entry['dir'])
    # The LAST finalized, on branches too: candidates are ordered by the date
    # of the commit that last touched each plan on its own branch — taking the
    # first branch the listing happens to name returns whichever slug sorts
    # first, not the workflow that finished most recently.

    def finalized_at(entry):
        ts = git(repo, 'log', '-1', '--format=%ct',
                 entry['branch'], '--', entry['path']).strip()
        return int(ts) if ts.isdigit() else 0

    on_branch = [e for e in branch_plan_dirs(repo) if e['state'] == 'done']
    for entry in sorted(on_branch, key=finalized_at, reverse=True):
        text = git(repo, 'show', f"{entry['branch']}:{entry['path']}")
        if not text:
            continue
        sel = selection(text=text)
        if sel is None:
            continue
        # The dir carries the `done/` path the branch holds it at, which is what
        # `lifecycle` reads as the proof of finalization.
        directory = str(pathlib.PurePosixPath(entry['path']).parent)
        return plan_shape(entry['dir'], entry['slug'], f'/{directory}', sel)
    return None


def read_foreman(plan_dir):
    f = pathlib.Path(plan_dir) / 'foreman.json'
    if not f.is_file():
        return None
    try:
        return json.loads(f.read_text())
    except ValueError:
        return None


def all_plan_dirs(repo):
    """Every plan directory of the repo, with where it sits.

    The position IS the state of a macro-phase — `done/` closed, `active/` in
    progress — never a judgment this tool makes.
    """
    out = []
    for state in ('active', 'done'):
        for d in sorted(pathlib.Path(repo).glob(f'.phased/{state}/*')):
            if (d / 'plan.md').is_file():
                out.append({'slug': d.name, 'dir': str(d), 'state': state})
    return out


def text_stamps(repo):
    """When each plan text last changed, so the page can drop a cached copy.

    The page reads a plan's own words once per phase and keeps them: re-reading
    the file on every poll would fight the reader, and the file changes rarely.
    Rarely is not never — a plan rewritten under an open pane left the pane
    showing words that were no longer on disk. These mtimes travel with the
    tick, and a copy cut from a different one is re-read.

    Only what a mtime can answer for: a plan read out of a `wf/` branch is not
    named here, git having no rewrite for it.
    """
    plans = {}
    for entry in all_plan_dirs(repo):
        try:
            plans[entry['slug']] = (pathlib.Path(entry['dir'])
                                    / 'plan.md').stat().st_mtime
        except OSError:
            pass
    try:
        road = (pathlib.Path(repo) / '.phased' / 'roadmap.md').stat().st_mtime
    except OSError:
        road = None
    return {'plans': plans, 'roadmap': road}


GIT_TIMEOUT = 15
BRANCH_PLAN_RE = re.compile(r'^\.phased/(done|active)/([^/]+)/plan\.md$')


def git(repo, *args):
    """A git command that never raises: a mute repo is zero results."""
    try:
        out = subprocess.run(['git', '-C', str(repo), *args], capture_output=True,
                             text=True, timeout=GIT_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return ''
    return out.stdout if out.returncode == 0 else ''


def plan_commit(repo, slug):
    """The `wf: plan for <slug>` commit — the artifact that says the plan exists.

    Searched over every ref, not the current branch. Finalize squashes the
    workflow into one commit on the parent, so afterwards the plan commit
    survives only on the `wf/` branch that produced it — and a strip that read
    the current branch alone showed the FIRST stage as still running on a
    workflow that had finished. The slug is in the pattern, so a wider search
    cannot match another workflow's commit.
    """
    return git(repo, 'log', '-1', '--format=%h', '--all', '-E',
               f'--grep=^wf: plan for {re.escape(slug)}$').strip() or None


# Short labels: the strip sits in a header a third of a window wide, and the
# artifact that proves each stage is in the tooltip.
LIFECYCLE = (('planned', 'plan'), ('executing', 'exec'),
             ('quality', 'quality'), ('finalized', 'final'))


def lifecycle(repo, plan):
    """The four macro stages of a workflow, each with the artifact that proves it.

    Nothing is predicted and no stage is inferred from another: the plan
    commit, the phase markers, the quality stamp, the plan directory moved
    under `.phased/done/`. Scoping has no stage here — it leaves no artifact.

    A stage whose artifact exists is `done`, the first one whose artifact is
    missing is `now`, the rest are `todo`.
    """
    proofs = {
        'planned': plan_commit(repo, plan['slug']),
        'executing': (f"{plan['done']}/{plan['total']} phases closed"
                      if plan['total'] and plan['done'] == plan['total'] else None),
        'quality': plan['quality'],
        'finalized': plan['dir'] if '/.phased/done/' in plan['dir'] else None,
    }
    out, reached = [], False
    for key, label in LIFECYCLE:
        proof = proofs[key]
        if proof:
            state = 'done'
        elif reached:
            state = 'todo'
        else:
            state, reached = 'now', True
        out.append({'key': key, 'label': label, 'state': state,
                    'proof': _short(proof, 120) if proof else None})
    return out


def branch_tips(repo):
    return git(repo, 'for-each-ref', '--format=%(objectname) %(refname:short)',
               'refs/heads')


def branch_plan_dirs(repo):
    """The plans that live on a branch and not in the working tree.

    /wf:finalize-workflow drops `.phased/` from the squash that reaches the
    parent, so the `done/<slug>/` of a closed workflow survives only on the
    `wf/` branch that produced it. Reading it there is the same kind of fact as
    reading a directory, and it is what tells a macro-phase closed elsewhere
    from one nobody ever started.

    A slug appearing on several branches is taken once, from the first.
    """
    seen, out = set(), []
    for line in branch_tips(repo).splitlines():
        _, _, branch = line.partition(' ')
        listing = git(repo, 'ls-tree', '-r', '--name-only', branch,
                      '.phased/done/', '.phased/active/')
        for path in listing.splitlines():
            m = BRANCH_PLAN_RE.match(path)
            if m and m.group(2) not in seen:
                seen.add(m.group(2))
                out.append({'slug': m.group(2), 'state': m.group(1),
                            'branch': branch, 'path': path,
                            'dir': f'{branch}:{path}'})
    return out


PHASE_COMMIT_RE = re.compile(r'^wf\(phase (\d+)\)')


def phase_windows(repo, plan):
    """When each phase was running, read from the commits around it.

    A phase run unattended has no titled chat, so the title says nothing and
    the only other record of when it happened is the workflow's own commits.
    The window of phase N opens at the last `wf(phase M):` commit with M < N —
    the moment the previous phase stopped writing — and closes at phase N's
    own LAST `wf(phase N):` commit. The plan commit opens the first window.
    The other `wf:` commits (clarifications, re-phasings, notes) never bound
    anything: they happen between phases and inside them alike.

    A `[>]` phase has no end to its window — `None` stands for it, and
    `window_phase` reads it as still open. That holds even when the phase has
    already committed a partial: the phase is still running, so chats opened
    after that commit still belong to it.

    Only a phase carrying `log/phase-N.txt` gets a window at all. That log is
    what an unattended run leaves behind, and an unattended run is the only
    thing this attribution exists to catch.
    """
    base = git(repo, 'log', '-1', '--diff-filter=A', '--format=%H %cI', '--', plan['path']).split()
    if len(base) != 2:
        return {}
    log = git(repo, 'log', '--reverse', '--format=%cI|%s', f'{base[0]}..HEAD')
    commits = []
    for line in log.splitlines():
        ts, _, subject = line.partition('|')
        m = PHASE_COMMIT_RE.match(subject)
        when = _when(ts)
        if m and when:
            commits.append((when, int(m.group(1))))
    # Attribution by window serves ONE case: a phase that ran unattended, whose
    # chat never took the protocol title. That run leaves `log/phase-N.txt`, so
    # the log is the positive evidence a window needs to exist at all. Without
    # it an open window swallows any chat whose cwd is the repo — the owner's own
    # interactive chat included — and folds its turns and cost into the phase.
    logs = phase_logs(plan['dir'])
    out = {}
    for ph in plan['phases']:
        n = ph['n']
        if n not in logs:
            continue
        mine = [t for t, k in commits if k == n]
        earlier = [t for t, k in commits if k < n]
        lo = max(earlier) if earlier else _when(base[1])
        # The `[>]` test comes FIRST: a running phase that already committed a
        # partial keeps an open window. Closing it at that commit drops every
        # chat opened afterwards to continue the phase — which is what a long
        # phase and a repair both do.
        if ph['status'] == '>':
            hi = None
        elif mine:
            hi = max(mine)
        else:
            continue
        if lo:
            out[n] = (lo, hi)
    return out


def window_phase(windows, scan, repo):
    """The phase a transcript belongs to, judged by when it started.

    The FIRST assistant row is what says which phase the session was opened
    for. The last one says nothing: closing a phase is work that happens
    after its commit, so every phase chat outlives its own window.

    Two facts must hold besides the time, because a wrong attribution is
    worse than a missing one — the `vs median` column is read to judge a
    phase. The session ran in this repository, and the window it falls in is
    the only one: a start on the boundary between two windows is attributed
    to neither.
    """
    if not scan.cwd or os.path.abspath(scan.cwd) != repo:
        return None
    start = _when(scan.first_ts)
    if start is None:
        return None
    hits = [n for n, (lo, hi) in windows.items()
            if lo <= start and (hi is None or start <= hi)]
    return hits[0] if len(hits) == 1 else None


def phase_logs(plan_dir):
    out = {}
    for f in sorted(pathlib.Path(plan_dir).glob('log/phase-*.txt')):
        m = re.search(r'phase-(\d+)', f.name)
        if m:
            st = f.stat()
            out[int(m.group(1))] = {'path': str(f), 'size': st.st_size,
                                    'mtime': st.st_mtime}
    return out


# --- the whole ----------------------------------------------------------------

TITLE_PHASE_RE = re.compile(r'wf:(?P<slug>[^:]+):(?P<role>phase|repair|foreman)-?(?P<n>\d+)?')


class Board:
    """Keeps the Scans open between one request and the next."""

    def __init__(self, repo):
        self.repo = os.path.abspath(os.path.expanduser(repo))
        self.scans = {}
        # The plans read from the branches, and the tips they were read at:
        # rereading them on every poll costs one git per branch, and branches
        # move slowly.
        self.branch_plans = {}
        self.branch_tips = None

    def _scan(self, path):
        s = self.scans.get(str(path))
        if s is None:
            s = self.scans[str(path)] = Scan(path)
        return s.update()

    def agents(self, slug=None, windows=None):
        """One panel per chat, its subagents nested under it.

        A subagent inherits the phase of the chat that spawned it. A chat
        titled for another plan's slug keeps phase None: its numbers must
        never enter this plan's per-phase figures.

        A chat carrying no `wf:` title at all is the unattended case, and
        `windows` attributes it by the time it ran. A title always wins where
        both would apply: the chat declared itself, and a declaration beats an
        inference. `phase_from` says which of the two answered, so the page can
        show an inferred attribution as inferred.
        """
        d = project_dir(self.repo)
        if d is None:
            return []
        live = live_sessions()
        panels = []
        for f in glob.glob(str(d / '*.jsonl')):
            sid = pathlib.Path(f).stem
            s = self._scan(f)
            if not s.turns:
                continue
            rec = live.get(sid)
            title = s.title or (rec or {}).get('name') or ''
            m = TITLE_PHASE_RE.match(title or '')
            mine = bool(m) and (slug is None or m.group('slug') == slug)
            phase = int(m.group('n')) if mine and m.group('n') else None
            phase_from = 'title' if phase else None
            if m is None and windows:
                phase = window_phase(windows, s, self.repo)
                phase_from = 'window' if phase else None
            chat = s.panel(
                'chat', sid[:8], title or sid[:8], s.first_prompt,
                {'session_id': sid, 'live': rec is not None,
                 'pid': (rec or {}).get('pid'),
                 'role': m.group('role') if m else None,
                 'plan_slug': m.group('slug') if m else None,
                 'phase': phase, 'phase_from': phase_from,
                 'todos': read_todos(sid), 'subagents': []})
            panels.append(chat)
            for meta_path in glob.glob(str(d / sid / 'subagents' / '*.meta.json')):
                jl = meta_path.replace('.meta.json', '.jsonl')
                if not os.path.exists(jl):
                    continue
                try:
                    meta = json.loads(open(meta_path).read())
                except ValueError:
                    meta = {}
                sa = self._scan(jl)
                if not sa.turns:
                    continue
                aid = pathlib.Path(jl).stem.replace('agent-', '')
                chat['subagents'].append(sa.panel(
                    'subagent', aid[:8], meta.get('agentType') or 'agent',
                    meta.get('description') or sa.first_prompt,
                    {'parent': sid[:8], 'parent_live': sid in live,
                     'depth': meta.get('spawnDepth'),
                     'plan_slug': m.group('slug') if m else None,
                     'phase': phase, 'phase_from': phase_from}))
            chat['subagents'].sort(key=lambda p: (not p['active'], -(p['mtime'] or 0)))
        panels.sort(key=lambda p: (not p['active'], -(p['mtime'] or 0)))
        return panels

    def state(self):
        plan = read_plan(self.repo)
        windows = phase_windows(self.repo, plan) if plan else {}
        chats = self.agents(plan['slug'] if plan else None, windows)
        flat = flatten(chats)
        alerts = build_alerts(plan, flat)
        totals = {
            'agents': len(flat),
            'active': sum(1 for a in flat if a['active']),
            'turns': sum(a['turns'] for a in flat),
            'output': sum(a['output'] for a in flat),
            'reread': sum(a['reread'] for a in flat),
            'usd': round(sum(a['usd'] for a in flat), 2),
            # Models with no entry in the price table add tokens and no dollars.
            # Every panel already records its own; collected here because a
            # total that silently omits part of the spend is worse than no
            # total, and the page must be able to say so.
            'unpriced': sorted({m for a in flat for m in (a.get('unpriced') or ())}),
        }
        totals['ratio'] = round(totals['reread'] / totals['output'], 1) if totals['output'] else 0
        if plan:
            plan['logs'] = phase_logs(plan['dir'])
            plan['median_ratio'] = median_phase_ratio(plan, flat)
            plan['lifecycle'] = lifecycle(self.repo, plan)
        # With no plan active, the last FINALIZED one — so the page can say what
        # was built here instead of only that nothing is running, and so the
        # last stage of the lifecycle strip has a workflow to be true of. It is
        # deliberately not `plan`: the no-plan state keeps its Create form, and
        # nothing that acts on a plan may act on a finished one.
        finished = None
        if plan is None:
            finished = finished_plan(self.repo)
            if finished:
                finished['lifecycle'] = lifecycle(self.repo, finished)
        return {'generated': time.time(), 'repo': self.repo, 'plan': plan,
                'finished': finished,
                'chats': chats, 'groups': group_chats(chats),
                'alerts': alerts, 'totals': totals,
                'stamps': text_stamps(self.repo),
                'tree': self.tree(plan, flat)}

    def tree(self, plan, agents):
        """The tree, with the plans of the other macro-phases read from disk.

        The per-phase figures stay those of the active plan: a chat carries its
        plan's slug in its title, and attributing another plan's chats is not
        this phase's work.
        """
        by_phase = {}
        for a in agents:
            if a.get('phase'):
                by_phase.setdefault(a['phase'], []).append(a)
        if plan:
            for ph in plan['phases']:
                ph.update(roadmap.phase_icon(ph, by_phase.get(ph['n'], ())))
                ph['checks'] = checks.phase_checks(ph)
        plans, here = [], set()
        for entry in all_plan_dirs(self.repo):
            here.add(entry['slug'])
            if plan and entry['slug'] == plan['slug']:
                plans.append(dict(entry, phases=plan['phases']))
                continue
            sel = selection(path=pathlib.Path(entry['dir']) / 'plan.md')
            phases = sel['phases'] if sel else []
            for ph in phases:
                ph.update(roadmap.phase_icon(ph))
            plans.append(dict(entry, phases=phases))
        plans.extend(p for p in self.plans_on_branches() if p['slug'] not in here)
        return roadmap.build_tree(roadmap.read_roadmap(self.repo), plans,
                                  plan['slug'] if plan else None)

    def plans_on_branches(self):
        """The closed plans that live only on a branch, reread when the tips move."""
        tips = branch_tips(self.repo)
        if tips == self.branch_tips:
            return list(self.branch_plans.values())
        self.branch_tips = tips
        self.branch_plans = {}
        for entry in branch_plan_dirs(self.repo):
            text = git(self.repo, 'show', f"{entry['branch']}:{entry['path']}")
            if not text:
                continue
            sel = selection(text=text)
            phases = sel['phases'] if sel else []
            for ph in phases:
                ph.update(roadmap.phase_icon(ph))
            self.branch_plans[entry['slug']] = dict(entry, phases=phases)
        return list(self.branch_plans.values())


def flatten(chats):
    """Chats and their subagents, one flat list."""
    out = []
    for c in chats:
        out.append(c)
        out.extend(c['subagents'])
    return out


def group_chats(chats):
    """The grouping the page renders: phase -> chats, plus the ones outside.

    Keys of by_phase are strings: the dict crosses JSON.
    """
    by_phase, off_plan = {}, []
    for c in chats:
        if c['phase']:
            by_phase.setdefault(str(c['phase']), []).append(c['session_id'])
        else:
            off_plan.append(c['session_id'])
    return {'by_phase': by_phase, 'off_plan': off_plan}


def median_phase_ratio(plan, agents):
    per = {}
    for a in agents:
        if a.get('phase') and a['output']:
            per.setdefault(a['phase'], []).append(a)
    vals = []
    for n, group in per.items():
        out = sum(a['output'] for a in group)
        rd = sum(a['reread'] for a in group)
        if out:
            vals.append(rd / out)
    return round(sorted(vals)[len(vals) // 2], 1) if vals else None


def build_alerts(plan, agents):
    """Checkable facts only. No prediction."""
    out = []
    if plan is None:
        out.append({'level': 'warn', 'text': 'no plan in .phased/active/'})
        return out
    for p in plan['phases']:
        if p['status'] == '!':
            out.append({'level': 'error', 'phase': p['n'],
                        'text': f'phase {p["n"]} failed — /wf:repair-phase'})
        elif p['status'] == '~':
            out.append({'level': 'warn', 'phase': p['n'],
                        'text': f'phase {p["n"]} blocked'})
        elif p['status'] == '>':
            testing = [n for n in p['notes'] if n['kind'] == 'Testing']
            if testing:
                out.append({'level': 'info', 'phase': p['n'],
                            'text': f'phase {p["n"]} awaits the human checks — '
                                    f'/wf:close-phase once they pass'})
            else:
                out.append({'level': 'warn', 'phase': p['n'],
                            'text': f'phase {p["n"]} running'})
    for a in agents:
        if a['errors'] and a['active']:
            out.append({'level': 'warn',
                        'text': f'{a["name"]}: {a["errors"]} API errors in the transcript'})
    med = median_phase_ratio(plan, agents)
    if med:
        for a in agents:
            if a['active'] and a['output'] and a['ratio'] > 2 * med:
                out.append({'level': 'warn',
                            'text': f'{a["name"]}: reread/output {a["ratio"]:.0f}, '
                                    f'{a["ratio"] / med:.1f}x the plan median'})
    return out

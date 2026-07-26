#!/usr/bin/env python3
"""Sync this repo's skill sources to the Sourcerer knowledge base.

Why this exists
---------------
The repo is the source of truth; the KB is how the skills reach other machines
(`/update-skills` pulls from it). Nothing kept the two in step, so they drifted:
the KB served an older chain than the repo for an unknown stretch of time, and
reconciling by hand meant retyping ~90KB of markdown with the transcription
risk that implies.

Two things make that safe to automate:

1. **Three-way merge, not overwrite.** KB entries are not byte-copies of the
   repo files — several carry an "Installation:" preamble or a cross-reference
   to a sibling skill that only makes sense inside the KB. A blind overwrite
   silently deletes those. So we merge the repo's *changes* into the KB's
   *current* text (`git merge-file KB base=old-repo other=new-repo`), which
   preserves KB-only edits and reports a conflict instead of guessing.
2. **A recorded base.** The merge needs to know which repo commit the KB
   currently reflects. That is kept in `tools/.kb-sync-state.json` and updated
   only on a successful `--apply`.

Credentials are read at runtime from the local Claude MCP config. Nothing
secret is stored in this file, printed, or written to the state file.

Usage
-----
    tools/kb-sync.py                 # dry run: what would change, per file
    tools/kb-sync.py --apply         # push, then record the new base
    tools/kb-sync.py --base <ref>    # override the recorded base commit
    tools/kb-sync.py --only run-all-phases finalize-workflow

Exit status is non-zero if any file conflicts, so CI can gate on it.
"""
import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.request
import uuid

REPO = pathlib.Path(__file__).resolve().parent.parent
STATE = REPO / 'tools' / '.kb-sync-state.json'
MCP_CONFIG = pathlib.Path(os.environ.get('CLAUDE_CONFIG', pathlib.Path.home() / '.claude.json'))
TOPIC = 'Crew/Workflow/Phased Workflow'

# repo path -> KB skill title. Titles that are not simply the skill directory
# name are the ones a blind name-match would miss.
MAPPING = {
    'plugins/phased-workflow/skills/write-workflow/SKILL.md': 'write-workflow',
    'plugins/phased-workflow/skills/execute-phase/SKILL.md': 'execute-phase',
    'plugins/phased-workflow/skills/auto-phase/SKILL.md': 'auto-phase',
    'plugins/phased-workflow/skills/run-all-phases/SKILL.md': 'run-all-phases',
    'plugins/phased-workflow/skills/repair-phase/SKILL.md': 'repair-phase',
    'plugins/phased-workflow/skills/finalize-workflow/SKILL.md': 'finalize-workflow',
    'plugins/phased-workflow/skills/check-phase-context/SKILL.md': 'check-phase-context',
    'plugins/phased-workflow/skills/create-context/SKILL.md': 'create-context',
    'plugins/phased-workflow/skills/close-context/SKILL.md': 'close-context',
    'plugins/phased-workflow/skills/clean-contexts/SKILL.md': 'clean-contexts',
    'plugins/phased-workflow/skills/pull-request/SKILL.md': 'pull-request',
    'plugins/phased-workflow/skills/issue/SKILL.md': 'issue',
    'plugins/phased-workflow/skills/clean-memories/SKILL.md': 'clean-memories',
    'plugins/phased-workflow/refs/common.md': 'Phased Workflow — shared conventions (common.md)',
    'plugins/phased-workflow/refs/write-workflow-autonomous.md': 'write-workflow — autonomous (robottino) addendum',
    'plugins/phased-workflow/agents/phase-verifier.md': 'phase-verifier subagent',
    'docs/loop-engineering.md': 'Loop engineering — self-correcting autonomous chain',
}

# Repo files the KB embeds inside a fenced block rather than holding verbatim.
# A three-way text merge of a .py against a markdown page is nonsense, so these
# are synced by replacing the fence body and nothing else.
EMBEDDED = {
    'plugins/phased-workflow/scripts/next-phase.py':
        ('next-phase.py — deterministic phase selection script', 'python'),
    'plugins/phased-workflow/scripts/run-all-phases.sh':
        ('run-all-phases.sh — autonomous phase loop launcher', 'bash'),
}

# KB entries with no counterpart in this repo, on purpose. Listed so `--audit`
# reports them as known rather than as a gap — an unexplained KB-only entry is
# how drift starts.
KB_ONLY = {
    'Guida ai comandi — Phased Workflow': 'KB-authored command guide (Italian)',
    'Install Phased Workflow Plugin': 'KB-authored install instructions',
    'open-context': 'command not shipped by the plugin',
    'push-context-memory': 'Sourcerer-specific, internal machines only',
    'ui-test': 'GenroPy-specific, internal machines only',
    'Worktree GenroPy runtime isolation': 'genropy-worktree plugin note',
}


# --------------------------------------------------------------------------
# MCP client (streamable HTTP)
# --------------------------------------------------------------------------
class KB:
    def __init__(self):
        try:
            cfg = json.loads(MCP_CONFIG.read_text())['mcpServers']['sourcerer']
        except (OSError, KeyError) as e:
            sys.exit(f'kb-sync: no sourcerer MCP server in {MCP_CONFIG} ({e})')
        self.url = cfg['url']
        self.headers = dict(cfg.get('headers', {}))
        self.headers.update({'Content-Type': 'application/json',
                             'Accept': 'application/json, text/event-stream'})
        self.session = {}
        self._rpc('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                                 'clientInfo': {'name': 'kb-sync', 'version': '1'}})
        self._rpc('notifications/initialized', {}, notify=True)

    def _rpc(self, method, params=None, notify=False):
        body = {'jsonrpc': '2.0', 'method': method}
        if params is not None:
            body['params'] = params
        if not notify:
            body['id'] = str(uuid.uuid4())
        headers = {**self.headers, **self.session}
        req = urllib.request.Request(self.url, data=json.dumps(body).encode(),
                                     headers=headers, method='POST')
        with urllib.request.urlopen(req, timeout=180) as r:
            sid = r.headers.get('Mcp-Session-Id')
            if sid:
                self.session['Mcp-Session-Id'] = sid
            raw = r.read().decode()
        if notify or not raw.strip():
            return None
        for line in raw.splitlines():                    # SSE-framed payloads
            if line.strip().startswith('data:'):
                return json.loads(line.split('data:', 1)[1].strip())
        return json.loads(raw)

    def call(self, tool, args):
        res = self._rpc('tools/call', {'name': tool, 'arguments': args})
        if not res or 'error' in res:
            raise RuntimeError(f'{tool}: {json.dumps(res)[:300]}')
        return json.loads(res['result']['content'][0]['text'])

    def index(self):
        """title -> skill id, for the phased-workflow topic."""
        data = self.call('kb.get_skills', {'topic': TOPIC})['data']
        return {s['title']: s['id'] for s in data}

    def get(self, skill_id):
        return self.call('kb.get_skill_content', {'skill_id': skill_id})['data']['content']

    def put(self, skill_id, content):
        return self.call('kb.update_skill', {'skill_id': skill_id, 'content': content})

    def add(self, title, content, description):
        return self.call('kb.add_skill', {'title': title, 'topic': TOPIC,
                                          'content': content, 'description': description})


# --------------------------------------------------------------------------
def git(*args):
    return subprocess.run(['git', '-C', str(REPO), *args],
                          capture_output=True, text=True, check=True).stdout


SECTION_HEADING = '## Frontmatter for the command file'
FRONTMATTER_SECTION = """
---

{heading}

Write this block at the top of `~/.claude/commands/{name}.md`. It is part of the
skill, not machine-local configuration: `allowed-tools` pre-approves the steps
above, so an incomplete list makes a documented step stop and ask. It is checked
against this body by `tests/orchestration/check_allowlists.py` in the repo.

```yaml
---
{frontmatter}
---
```
"""


def split_frontmatter(text):
    """(frontmatter, body), or (None, text) when the file has none."""
    if not text.startswith('---\n'):
        return None, text
    end = text.find('\n---\n', 3)
    if end == -1:
        return None, text
    return text[4:end].strip(), text[end + 5:].lstrip('\n')


def strip_frontmatter(text):
    return split_frontmatter(text)[1]


def with_frontmatter_section(kb_text, repo_text, name, is_command):
    """Publish the command's frontmatter as an install block at the end.

    A KB entry must not *start* with frontmatter: `/update-skills` reads the
    entry as a body and keeps the local block, so an entry beginning with `---`
    would land duplicated in the installed file. But dropping the frontmatter
    entirely is how the KB came to publish commands with no `allowed-tools` at
    all — the same defect as a repo skill shipping without one, a channel
    further out. So the body stays first and the frontmatter follows explicitly.

    Idempotent, and applied to the merge *result* rather than its inputs: a
    three-way merge only propagates differences, so it can never introduce a
    section that neither side has. It also replaces a hand-written frontmatter
    section under any heading — `repair-phase` carried one whose allowlist had
    since gone stale, which is the drift this closes."""
    frontmatter = split_frontmatter(repo_text)[0]
    if not is_command or frontmatter is None:
        return kb_text
    section = FRONTMATTER_SECTION.format(heading=SECTION_HEADING, name=name,
                                         frontmatter=frontmatter)
    m = re.search(r'^#{2,3} .*[Ff]rontmatter.*$', kb_text, re.M)
    if not m:
        return kb_text.rstrip('\n') + '\n' + section
    cut = m.start()
    rule = kb_text.rfind('\n---\n', 0, cut)             # the section's own rule, if any
    if rule != -1 and kb_text[rule:cut].strip() == '---':
        cut = rule
    return kb_text[:cut].rstrip('\n') + '\n' + section


def merge(kb_text, base_text, new_text):
    """Apply base->new onto kb_text. Returns (merged, conflicted)."""
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for name, text in (('kb', kb_text), ('base', base_text), ('new', new_text)):
            p = pathlib.Path(d, name)
            p.write_text(text, encoding='utf-8')
            paths.append(str(p))
        r = subprocess.run(['git', 'merge-file', '-p', *paths],
                           capture_output=True, text=True)
        return r.stdout, r.returncode != 0


def create_missing(kb, apply):
    """Create the mapped skills the KB topic does not have yet.

    Hand-copying a 7KB skill body into the KB is the transcription risk this
    tool exists to remove, so the creation path belongs here too. The KB holds
    body only — `/update-skills` preserves the local frontmatter — and the
    frontmatter's own `description:` becomes the KB description."""
    index = kb.index()
    made = 0
    for rel, title in MAPPING.items():
        if title in index:
            continue
        text = (REPO / rel).read_text(encoding='utf-8')
        body = strip_frontmatter(text)
        desc = re.search(r'^description:\s*(.+)$', text[:text.find('\n---\n', 3) + 1], re.M) \
            if text.startswith('---\n') else None
        desc = desc.group(1).strip() if desc else title
        print(f'  {title:<52} create from {rel} ({len(body)} bytes)')
        if apply:
            kb.add(title, body, desc)
            made += 1
    print(f'\n{made} created.' if apply else '\ndry run: re-run with --apply to create them.')
    return 0


def audit(kb):
    """Coverage in both directions: repo files nobody syncs, KB entries nobody
    owns. Either one is invisible until someone notices a colleague missing a
    command, which is exactly what happened with `pull-request`."""
    index = kb.index()
    managed = set(MAPPING.values()) | {t for t, _ in EMBEDDED.values()}
    problems = []

    print('repo -> KB')
    for d in sorted((REPO / 'plugins/phased-workflow/skills').glob('*/SKILL.md')):
        title = MAPPING.get(str(d.relative_to(REPO)))
        if not title:
            problems.append(f'  {d.parent.name:<24} NOT MAPPED — add it to MAPPING')
        elif title not in index:
            problems.append(f'  {d.parent.name:<24} mapped to "{title}", absent from the KB topic')
    for rel, title in list(MAPPING.items()) + [(r, t) for r, (t, _) in EMBEDDED.items()]:
        if not (REPO / rel).exists():
            problems.append(f'  {rel:<24} MAPPED BUT MISSING in the repo')
    print('\n'.join(problems) if problems else '  all mapped and present')

    print('\nKB -> repo')
    unowned = []
    for title in sorted(index):
        if title in managed:
            continue
        why = KB_ONLY.get(title)
        if why:
            print(f'  {title:<52} KB-only ({why})')
        else:
            unowned.append(f'  {title:<52} UNOWNED — map it or list it in KB_ONLY')
    print('\n'.join(unowned), end='\n' if unowned else '')
    problems += unowned

    print(f'\n{len(problems)} problem(s).')
    return 1 if problems else 0


def sync_embedded(kb, index, changed):
    """Replace the fenced body of a KB page with the repo file it embeds."""
    for rel, (title, lang) in EMBEDDED.items():
        skill_id = index.get(title)
        if not skill_id:
            print(f'  {title:<52} NOT IN KB — create it first')
            continue
        kb_text = kb.get(skill_id)
        m = re.search(rf'```{lang}\n(.*?)```', kb_text, re.S)
        if not m:
            print(f'  {title:<52} no ```{lang} block to sync into')
            continue
        file_text = (REPO / rel).read_text(encoding='utf-8')
        if m.group(1) == file_text:
            print(f'  {title:<52} unchanged (embedded)')
            continue
        merged = kb_text[:m.start(1)] + file_text + kb_text[m.end(1):]
        print(f'  {title:<52} embedded body differs — {len(m.group(1))} -> {len(file_text)} bytes')
        changed.append((skill_id, title, merged))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--apply', action='store_true', help='write to the KB (default: dry run)')
    ap.add_argument('--base', help='repo ref the KB currently reflects (default: recorded state)')
    ap.add_argument('--only', nargs='*', metavar='NAME', help='limit to these skill titles or paths')
    ap.add_argument('--audit', action='store_true',
                    help='report coverage gaps in both directions and exit')
    ap.add_argument('--create', action='store_true',
                    help='create mapped skills that the KB topic is missing, then exit')
    args = ap.parse_args()

    if args.audit:
        return audit(KB())
    if args.create:
        return create_missing(KB(), args.apply)

    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    base = args.base or state.get('base')
    if not base:
        sys.exit('kb-sync: no recorded base commit. Pass --base <ref> for the first run.')
    head = git('rev-parse', 'HEAD').strip()

    kb = KB()
    index = kb.index()

    print(f'base {base[:12]} -> HEAD {head[:12]}   topic: {TOPIC}\n')
    conflicts, changed, missing = [], [], []

    for rel, title in MAPPING.items():
        if args.only and title not in args.only and rel not in args.only:
            continue
        skill_id = index.get(title)
        if not skill_id:
            missing.append(title)
            print(f'  {title:<52} NOT IN KB — create it first')
            continue
        try:
            base_text = git('show', f'{base}:{rel}')
        except subprocess.CalledProcessError:
            print(f'  {title:<52} not at base {base[:12]} — skipped')
            continue
        new_text = (REPO / rel).read_text(encoding='utf-8')
        # Compare against what the KB actually holds, not against the recorded
        # base: a wrong base would then hide drift instead of causing it. The
        # base is only what the three-way merge needs.
        kb_text = kb.get(skill_id)
        name = rel.split('/skills/')[1].split('/')[0] if '/skills/' in rel else title
        base_body, new_body = strip_frontmatter(base_text), strip_frontmatter(new_text)
        bad = False
        if new_body == base_body or new_body.rstrip('\n') in kb_text:
            # Nothing to propagate: either the body did not move, or the KB
            # already carries it verbatim (several entries are "repo body plus a
            # KB-only preamble or tail" — an Installation: block, a
            # cross-reference map — and merging those conflicts on every edit
            # landing next to the KB-only part, permanently).
            merged = kb_text
        else:
            merged, bad = merge(kb_text, base_body, new_body)
        merged = with_frontmatter_section(merged, new_text, name, '/skills/' in rel)
        if merged == kb_text:
            print(f'  {title:<52} unchanged')
            continue
        note = 'CONFLICT' if bad else 'clean'
        print(f'  {title:<52} {note:<9} {len(kb_text)} -> {len(merged)} bytes'
              f'{"  (has KB-only edits)" if kb_text != base_body else ""}')
        if bad:
            conflicts.append(title)
            continue
        changed.append((skill_id, title, merged))

    if not args.only:
        sync_embedded(kb, index, changed)

    if conflicts:
        print(f'\n{len(conflicts)} conflict(s): {", ".join(conflicts)}')
        print('Resolve by hand, or re-run with --only for the rest. Nothing was written.')
        return 1
    if missing:
        print(f'\n{len(missing)} skill(s) absent from the KB — add them before syncing.')

    if not args.apply:
        print(f'\ndry run: {len(changed)} skill(s) would be updated. Re-run with --apply.')
        return 0

    for skill_id, title, content in changed:
        kb.put(skill_id, content)
        print(f'  pushed  {title}')
    STATE.write_text(json.dumps({'base': head, 'topic': TOPIC}, indent=2) + '\n')
    print(f'\n{len(changed)} pushed. Base recorded as {head[:12]}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

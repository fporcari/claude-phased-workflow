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
    'plugins/phased-workflow/refs/common.md': 'Phased Workflow — shared conventions (common.md)',
    'plugins/phased-workflow/refs/write-workflow-autonomous.md': 'write-workflow — autonomous (robottino) addendum',
    'plugins/phased-workflow/agents/phase-verifier.md': 'phase-verifier subagent',
    'docs/loop-engineering.md': 'Loop engineering — self-correcting autonomous chain',
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


# --------------------------------------------------------------------------
def git(*args):
    return subprocess.run(['git', '-C', str(REPO), *args],
                          capture_output=True, text=True, check=True).stdout


def strip_frontmatter(text):
    if not text.startswith('---\n'):
        return text
    end = text.find('\n---\n', 3)
    return text[end + 5:].lstrip('\n') if end != -1 else text


def align_frontmatter(kb_text, base_text, new_text):
    """KB entries carry no YAML frontmatter — `/update-skills` preserves the
    local one, so the KB deliberately holds body only. Merging a repo file that
    *does* have frontmatter against a KB body therefore conflicts on every
    frontmatter change, forever, for no reason. Drop it from the repo sides so
    the merge compares like with like."""
    if kb_text.startswith('---\n'):
        return base_text, new_text          # KB keeps frontmatter for this one
    return strip_frontmatter(base_text), strip_frontmatter(new_text)


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


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--apply', action='store_true', help='write to the KB (default: dry run)')
    ap.add_argument('--base', help='repo ref the KB currently reflects (default: recorded state)')
    ap.add_argument('--only', nargs='*', metavar='NAME', help='limit to these skill titles or paths')
    args = ap.parse_args()

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
        if base_text == new_text:
            print(f'  {title:<52} unchanged')
            continue
        kb_text = kb.get(skill_id)
        base_cmp, new_cmp = align_frontmatter(kb_text, base_text, new_text)
        if base_cmp == new_cmp:
            print(f'  {title:<52} unchanged (frontmatter only)')
            continue
        merged, bad = merge(kb_text, base_cmp, new_cmp)
        kb_only = kb_text != base_cmp
        note = 'CONFLICT' if bad else 'clean'
        print(f'  {title:<52} {note:<9} {len(kb_text)} -> {len(merged)} bytes'
              f'{"  (has KB-only edits)" if kb_only else ""}')
        if bad:
            conflicts.append(title)
            continue
        changed.append((skill_id, title, merged))

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

#!/usr/bin/env python3
"""wfdash core: grouping and slug isolation.

Builds a fake ~/.claude/projects tree and a fake repo with a plan, then
asserts on Board.state():

  - chats carry their subagents nested, and a subagent inherits the phase
    of the chat that spawned it;
  - a chat titled for ANOTHER plan's slug stays out of by_phase, so its
    numbers can never contaminate this plan's per-phase figures — the
    median defect found in the prototype (262.4 vs the correct 272.2).

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402

PLAN = """# Context: wf/myplan
Mode: interactive

## Work Plan
- [x] **Phase 1**: first phase
  - Run: opus / medium
  - Done: tests green
- [>] **Phase 2**: second phase
  - Run: opus / high
  > Testing: waiting for the human's checks
"""


def assistant_row(out, read, ts='2026-08-25T09:00:00Z'):
    return json.dumps({
        'type': 'assistant', 'timestamp': ts,
        'message': {'model': 'claude-opus-5',
                    'content': [{'type': 'text', 'text': 'done'}],
                    'usage': {'input_tokens': 10, 'output_tokens': out,
                              'cache_read_input_tokens': read}}})


def title_row(title):
    return json.dumps({'type': 'custom-title', 'customTitle': title})


def write_chat(project, sid, title, out, read, subagents=()):
    rows = [title_row(title), assistant_row(out, read)]
    (project / f'{sid}.jsonl').write_text('\n'.join(rows) + '\n')
    for aid, a_out, a_read in subagents:
        d = project / sid / 'subagents'
        d.mkdir(parents=True, exist_ok=True)
        (d / f'agent-{aid}.meta.json').write_text(
            json.dumps({'agentType': 'Explore', 'description': 'look around',
                        'spawnDepth': 1}))
        (d / f'agent-{aid}.jsonl').write_text(assistant_row(a_out, a_read) + '\n')


def build(tmp):
    repo = tmp / 'repo'
    plan_dir = repo / '.phased' / 'active' / 'myplan'
    plan_dir.mkdir(parents=True)
    (plan_dir / 'plan.md').write_text(PLAN)
    project = tmp / 'projects' / str(repo).replace('/', '-')
    project.mkdir(parents=True)
    # phase 2 of THIS plan, with one subagent
    write_chat(project, 'aaaa1111', 'wf:myplan:phase-2', 100, 20000,
               subagents=[('bbbb2222', 50, 5000)])
    # same phase number, ANOTHER plan: must stay off_plan
    write_chat(project, 'cccc3333', 'wf:otherplan:phase-2', 100, 900000)
    # no wf title at all
    write_chat(project, 'dddd4444', 'free exploration', 10, 100)
    return repo, project


def main():
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td)
        repo, _ = build(tmp)
        core.PROJECTS = tmp / 'projects'
        core.live_sessions = lambda: {}
        state = core.Board(str(repo)).state()

        # grouping: phase -> chat -> subagent
        assert state['groups']['by_phase'] == {'2': ['aaaa1111']}, state['groups']
        assert sorted(state['groups']['off_plan']) == ['cccc3333', 'dddd4444']
        mine = next(c for c in state['chats'] if c['session_id'] == 'aaaa1111')
        assert mine['phase'] == 2
        assert len(mine['subagents']) == 1
        sub = mine['subagents'][0]
        assert sub['kind'] == 'subagent' and sub['phase'] == 2
        assert sub['parent'] == 'aaaa1111'[:8]

        # slug isolation: the other plan's chat carries no phase...
        other = next(c for c in state['chats'] if c['session_id'] == 'cccc3333')
        assert other['phase'] is None and other['plan_slug'] == 'otherplan'
        # ...and the per-phase median only sees this plan's numbers:
        # (20000+5000)/(100+50) ~ 166.7, not contaminated by 900000/100.
        assert state['plan']['median_ratio'] == 166.7, state['plan']['median_ratio']

        # totals count chats and subagents alike
        assert state['totals']['agents'] == 4
        assert state['totals']['output'] == 100 + 50 + 100 + 10

        # no plan: state still answers
        empty = core.Board(td).state()
        assert empty['plan'] is None
    print('test_core: ok')


if __name__ == '__main__':
    main()

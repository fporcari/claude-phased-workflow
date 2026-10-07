import { expect, mock, test } from 'claude-code/testing'

const PLAN = `# Context: wf/foo
Mode: manual

## Work Plan
- [x] **Phase 1**: table foo
  - Run: opus / medium
- [ ] **Phase 2**: TH UI for foo  \`ui\`
  - Run: opus / low
`

const BAND = {
  plugin: 'wf-bar',
  component: 'AbovePrompt',
  requestId: 'AbovePrompt',
  viewport: { columns: 120, rows: 40 },
  props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100, scroll: { offset: 0, bodyRows: 10 }, view: {} },
} as const

type Chat = { turns?: number; messages?: unknown[] }

const FOREMAN_TITLE = { role: 'assistant', text: '', toolUses: [{ id: 't1', tool: 'mcp__ccd_session_mgmt__set_session_title', input: { session_id: 'self', title: 'wf:foo:foreman' } }] }
const THEMED = PLAN.replace('Mode: manual', 'Mode: manual\nTheme: Foo UI')
const titled = (title: string) => ({ role: 'assistant', text: '', toolUses: [{ id: 't2', tool: 'mcp__ccd_session_mgmt__set_session_title', input: { session_id: 'self', title } }] })
const TYPED_EXECUTE = { role: 'user', text: '<command-name>/wf:execute-phase</command-name>', toolUses: [] }
const CHATTER = { role: 'user', text: 'what does execute-phase do?', toolUses: [] }

function stubPlan(on, plan: string | null, chat: Chat = {}) {
  mock.clock(on)
  on('fs.list', () => ({ value: plan === null ? [] : [{ name: 'foo', kind: 'dir', size: 0, isLink: false }] }))
  on('fs.read', () => ({ value: plan ?? '' }))
  on('session.start', () => ({ cwd: '/work' }))
  on('session.turns', () => ({ value: chat.turns ?? 0 }))
  on('session.messages', () => ({ value: chat.messages ?? [] }))
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['drawn by Claude Code'] }))
}

function recordCommands(on) {
  const ran: string[] = []
  on('command.run', ($, e) => {
    ran.push(e.args ? `${e.command} ${e.args}` : e.command)
    return { text: '' }
  })
  return ran
}

function recordStatus(on) {
  const shown: (string | undefined)[] = []
  on('ui.status', ($, e) => {
    shown.push(e.text)
    return { value: undefined }
  })
  return shown
}

function answerSteps(on) {
  on('turn.step', async function* ($, e) {
    return { turnId: e.turnId, index: e.index, answer: 'ok', toolUses: [], stopReason: 'end_turn', usage: null }
  })
}

async function step($, extra = {}) {
  const stream = $.turn.step({ turnId: 't', index: 0, model: 'claude-opus-5-5', effort: 'low', messageCount: 1, ...extra })
  let r = await stream.next()
  while (r.done !== true) r = await stream.next()
  return r.value
}

async function pressNext($) {
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  await ui.press({ key: 'wf-next' })
  await ui.unmount()
}

// The arguments tell execute-phase the button set the model and effort.
const LAUNCH = ['model opus', 'effort low', 'wf:execute-phase wf-bar opus / low']

test('a new chat: the button sets the phase model and effort, then launches execute-phase, nothing to clear', async ($, on) => {
  stubPlan(on, PLAN)
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect(await ui.find({ type: 'Text', text: 'wf 1/2' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'TH UI for foo · foo' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: ' FOREMAN ' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: ' WORKER · Phase 2 ' })).toBeUndefined()
    const button = await ui.find({ key: 'wf-next' })
    expect(button?.props.label).toBe('▶ Phase 2 · opus / low')
    await ui.press({ key: 'wf-next' })
    await ui.unmount()
  }
  expect(ran).toEqual([...LAUNCH, ...LAUNCH])
})

test('the worker — it ran execute-phase — is cleared before the next phase', async ($, on) => {
  stubPlan(on, PLAN, { turns: 12, messages: [TYPED_EXECUTE] })
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: ' WORKER · Phase 2 ' })).toBeDefined()
  await ui.press({ key: 'wf-next' })
  expect(ran).toEqual(['clear', ...LAUNCH])
})

test('the foreman is never cleared and never builds: no button, the worker named instead', async ($, on) => {
  stubPlan(on, PLAN, { turns: 40, messages: [FOREMAN_TITLE, TYPED_EXECUTE] })
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: ' FOREMAN ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'wf 1/2' })).toBeDefined()
  expect(await ui.find({ key: 'wf-next' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'worker, in a new chat: Phase 2 · opus / low · TH UI for foo · foo' })).toBeDefined()
  await ui.press({ key: 'wf-menu' })
  for (const k of ['execute-phase', 'close-phase', 'repair-phase']) expect(await ui.find({ key: `wf-cmd-${k}` })).toBeUndefined()
  expect(await ui.find({ key: 'wf-cmd-quality-check' })).toBeDefined()
  expect(ran).toEqual([])
})

test('a chat with history and no role asks before clearing: the first press arms, the second runs', async ($, on) => {
  stubPlan(on, PLAN, { turns: 5, messages: [CHATTER] })
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  await ui.press({ key: 'wf-next' })
  expect(ran).toEqual([])
  expect((await ui.find({ key: 'wf-next' }))?.props.label).toBe('▶ clear this chat for Phase 2? press again')
  await ui.press({ key: 'wf-next' })
  expect(ran).toEqual(['clear', ...LAUNCH])
})

test('a chat that took the foreman title after it opened is read again at the press: nothing runs', async ($, on) => {
  const chat: Chat = { turns: 0, messages: [] }
  stubPlan(on, PLAN, chat)
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  chat.turns = 30
  chat.messages = [FOREMAN_TITLE]
  await ui.press({ key: 'wf-next' })
  expect(ran).toEqual([])
})



test('a main-loop request on another effort than the phase is flagged; subagents are not watched', async ($, on) => {
  stubPlan(on, PLAN)
  recordCommands(on)
  answerSteps(on)
  const shown = recordStatus(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  await pressNext($)
  shown.length = 0
  await step($)
  await step($, { effort: 'high', agentId: 'verifier' })
  await step($, { effort: 'high' })
  expect(shown).toEqual([undefined, '⚠ running claude-opus-5-5 / high — Phase 2 wants opus / low'])
})

test('since 6.49.0 the role leads the title and the theme ends it: the foreman', async ($, on) => {
  stubPlan(on, THEMED, { turns: 9, messages: [titled('Foreman · Foo UI')] })
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: ' FOREMAN ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'worker, in a new chat: Phase 2 · opus / low · TH UI for foo · Foo UI' })).toBeDefined()
})

test('since 6.49.0: the worker, cleared before the next phase', async ($, on) => {
  stubPlan(on, THEMED, { turns: 9, messages: [titled('Worker P1 · Foo UI')] })
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: ' WORKER · Phase 2 ' })).toBeDefined()
  await ui.press({ key: 'wf-next' })
  expect(ran).toEqual(['clear', ...LAUNCH])
})

test('another plan\'s foreman is not this plan\'s: no role, and the press asks first', async ($, on) => {
  stubPlan(on, THEMED, { turns: 9, messages: [titled('Foreman · Other plan')] })
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: ' FOREMAN ' })).toBeUndefined()
  await ui.press({ key: 'wf-next' })
  expect(ran).toEqual([])
})

test('no button while Claude works', async ($, on) => {
  stubPlan(on, PLAN)
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const busy = await $.ui.mount({ ...BAND, surface: 'terminal', props: { ...BAND.props, isWorking: true } })
  expect(await busy.find({ key: 'wf-next' })).toBeUndefined()
  await busy.unmount()
})

test('a checkout with no active plan draws nothing of its own', async ($, on) => {
  stubPlan(on, null)
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ key: 'wf-next' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'drawn by Claude Code' })).toBeDefined()
})

test('☰ wf opens the palette: every user command, the ones that fit now undimmed', async ($, on) => {
  stubPlan(on, PLAN)
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ key: 'wf-cmd-close-phase' })).toBeUndefined()
  await ui.press({ key: 'wf-menu' })
  expect((await ui.find({ key: 'wf-cmd-execute-phase' }))?.props.dimColor).toBe(false)
  expect((await ui.find({ key: 'wf-cmd-close-phase' }))?.props.dimColor).toBe(true)
  expect((await ui.find({ key: 'wf-cmd-dashboard' }))?.props.dimColor).toBe(false)
  await ui.press({ key: 'wf-cmd-dashboard' })
  expect(ran).toEqual(['wf:dashboard'])
  expect(await ui.find({ key: 'wf-cmd-dashboard' })).toBeUndefined()
})

test('a [>] phase offers close-phase, which runs without clearing the chat', async ($, on) => {
  stubPlan(on, PLAN.replace('[ ] **Phase 2', '[>] **Phase 2'))
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  await ui.press({ key: 'wf-menu' })
  expect((await ui.find({ key: 'wf-cmd-close-phase' }))?.props.dimColor).toBe(false)
  await ui.press({ key: 'wf-cmd-close-phase' })
  expect(ran).toEqual(['wf:close-phase'])
})

test('a command that needs its argument is drafted in the prompt, not run', async ($, on) => {
  stubPlan(on, PLAN)
  const ran = recordCommands(on)
  const drafts: string[] = []
  on('prompt.fill', ($, e) => {
    drafts.push(e.text)
    return { isFilled: true }
  })
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  await ui.press({ key: 'wf-menu' })
  await ui.press({ key: 'wf-cmd-issue' })
  expect(drafts).toEqual(['/wf:issue '])
  expect(ran).toEqual([])
})

test('a chat opened on the project finds the plan in its worktree and offers the next phase', async ($, on) => {
  mock.clock(on)
  on('fs.list', ($, e) => {
    const p = String(e.path ?? '')
    if (p.endsWith('.claude/worktrees')) return { value: [{ name: 'foo', kind: 'dir', size: 0, isLink: false }] }
    if (p.endsWith('.claude/worktrees/foo/.phased/active')) return { value: [{ name: 'foo', kind: 'dir', size: 0, isLink: false }] }
    return { value: [] }
  })
  on('fs.read', () => ({ value: PLAN }))
  on('session.start', () => ({ cwd: '/work' }))
  on('session.turns', () => ({ value: 0 }))
  on('session.messages', () => ({ value: [] }))
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['drawn by Claude Code'] }))
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: 'wf 1/2' })).toBeDefined()
  expect((await ui.find({ key: 'wf-next' }))?.props.label).toBe('▶ Phase 2 · opus / low')
  await ui.press({ key: 'wf-menu' })
  expect((await ui.find({ key: 'wf-cmd-execute-phase' }))?.props.dimColor).toBe(false)
  expect((await ui.find({ key: 'wf-cmd-doctor' }))?.props.dimColor).toBe(false)
})

test('◎ goal, in the worker only: the phase, its Done:, the plan\'s objective and how far the chat took it', async ($, on) => {
  const plan = PLAN.replace('## Work Plan', '## Objective\nFoo, end to end.\n\n## Work Plan')
    .replace('[ ] **Phase 2', '[>] **Phase 2').replace('  - Run: opus / low', '  - Run: opus / low\n  - Done: the grid reloads')
  const edit = { role: 'assistant', text: '', toolUses: [{ id: 'e', tool: 'Edit', input: { file_path: 'foo.py' } }] }
  stubPlan(on, plan, { turns: 9, messages: [TYPED_EXECUTE, edit] })
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: 'Done: the grid reloads' })).toBeUndefined()
  await ui.press({ key: 'wf-goal' })
  expect((await ui.find({ key: 'wf-goal' }))?.props.label).toBe('✕ goal')
  expect(await ui.find({ type: 'Text', text: 'Phase 2 · TH UI for foo' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '■■□□□' })).toBeDefined()
  expect((await ui.find({ type: 'Text', text: ' build ' }))?.props.inverse).toBe(true)
  expect((await ui.find({ type: 'Text', text: 'verify' }))?.props.dimColor).toBe(true)
  expect(await ui.find({ type: 'Text', text: 'Done: the grid reloads' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Plan: Foo, end to end.' })).toBeDefined()
})

test('no ◎ goal in the foreman', async ($, on) => {
  stubPlan(on, PLAN, { turns: 40, messages: [FOREMAN_TITLE] })
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ key: 'wf-goal' })).toBeUndefined()
  await ui.unmount()
})

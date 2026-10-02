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

function stubPlan(on, plan: string | null) {
  mock.clock(on)
  on('fs.list', () => ({ value: plan === null ? [] : [{ name: 'foo', kind: 'dir', size: 0, isLink: false }] }))
  on('fs.read', () => ({ value: plan ?? '' }))
  on('session.start', () => ({ cwd: '/work' }))
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['drawn by Claude Code'] }))
  on('ui.status', () => ({ value: undefined }))
}

function recordCommands(on) {
  const ran: string[] = []
  on('command.run', ($, e) => {
    ran.push(e.command)
    return { value: { text: '' } }
  })
  return ran
}

async function pressNext($) {
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  await ui.press({ key: 'wf-next' })
  await ui.unmount()
}

async function step($, extra = {}) {
  const stream = $.turn.step({ turnId: 't', index: 0, model: 'claude-sonnet-5-5', effort: 'medium', messageCount: 1, ...extra })
  let r = await stream.next()
  while (r.done !== true) r = await stream.next()
  return r.value
}

test('the band offers the next phase; the button clears the chat, then launches execute-phase', async ($, on) => {
  stubPlan(on, PLAN)
  const ran = recordCommands(on)
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect(await ui.find({ type: 'Text', text: 'wf · foo · 1/2' })).toBeDefined()
    const button = await ui.find({ key: 'wf-next' })
    expect(button?.props.label).toBe('▶ execute-phase · Phase 2: TH UI for foo · opus / low')
    await ui.press({ key: 'wf-next' })
    await ui.unmount()
  }
  expect(ran).toEqual(['clear', 'wf:execute-phase', 'clear', 'wf:execute-phase'])
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

test('after the press the worker runs on the phase model and effort; subagents keep theirs', async ($, on) => {
  stubPlan(on, PLAN)
  recordCommands(on)
  const sent: { model: string; effort?: unknown; agentId?: string }[] = []
  on('turn.step', async function* ($, e) {
    sent.push({ model: e.model, effort: e.effort, agentId: e.agentId })
    return { turnId: e.turnId, index: e.index, answer: 'ok', toolUses: [], stopReason: 'end_turn', usage: null }
  })
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  await step($)
  await pressNext($)
  await step($)
  await step($, { agentId: 'verifier' })
  expect(sent).toEqual([
    { model: 'claude-sonnet-5-5', effort: 'medium', agentId: undefined },
    { model: 'opus', effort: 'low', agentId: undefined },
    { model: 'claude-sonnet-5-5', effort: 'medium', agentId: 'verifier' },
  ])
})

test('execute-phase is told the button set model and effort', async ($, on) => {
  stubPlan(on, PLAN)
  recordCommands(on)
  on('skill.prompt', ($, e) => ({ text: e.text }))
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  expect((await $.skill.prompt({ skill: 'wf:execute-phase', text: 'BODY' })).text).toBe('BODY')
  await pressNext($)
  expect((await $.skill.prompt({ skill: 'wf:execute-phase', text: 'BODY' })).text)
    .toBe('BODY\n\nwf-bar: this chat runs Phase 2 on opus / low, set by the button.')
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
  await ui.press({ key: 'wf-menu' })
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

test('the foreman chat finds the plan in its worktree and never offers to build the phase', async ($, on) => {
  mock.clock(on)
  on('fs.list', ($, e) => {
    const p = String(e.path ?? '')
    if (p.endsWith('.claude/worktrees')) return { value: [{ name: 'foo', kind: 'dir', size: 0, isLink: false }] }
    if (p.endsWith('.claude/worktrees/foo/.phased/active')) return { value: [{ name: 'foo', kind: 'dir', size: 0, isLink: false }] }
    return { value: [] }
  })
  on('fs.read', () => ({ value: PLAN }))
  on('session.start', () => ({ cwd: '/work' }))
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['drawn by Claude Code'] }))
  on('ui.status', () => ({ value: undefined }))
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: 'wf · foo · 1/2 · foreman' })).toBeDefined()
  expect(await ui.find({ key: 'wf-next' })).toBeUndefined()
  await ui.press({ key: 'wf-menu' })
  expect((await ui.find({ key: 'wf-cmd-execute-phase' }))?.props.dimColor).toBe(true)
  expect((await ui.find({ key: 'wf-cmd-doctor' }))?.props.dimColor).toBe(false)
})

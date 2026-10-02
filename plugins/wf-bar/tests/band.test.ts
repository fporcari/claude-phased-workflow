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
}

test('the band offers the next phase and the button launches execute-phase', async ($, on) => {
  stubPlan(on, PLAN)
  const ran: string[] = []
  on('command.run', ($, e) => {
    ran.push(e.command)
    return { value: { text: '' } }
  })
  await $.session.start({ surface: 'desktop', isInteractive: true, cwd: '/work' })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect(await ui.find({ type: 'Text', text: 'wf · foo · 1/2' })).toBeDefined()
    const button = await ui.find({ key: 'wf-next' })
    expect(button?.props.label).toBe('▶ execute-phase · Phase 2: TH UI for foo · opus / low')
    await ui.press({ key: 'wf-next' })
    await ui.unmount()
  }
  expect(ran).toEqual(['wf:execute-phase', 'wf:execute-phase'])
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

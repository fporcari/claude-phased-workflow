import { expect, test } from 'claude-code/testing'
import { chatTitle, nextAction, palette, parsePlan, parseRun, phaseRun } from '../hooks/plan.js'

const PLAN = `# Context: wf/foo
Mode: manual

## Work Plan
- [x] **Phase 1**: table foo
  - Run: opus / medium
- [ ] **Phase 2**: TH UI for foo  \`ui\`
  - Run: opus / low
  - Details: view + form
- [ ] **Phase 3**: rename legacyAmount  \`vast\`
  - Run: fable / high
`

test('the first phase not [x] is the one the button launches', () => {
  const a = nextAction(parsePlan(PLAN))
  expect(a.command).toBe('wf:execute-phase')
  expect(a.phase.number).toBe(2)
  expect(a.phase.title).toBe('TH UI for foo')
  expect(a.phase.run).toEqual({ model: 'opus', effort: 'low' })
  expect([a.done, a.total]).toEqual([1, 3])
})

test('a [>] phase is resumed through execute-phase, a [!] one goes to repair', () => {
  expect(nextAction(parsePlan(PLAN.replace('[ ] **Phase 2', '[>] **Phase 2'))).command).toBe('wf:execute-phase')
  expect(nextAction(parsePlan(PLAN.replace('[ ] **Phase 2', '[!] **Phase 2'))).command).toBe('wf:repair-phase')
  expect(nextAction(parsePlan(PLAN.replace('[ ] **Phase 2', '[~] **Phase 2'))).command).toBe(null)
})

test('every phase [x] offers the quality check; an autonomous plan offers nothing', () => {
  expect(nextAction(parsePlan(PLAN.replaceAll('- [ ]', '- [x]'))).command).toBe('wf:quality-check')
  expect(nextAction(parsePlan(PLAN.replace('Mode: manual', 'Mode: autonomous'))).command).toBe(null)
})

test('a Run: line splits into model and effort, its comment dropped; none reads as opus / high', () => {
  expect(parseRun('fable / high — meant for /execute-phase-agent')).toEqual({ model: 'fable', effort: 'high' })
  expect(parseRun('whatever the session has')).toBe(null)
  expect(phaseRun({ run: null })).toEqual({ model: 'opus', effort: 'high' })
})

test('the palette follows the chat: the worker builds, the foreman never does, a chat with no role sees all', () => {
  const names = (role) => palette(role).flatMap(([, n]) => n)
  expect(names('worker')).toEqual(['execute-phase', 'close-phase', 'repair-phase', 'resume-workflow', 'dashboard', 'help'])
  expect(names('foreman')).not.toContain('execute-phase')
  expect(names('foreman')).not.toContain('close-phase')
  expect(names('foreman')).toContain('quality-check')
  expect(names('fresh').length).toBe(14)
})

test('a chat title reads in both shapes: role first since 6.49.0, the wf: prefix before', () => {
  expect(chatTitle('Foreman · Convegno menu')).toEqual({ key: 'Convegno menu', role: 'foreman' })
  expect(chatTitle('Worker P10 · Convegno menu')).toEqual({ key: 'Convegno menu', role: 'worker' })
  expect(chatTitle('Deposed · Convegno menu')).toEqual({ key: 'Convegno menu', role: 'deposed' })
  expect(chatTitle('wf:454-convegno:foreman')).toEqual({ key: '454-convegno', role: 'foreman' })
  expect(chatTitle('wf:454-convegno:phase-10 — Programma')).toEqual({ key: '454-convegno', role: 'worker' })
  expect(chatTitle('Fix the login page')).toBe(null)
  expect(parsePlan('Mode: manual\nTheme: Convegno menu\n').theme).toBe('Convegno menu')
})

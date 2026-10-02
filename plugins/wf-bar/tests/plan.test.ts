import { expect, test } from 'claude-code/testing'
import { nextAction, parsePlan } from '../hooks/plan.js'

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
  expect(a.phase.run).toBe('opus / low')
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

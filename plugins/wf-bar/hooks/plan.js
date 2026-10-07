const PHASE_RE = /^\s*-\s*\[(.)\]\s*\*\*Phase\s+(\d+)\*\*:\s*(.+?)\s*$/
const RUN_RE = /^\s*[-*]?\s*Run:\s*(.+?)\s*$/i
const MODE_RE = /^Mode:\s*(\S+)/m
const THEME_RE = /^Theme:\s*(.+?)\s*$/m
const TAG_RE = /\s+`[a-z-]+`(\s+`[a-z-]+`)*$/
const HEADING_RE = /^##\s+(.+?)\s*$/
const FIELD_RE = /^\s+[-*]\s*([A-Z][A-Za-z ]*?):\s*(.+?)\s*$/
const NOTE_RE = /^\s*>\s*([A-Z][A-Za-z-]*):/
const RUN_VALUE_RE = /^([a-z][a-z0-9.-]*)\s*\/\s*(low|medium|high|xhigh|max)\b/i
// execute-phase reads a phase with no Run: line as opus / high.
const DEFAULT_RUN = { model: 'opus', effort: 'high' }

export function parseRun(value) {
  const m = value.match(RUN_VALUE_RE)
  return m ? { model: m[1].toLowerCase(), effort: m[2].toLowerCase() } : null
}

export function phaseRun(phase) {
  return phase.run || DEFAULT_RUN
}

export function parsePlan(text) {
  const mode = (text.match(MODE_RE) || [, 'manual'])[1].toLowerCase()
  const theme = (text.match(THEME_RE) || [])[1] || null
  const phases = []
  const objective = []
  let section = null
  let current = null
  for (const line of text.split('\n')) {
    const h = line.match(HEADING_RE)
    if (h) {
      section = h[1]
      current = null
      continue
    }
    const p = line.match(PHASE_RE)
    if (p) {
      current = { marker: p[1], number: Number(p[2]), title: p[3].replace(TAG_RE, ''), run: null, fields: {}, notes: [] }
      phases.push(current)
      continue
    }
    const r = line.match(RUN_RE)
    if (r && phases.length && !phases[phases.length - 1].run) phases[phases.length - 1].run = parseRun(r[1])
    if (section === 'Objective' && line.trim()) objective.push(line.trim())
    if (!current) continue
    const f = line.match(FIELD_RE)
    if (f && !(f[1] in current.fields)) current.fields[f[1]] = f[2]
    const n = line.match(NOTE_RE)
    if (n) current.notes.push(n[1])
  }
  return { mode, theme, objective: objective.join(' ') || null, phases }
}

// The first phase not [x] is the only one that can run: phases run strictly in order.
export function nextAction(plan) {
  const done = plan.phases.filter((p) => p.marker === 'x').length
  const total = plan.phases.length
  const head = plan.phases.find((p) => p.marker !== 'x')
  const base = { done, total, phase: head || null }
  if (plan.mode === 'autonomous') return { ...base, command: null }
  if (!head) return { ...base, command: total ? 'wf:quality-check' : null }
  if (head.marker === ' ' || head.marker === '>') return { ...base, command: 'wf:execute-phase' }
  if (head.marker === '!') return { ...base, command: 'wf:repair-phase' }
  return { ...base, command: null }
}

export const EXECUTE = 'wf:execute-phase'
export const TYPED_EXECUTE = /(^|<command-name>)\/wf:execute-phase\b/
export const STAGES = ['gate', 'build', 'verify', 'test', 'close']
const EDITS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit'])
const VERIFIERS = new Set(['wf:phase-verifier', 'wf:ui-judge'])

// How far the chat took its phase since its last execute-phase, as an index into STAGES; -1 before one.
// The gate writes under .phased/ (mockups, notes): only an edit elsewhere is the build.
export function chatStage(rows) {
  let at = -1
  for (const m of rows) {
    if (m.role === 'user' && TYPED_EXECUTE.test(m.text)) at = 0
    for (const u of m.toolUses) {
      const skill = u.tool === 'Skill' ? u.input.skill : null
      if (skill === EXECUTE) at = 0
      else if (at < 0) continue
      else if (skill === 'wf:close-phase') at = 4
      else if (VERIFIERS.has(u.input.subagent_type) || skill === 'ui-test') at = Math.max(at, 2)
      else if (EDITS.has(u.tool) && !String(u.input.file_path ?? u.input.notebook_path ?? '').includes('.phased/')) at = Math.max(at, 1)
    }
  }
  return at
}

// The plan bounds what the chat says: a phase not yet marked [>] is at most at its gate,
// one awaiting the human's checks is at least in test.
export function phaseStage(phase, seen) {
  if (!phase) return -1
  if (phase.marker === ' ') return Math.min(seen, 0)
  if (phase.marker !== '>') return -1
  return Math.max(seen, phase.notes.includes('Testing') ? 3 : 0)
}

// A workflow chat's title: `Foreman · <theme>`, `Worker P<N> · <theme>` since 6.49.0,
// `wf:<slug>:foreman` and `wf:<slug>:phase-N` before. Null for any other chat.
const TITLE_RE = /^(Foreman|Deposed|Worker P(\d+)) · (.+)$/
const LEGACY_TITLE_RE = /^wf:([^:]+):(foreman|phase|repair)/

export function chatTitle(title) {
  const m = title.match(TITLE_RE)
  if (m) return { key: m[3].trim(), role: m[2] ? 'worker' : m[1].toLowerCase() }
  const l = title.match(LEGACY_TITLE_RE)
  if (l) return { key: l[1], role: l[2] === 'foreman' ? 'foreman' : 'worker' }
  return null
}

export const GROUPS = [
  ['Phase', ['execute-phase', 'close-phase', 'repair-phase']],
  ['Plan', ['resume-workflow', 'run-workflow', 'quality-check', 'finalize-workflow', 'doctor']],
  ['Other', ['dashboard', 'write-workflow', 'import-workflow', 'issue', 'pull-request', 'help']],
]

// The worker builds the phases and nothing else; the foreman supervises and never builds.
// A chat with no role yet is offered everything.
const WORKER = new Set(['execute-phase', 'close-phase', 'repair-phase', 'resume-workflow', 'dashboard', 'help'])
const FOREMAN_NEVER = new Set(['execute-phase', 'close-phase', 'repair-phase'])

export function allowed(name, role) {
  if (role === 'worker') return WORKER.has(name)
  if (role === 'foreman') return !FOREMAN_NEVER.has(name)
  return true
}

export function palette(role) {
  return GROUPS.map(([group, names]) => [group, names.filter((n) => allowed(n, role))]).filter(([, names]) => names.length)
}

// Skills whose argument is required: the button drafts the command, the user completes it.
export const NEEDS_ARGS = new Set(['issue'])

export function relevant(plan, action) {
  const on = new Set(['resume-workflow', 'dashboard', 'help'])
  if (!plan) {
    for (const c of ['write-workflow', 'import-workflow', 'issue']) on.add(c)
    return on
  }
  const head = action.phase
  if (plan.mode === 'autonomous') {
    on.add(head ? 'run-workflow' : 'quality-check')
    if (!head) on.add('finalize-workflow')
    return on
  }
  if (!head) {
    for (const c of ['quality-check', 'finalize-workflow', 'pull-request']) on.add(c)
    return on
  }
  if (head.marker === '!') on.add('repair-phase')
  if (head.marker === ' ' || head.marker === '>') on.add('execute-phase')
  if (head.marker === '>') on.add('close-phase')
  on.add('doctor')
  return on
}

const PHASE_RE = /^\s*-\s*\[(.)\]\s*\*\*Phase\s+(\d+)\*\*:\s*(.+?)\s*$/
const RUN_RE = /^\s*[-*]?\s*Run:\s*(.+?)\s*$/i
const MODE_RE = /^Mode:\s*(\S+)/m
const TAG_RE = /\s+`[a-z-]+`(\s+`[a-z-]+`)*$/
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
  const phases = []
  for (const line of text.split('\n')) {
    const p = line.match(PHASE_RE)
    if (p) {
      phases.push({ marker: p[1], number: Number(p[2]), title: p[3].replace(TAG_RE, ''), run: null })
      continue
    }
    const r = line.match(RUN_RE)
    if (r && phases.length && !phases[phases.length - 1].run) phases[phases.length - 1].run = parseRun(r[1])
  }
  return { mode, phases }
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

import { GROUPS, NEEDS_ARGS, nextAction, parsePlan, phaseRun, relevant } from './plan.js'

const ACTIVE = '.phased/active'
const WORKTREES = '.claude/worktrees'
const REFRESH_MS = 15_000
const EXECUTE = 'wf:execute-phase'

let state = null
let open = false
// The phase this worker chat was started on: its model and effort hold on every
// main-loop request until the next press. Module-level, so it survives /clear.
let pin = null

async function dirs($, path) {
  return (await $.fs.list(path).catch(() => [])).filter((d) => d.kind === 'dir').map((d) => d.name)
}

// The worker sits in the plan's checkout; the foreman in the checkout the worktree hangs from.
async function locate($) {
  const here = await dirs($, ACTIVE)
  if (here.length === 1) return { role: 'worker', dir: `${ACTIVE}/${here[0]}`, slug: here[0] }
  if (here.length > 1) return null
  const found = []
  for (const w of await dirs($, WORKTREES)) {
    for (const slug of await dirs($, `${WORKTREES}/${w}/${ACTIVE}`)) found.push({ role: 'foreman', dir: `${WORKTREES}/${w}/${ACTIVE}/${slug}`, slug })
  }
  return found.length === 1 ? found[0] : null
}

async function readState($) {
  const where = await locate($)
  if (!where) return null
  const text = await $.fs.read(`${where.dir}/plan.md`).catch(() => null)
  if (text === null) return null
  const plan = parsePlan(text)
  const action = nextAction(plan)
  const primary = where.role === 'worker' ? action.command : plan.mode === 'autonomous' && action.phase ? 'wf:run-workflow' : null
  return { role: where.role, slug: where.slug, ...action, command: primary, on: [...relevant(plan, action, where.role)] }
}

async function refresh($) {
  const fresh = await readState($)
  if (JSON.stringify(fresh) === JSON.stringify(state)) return
  state = fresh
  $.ui.invalidate('ui.render')
}

function label(s) {
  if (s.command !== EXECUTE) return `▶ ${s.command.slice(3)}`
  const run = phaseRun(s.phase)
  return `▶ execute-phase · Phase ${s.phase.number}: ${s.phase.title} · ${run.model} / ${run.effort}`
}

async function launch($, s, command) {
  if (NEEDS_ARGS.has(command.slice(3))) {
    await $.prompt.fill({ text: `/${command} ` })
    return
  }
  pin = command === EXECUTE && s.phase ? { phase: s.phase.number, ...phaseRun(s.phase) } : null
  $.ui.status(pin ? `worker on ${pin.model} / ${pin.effort} — Phase ${pin.phase}` : '')
  if (pin) await $.command.run({ command: 'clear', args: '' })
  await $.command.run({ command, args: '' })
}

export function register(on) {
  on('session.start', async ($, e, next) => {
    await refresh($)
    $.clock.every(REFRESH_MS, () => refresh($))
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (!pin || e.agentId) return yield* next(e)
    return yield* next({ ...e, model: pin.model, effort: pin.effort })
  })

  on('skill.prompt', { skill: EXECUTE }, async ($, e, next) => {
    if (!pin) return next(e)
    const r = await next(e)
    return { text: `${r.text}\n\nwf-bar: this chat runs Phase ${pin.phase} on ${pin.model} / ${pin.effort}, set by the button.` }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (!state || e.props.hasSurvey) return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const s = state
    const idle = !e.props.isWorking
    const head = [Text({ dimColor: true, children: [`wf · ${s.slug} · ${s.done}/${s.total}${s.role === 'foreman' ? ' · foreman' : ''}`] })]
    if (s.command && idle) head.push(Button({ key: 'wf-next', label: label(s), onPress: () => launch($, s, s.command) }))
    head.push(Button({ key: 'wf-menu', label: open ? '✕ wf' : '☰ wf', onPress: () => { open = !open; $.ui.invalidate('ui.render') } }))
    const rows = [Box({ flexDirection: 'row', columnGap: 2, children: head })]
    if (open) {
      for (const [group, names] of GROUPS) {
        rows.push(Box({
          flexDirection: 'row',
          columnGap: 1,
          children: [
            Text({ dimColor: true, children: [group.padEnd(6)] }),
            ...names.map((name) => Button({
              key: `wf-cmd-${name}`,
              label: name,
              dimColor: !s.on.includes(name),
              onPress: () => { if (idle) launch($, s, `wf:${name}`) },
            })),
          ],
        }))
      }
    }
    const theirs = await next(e)
    return Box({ flexDirection: 'column', children: [...rows, theirs] })
  })
}

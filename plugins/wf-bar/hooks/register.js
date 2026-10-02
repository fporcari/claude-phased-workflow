import { nextAction, parsePlan, phaseRun } from './plan.js'

const ACTIVE = '.phased/active'
const REFRESH_MS = 15_000
const EXECUTE = 'wf:execute-phase'

let state = null
// The phase this worker chat was started on: its model and effort hold on every
// main-loop request until the next press. Module-level, so it survives /clear.
let pin = null

async function readState($) {
  const dirs = (await $.fs.list(ACTIVE).catch(() => [])).filter((d) => d.kind === 'dir')
  if (dirs.length !== 1) return null
  const slug = dirs[0].name
  const text = await $.fs.read(`${ACTIVE}/${slug}/plan.md`).catch(() => null)
  if (text === null) return null
  return { slug, ...nextAction(parsePlan(text)) }
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

async function press($, s) {
  pin = s.command === EXECUTE ? { phase: s.phase.number, ...phaseRun(s.phase) } : null
  $.ui.status(pin ? `worker on ${pin.model} / ${pin.effort} — Phase ${pin.phase}` : '')
  if (s.command === EXECUTE) await $.command.run({ command: 'clear', args: '' })
  await $.command.run({ command: s.command, args: '' })
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
    const children = [Text({ dimColor: true, children: [`wf · ${state.slug} · ${state.done}/${state.total}`] })]
    if (state.command && !e.props.isWorking) {
      const s = state
      children.push(Button({ key: 'wf-next', label: label(s), onPress: () => press($, s) }))
    }
    const theirs = await next(e)
    return Box({ flexDirection: 'column', children: [Box({ flexDirection: 'row', columnGap: 2, children }), theirs] })
  })
}

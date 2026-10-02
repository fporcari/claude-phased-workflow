import { nextAction, parsePlan } from './plan.js'

const ACTIVE = '.phased/active'
const REFRESH_MS = 15_000

let state = null

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
  if (s.command === 'wf:quality-check') return '▶ quality-check'
  const run = s.phase.run ? ` · ${s.phase.run}` : ''
  return `▶ ${s.command.slice(3)} · Phase ${s.phase.number}: ${s.phase.title}${run}`
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

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (!state || e.props.hasSurvey) return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const children = [Text({ dimColor: true, children: [`wf · ${state.slug} · ${state.done}/${state.total}`] })]
    if (state.command && !e.props.isWorking) {
      const command = state.command
      children.push(Button({
        key: 'wf-next',
        label: label(state),
        onPress: () => $.command.run({ command, args: '' }),
      }))
    }
    const theirs = await next(e)
    return Box({ flexDirection: 'column', children: [Box({ flexDirection: 'row', columnGap: 2, children }), theirs] })
  })
}

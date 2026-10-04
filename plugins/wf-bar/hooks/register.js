import { NEEDS_ARGS, allowed, nextAction, palette, parsePlan, phaseRun, relevant } from './plan.js'

const ACTIVE = '.phased/active'
const WORKTREES = '.claude/worktrees'
const REFRESH_MS = 15_000
const EXECUTE = 'wf:execute-phase'
const TYPED_EXECUTE = /(^|<command-name>)\/wf:execute-phase\b/

let state = null
let role = 'unknown'
let open = false
// An unknown chat may hold work of its own: the first press asks, the second clears.
let armed = false
// execute-phase ran here, typed or pressed. Module-level, so it survives /clear.
let built = false

async function dirs($, path) {
  return (await $.fs.list(path).catch(() => [])).filter((d) => d.kind === 'dir').map((d) => d.name)
}

// The plan's own checkout first, then the worktrees below a project chat.
async function locate($) {
  const here = await dirs($, ACTIVE)
  if (here.length === 1) return { dir: `${ACTIVE}/${here[0]}`, slug: here[0] }
  if (here.length > 1) return null
  const found = []
  for (const w of await dirs($, WORKTREES)) {
    for (const slug of await dirs($, `${WORKTREES}/${w}/${ACTIVE}`)) found.push({ dir: `${WORKTREES}/${w}/${ACTIVE}/${slug}`, slug })
  }
  return found.length === 1 ? found[0] : null
}

// Both chats sit in the same checkout, so the role is read from what the chat did:
// the foreman titled itself wf:<slug>:foreman, the worker ran execute-phase.
async function chatRole($, slug) {
  let worker = built
  const rows = await $.session.messages()
  for (const m of Array.isArray(rows) ? rows : []) {
    for (const u of m.toolUses) {
      const title = u.tool.endsWith('set_session_title') ? String(u.input.title ?? '') : ''
      if (title === `wf:${slug}:foreman`) return 'foreman'
      if (title.startsWith(`wf:${slug}:phase-`) || (u.tool === 'Skill' && u.input.skill === EXECUTE)) worker = true
    }
    if (m.role === 'user' && TYPED_EXECUTE.test(m.text)) worker = true
  }
  if (worker) return 'worker'
  return (await $.session.turns()) === 0 ? 'fresh' : 'unknown'
}

async function readState($) {
  const where = await locate($)
  if (!where) return null
  const text = await $.fs.read(`${where.dir}/plan.md`).catch(() => null)
  if (text === null) return null
  const plan = parsePlan(text)
  const action = nextAction(plan)
  const primary = plan.mode === 'autonomous' ? (action.phase ? 'wf:run-workflow' : action.command) : action.command
  return { slug: where.slug, ...action, command: primary, on: [...relevant(plan, action)] }
}

async function refresh($, rereadRole) {
  const fresh = await readState($)
  const r = fresh && rereadRole ? await chatRole($, fresh.slug).catch(() => 'unknown') : role
  if (r === role && JSON.stringify(fresh) === JSON.stringify(state)) return
  state = fresh
  role = r
  armed = false
  $.ui.invalidate('ui.render')
}

function label(s) {
  if (s.command !== EXECUTE || !s.phase) return `▶ ${s.command.slice(3)}`
  const run = phaseRun(s.phase)
  return `▶ Phase ${s.phase.number} · ${run.model} / ${run.effort}`
}

// Whose step it is when this chat may not take it.
function elsewhere(s) {
  if (!s.command || allowed(s.command.slice(3), role)) return null
  return allowed(s.command.slice(3), 'worker') ? `worker, in a new chat: ${label(s).slice(2)}` : `foreman: ${s.command.slice(3)}`
}

async function launch($, s, command) {
  const name = command.slice(3)
  open = false
  $.ui.invalidate('ui.render')
  if (!allowed(name, role)) return
  if (NEEDS_ARGS.has(name)) {
    await $.prompt.fill({ text: `/${command} ` })
    return
  }
  if (command !== EXECUTE || !s.phase) {
    await $.command.run({ command, args: '' })
    return
  }
  if (role === 'unknown' && !armed) {
    armed = true
    $.ui.invalidate('ui.render')
    return
  }
  armed = false
  const run = phaseRun(s.phase)
  if ((await $.session.turns()) > 0) await $.command.run({ command: 'clear', args: '' })
  await $.command.run({ command: 'model', args: run.model })
  await $.command.run({ command: 'effort', args: run.effort })
  await $.command.run({ command, args: '' })
}

export function register(on) {
  on('session.start', async ($, e, next) => {
    await refresh($, true)
    $.clock.every(REFRESH_MS, () => refresh($, false))
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    if (!e.agentId) await refresh($, true)
    return next(e)
  })

  on('skill.prompt', { skill: EXECUTE }, async ($, e, next) => {
    built = true
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (!state || e.props.hasSurvey) return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const s = state
    const idle = !e.props.isWorking
    const tag = role === 'foreman' || role === 'worker' ? ` · ${role}` : ''
    const head = [Text({ dimColor: true, children: [`wf ${s.done}/${s.total}${tag}`] })]
    if (idle && armed && s.phase) {
      head.push(Button({ key: 'wf-next', label: `▶ clear this chat for Phase ${s.phase.number}? press again`, onPress: () => launch($, s, EXECUTE) }))
    } else if (idle && s.command && !elsewhere(s)) {
      head.push(Button({ key: 'wf-next', label: label(s), onPress: () => launch($, s, s.command) }))
    }
    const about = [elsewhere(s), s.phase?.title, s.slug].filter(Boolean).join(' · ')
    head.push(Box({ flexGrow: 1, flexShrink: 1, minWidth: 0, children: [Text({ dimColor: true, wrap: 'truncate-end', children: [about] })] }))
    head.push(Button({ key: 'wf-menu', label: open ? '✕ wf' : '☰ wf', onPress: () => { open = !open; $.ui.invalidate('ui.render') } }))
    const rows = [Box({ flexDirection: 'row', columnGap: 2, children: head })]
    if (open) {
      for (const [group, names] of palette(role)) {
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

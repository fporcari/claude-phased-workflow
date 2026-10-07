import { EXECUTE, NEEDS_ARGS, STAGES, TYPED_EXECUTE, allowed, chatStage, chatTitle, nextAction, palette, parsePlan, phaseRun, phaseStage, relevant } from './plan.js'

const ACTIVE = '.phased/active'
const WORKTREES = '.claude/worktrees'
const REFRESH_MS = 15_000

let state = null
let role = 'unknown'
let seen = -1
let open = false
let goal = false
// An unknown chat may hold work of its own: the first press asks, the second clears.
let armed = false
// execute-phase ran here, typed or pressed. Module-level, so it survives /clear.
let built = false
// The phase's model and effort the button set, held against every main-loop request.
let pin = null

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
// the foreman titled itself for this plan's foreman, the worker ran execute-phase.
async function chatRole($, s, rows) {
  let worker = built
  for (const m of rows) {
    for (const u of m.toolUses) {
      const t = u.tool.endsWith('set_session_title') ? chatTitle(String(u.input.title ?? '')) : null
      const ours = t && (t.key === s.slug || t.key === s.theme)
      if (ours && t.role === 'foreman') return 'foreman'
      if ((ours && t.role === 'worker') || (u.tool === 'Skill' && u.input.skill === EXECUTE)) worker = true
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
  return { slug: where.slug, theme: plan.theme || where.slug, objective: plan.objective, ...action, command: primary, on: [...relevant(plan, action)] }
}

async function messages($) {
  const rows = await $.session.messages().catch(() => [])
  return Array.isArray(rows) ? rows : []
}

async function refresh($, rereadChat) {
  const fresh = await readState($)
  const rows = fresh && rereadChat ? await messages($) : null
  const r = rows ? await chatRole($, fresh, rows).catch(() => 'unknown') : role
  const at = rows ? chatStage(rows) : seen
  if (r === role && at === seen && JSON.stringify(fresh) === JSON.stringify(state)) return
  state = fresh
  role = r
  seen = at
  armed = false
  $.ui.invalidate('ui.render')
}

function label(s) {
  if (s.command !== EXECUTE || !s.phase) return `▶ ${s.command.slice(3)}`
  const run = phaseRun(s.phase)
  return `▶ Phase ${s.phase.number} · ${run.model} / ${run.effort}`
}

// Foreman and worker sit in the same checkout and look alike: the role is drawn, not hinted.
const LOOK = {
  foreman: { color: 'magenta', tag: () => ' FOREMAN ', note: 'supervises — the worker builds in another chat' },
  worker: { color: 'cyan', tag: (s) => ` WORKER${s.phase ? ` · Phase ${s.phase.number}` : ''} ` },
}

// Whose step it is when this chat may not take it.
function elsewhere(s) {
  if (!s.command || allowed(s.command.slice(3), role)) return null
  return allowed(s.command.slice(3), 'worker') ? `worker, in a new chat: ${label(s).slice(2)}` : `foreman: ${s.command.slice(3)}`
}

// The phase's target and how far this chat took it.
function goalRows({ Box, Text }, s) {
  const at = phaseStage(s.phase, seen)
  const steps = STAGES.map((name, i) => Text({
    bold: i === at,
    inverse: i === at,
    color: i <= at ? 'cyan' : undefined,
    dimColor: i > at,
    children: [i === at ? ` ${name} ` : name],
  }))
  const rows = [
    Text({ bold: true, children: [`Phase ${s.phase.number} · ${s.phase.title}`] }),
    Box({ flexDirection: 'row', columnGap: 1, children: [Text({ children: ['■'.repeat(at + 1) + '□'.repeat(STAGES.length - at - 1)] }), ...steps] }),
  ]
  if (s.phase.fields.Done) rows.push(Text({ children: [`Done: ${s.phase.fields.Done}`] }))
  if (s.objective) rows.push(Text({ dimColor: true, children: [`Plan: ${s.objective}`] }))
  return rows
}

async function launch($, s, command) {
  const name = command.slice(3)
  open = false
  role = await chatRole($, s, await messages($)).catch(() => 'unknown')
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
  pin = { phase: s.phase.number, ...run }
  $.ui.status(undefined)
  // The arguments reach the model whatever the hooks do: execute-phase reads them.
  await $.command.run({ command, args: `wf-bar ${run.model} / ${run.effort}` })
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

  // The desktop's own picker does not follow /effort: what each request carries is the truth.
  on('turn.step', async function* ($, e, next) {
    if (pin && !e.agentId) {
      const off = String(e.effort) !== pin.effort || !e.model.toLowerCase().includes(pin.model)
      $.ui.status(off ? `⚠ running ${e.model} / ${e.effort} — Phase ${pin.phase} wants ${pin.model} / ${pin.effort}` : undefined)
    }
    return yield* next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (!state || e.props.hasSurvey) return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const s = state
    const idle = !e.props.isWorking
    const look = LOOK[role]
    const head = [Text({ dimColor: true, children: [`wf ${s.done}/${s.total}`] })]
    if (look) head.unshift(Text({ bold: true, inverse: true, color: look.color, children: [look.tag(s)] }))
    if (idle && armed && s.phase) {
      head.push(Button({ key: 'wf-next', label: `▶ clear this chat for Phase ${s.phase.number}? press again`, onPress: () => launch($, s, EXECUTE) }))
    } else if (idle && s.command && !elsewhere(s)) {
      head.push(Button({ key: 'wf-next', label: label(s), onPress: () => launch($, s, s.command) }))
    }
    const about = [elsewhere(s) ?? look?.note, s.phase?.title, s.theme].filter(Boolean).join(' · ')
    head.push(Box({ flexGrow: 1, flexShrink: 1, minWidth: 0, children: [Text({ dimColor: true, wrap: 'truncate-end', children: [about] })] }))
    if (role === 'worker' && s.phase) {
      head.push(Button({ key: 'wf-goal', label: goal ? '✕ goal' : '◎ goal', onPress: () => { goal = !goal; $.ui.invalidate('ui.render') } }))
    }
    head.push(Button({ key: 'wf-menu', label: open ? '✕ wf' : '☰ wf', onPress: () => { open = !open; $.ui.invalidate('ui.render') } }))
    const rows = [Box({ flexDirection: 'row', columnGap: 2, children: head })]
    if (goal && role === 'worker' && s.phase) rows.push(...goalRows($.ui.resolve(e), s))
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
    const band = look
      ? Box({ flexDirection: 'column', borderStyle: 'round', borderColor: look.color, paddingX: 1, children: rows })
      : Box({ flexDirection: 'column', children: rows })
    return Box({ flexDirection: 'column', children: [band, theirs] })
  })
}

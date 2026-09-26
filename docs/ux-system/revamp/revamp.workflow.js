export const meta = {
  name: 'app-revamp-wave',
  description: 'Run one revamp wave: build each unit in its own worktree, review it adversarially, fix, then integrate all branches serially',
  whenToUse: 'Owner-approved app revamp (docs/ux-system/revamp/PLAN.md). Pass args {wave, base, units} from work-units.json.',
  phases: [
    { title: 'Scope', detail: 'wave 3 only: each slice names its write set; slices are packed into conflict-free batches' },
    { title: 'Build', detail: 'one agent per unit, own git worktree and branch revamp/<unit id>' },
    { title: 'Review', detail: 'read-only adversarial review against the unit, the kit rules and the visual language' },
    { title: 'Fix', detail: 'the builder fixes what the review found, in the same worktree' },
    { title: 'Integrate', detail: 'one integrator merges every passing branch in order and runs the checks' },
  ],
}

// args: { wave: '1' | '2a' | '2b' | '2c' | '3', units: [...] }
// Builders branch from the integration branch itself, so every batch starts
// from what the previous integration merged.
const WAVE = args.wave
const BASE = args.base || 'feat/phone-setup-v2'
const UNITS = args.units

const RULES = `
Repository: /home/eslam/Storage/Code/oc_app (Flutter, Android first). Obey AGENTS.md.
Specs to read before editing: docs/design/visual-language-2026-09-26.md (look, §6 glass, §7 crisp),
docs/ux-system/kit-v2.md (parts, §4 rules, §8 adaptive, §9 kit only), docs/design/design-standard.md,
docs/ux-system/target-ia.md (where every job lands), docs/ux-system/map/all.json (your pages' records:
proposal, actionsMissing, statesMissing, whenMissing, couldBeAutomatic), docs/ux-system/owner-verdicts-2026-09-26.json.
Hard rules:
- Kit only: outside lib/ui/kit/ construct only the layout/scroll/builder/semantics allowlist (kit-v2.md §9.1).
  A missing part is added to the kit (lib/ui/kit/) in your own new file; test/kit_ratchet_test.dart counts may only go down.
- Colours come from theme roles only; type from KitText roles; sizes are integers; hairlines 1 physical px.
- Copy: lib/l10n/app_en.arb AND app_ar.arb (real Arabic); run gen-l10n once at the end.
- Pinned Flutter: F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter.
  Format changed files with "dart format --language-version=3.10". Run ONLY affected test files with "$F test -j 1 <files>"
  (six agents share one 15 GB machine). Regenerate a golden only after looking at the new image.
- Never: APK builds, Gradle, emulators, adb, pushes, the phone, editing files outside your write set except a new kit
  part file and your tests/goldens/QA record. main.dart and lib/state/connection.dart need the coordinator.
- Commit on your branch with messages ending "[skip ci]" and the two trailer lines:
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01G7Gr8TYUhyCJ169CtNjJB1
- Write docs/qa/revamp-<unit id>/README.md: what changed, before/after golden paths, commands and results, gaps.`

const BUILD_SCHEMA = {
  type: 'object',
  properties: {
    branch: { type: 'string' },
    worktree: { type: 'string' },
    commits: { type: 'array', items: { type: 'string' } },
    filesChanged: { type: 'array', items: { type: 'string' } },
    testsRun: { type: 'array', items: { type: 'string' } },
    testsPassed: { type: 'boolean' },
    analyzeClean: { type: 'boolean' },
    ratchetBefore: { type: 'number' },
    ratchetAfter: { type: 'number' },
    newKitParts: { type: 'array', items: { type: 'string' } },
    gaps: { type: 'array', items: { type: 'string' } },
  },
  required: ['branch', 'worktree', 'commits', 'testsPassed', 'analyzeClean', 'gaps'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['pass', 'fix', 'reject'] },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: { file: { type: 'string' }, line: { type: 'number' }, problem: { type: 'string' }, fix: { type: 'string' } },
        required: ['problem', 'fix'],
      },
    },
  },
  required: ['verdict', 'issues'],
}

const SCOPE_SCHEMA = {
  type: 'object',
  properties: {
    feasible: { type: 'boolean' },
    blocker: { type: 'string' },
    write: { type: 'array', items: { type: 'string' } },
  },
  required: ['feasible', 'write'],
}

function describe(u) {
  const lines = [
    `Unit ${u.id} (wave ${u.wave}): ${u.title}.`,
    u.write.length ? `Write set (only these files, plus a new kit part and your tests): ${u.write.join(', ')}.` : '',
    u.pages && u.pages.length ? `Pages (map records to honour): ${u.pages.join(', ')}.` : '',
    u.finishLine ? `Finish line: ${u.finishLine}` : '',
    u.nonGoal ? `Not in this unit: ${u.nonGoal}` : '',
    u.acceptance && u.acceptance.length ? `Acceptance: ${u.acceptance.join(' | ')}` : '',
  ]
  if (u.kind === 'kit-part') {
    lines.push('Build the part to its kit-v2.md section: API, states, motion, haptics, a11y, RTL, data safety, adaptive §8.2, ' +
      'galleries at the §8.4 sizes (DPR 3), behaviour tests. Export it from lib/ui/kit/kit.dart. Do not migrate screens.')
  } else if (u.kind === 'kit-change') {
    lines.push('Change the existing part as kit-v2.md §2 says, keeping every current caller compiling; update its gallery and tests.')
  } else if (u.kind === 'screen-revamp') {
    lines.push('Revamp every file in the write set: rebuild it from kit parts only (G16 for these files goes to zero), ' +
      'apply the visual language, and fix what the map records ask for these pages (proposal "fix", actionsMissing, ' +
      'statesMissing, whenMissing → explains/offers-enable). Pages whose proposal is remove or merge are wave 3: leave their ' +
      'behaviour, only restyle. Regenerate the goldens of these screens and look at them.')
  } else if (u.kind === 'programme-slice') {
    lines.push('Implement the slice end to end (controller → UI → persistence/deletion), with tests that fail without it. ' +
      'Its proof field is for the coordinator: describe the exact emulator steps in the QA record.')
  }
  return lines.filter(Boolean).join('\n')
}

async function buildReviewFix(u) {
  const deps = (u.after || []).filter((d) => !d.startsWith('programme-'))
  const built = await agent(
    `${describe(u)}\n\nStart: you are in a fresh git worktree. Run "git switch -c revamp/${u.id} ${BASE}"` +
      (deps.length ? `, then merge the branches of the units you build on: ${deps.map((d) => 'revamp/' + d).join(', ')}` : '') +
      `. Then "$F pub get". Work, check, commit.\n${RULES}\nReturn the build record; worktree = your absolute working directory.`,
    { label: `build ${u.id}`, phase: 'Build', schema: BUILD_SCHEMA, isolation: 'worktree', model: u.model === 'sonnet' ? 'sonnet' : undefined },
  )
  if (!built) return null
  const review = await agent(
    `Adversarially review branch revamp/${u.id} in ${built.worktree} against ${BASE} ("git diff ${BASE}...HEAD").\n${describe(u)}\n` +
      'Try to find what is wrong: raw framework widgets outside the kit, colours or type not from tokens, soft or half-pixel edges, ' +
      'missing states, broken RTL or 200 % text, copy that uses engine words, lost typed input, map records ignored, tests that ' +
      'assert implementation instead of behaviour, goldens regenerated without matching the approved renders ' +
      '(docs/design/visual-language-2026-09-26/*.png). Read-only: never run tests or builds, never edit. ' +
      'verdict "pass" only if nothing material is wrong.',
    { label: `review ${u.id}`, phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high' },
  )
  if (!review || review.verdict === 'pass') return { unit: u.id, built, review }
  const fixed = await agent(
    `Fix these review findings on branch revamp/${u.id}, working in ${built.worktree} (do not create another worktree):\n` +
      review.issues.map((i, n) => `${n + 1}. ${i.file || ''}:${i.line || ''} ${i.problem} → ${i.fix}`).join('\n') +
      `\n${RULES}\nReturn the updated build record.`,
    { label: `fix ${u.id}`, phase: 'Fix', schema: BUILD_SCHEMA },
  )
  return { unit: u.id, built: fixed || built, review, fixed: Boolean(fixed) }
}

// Wave 3: a slice's write set is only known after reading the code, so each
// slice scopes itself first, then slices are packed into batches whose write
// sets never overlap, respecting programme order.
async function batchesForWave3(units) {
  phase('Scope')
  const scoped = (await parallel(units.map((u) => () =>
    agent(`${describe(u)}\nRead-only: decide whether this slice is feasible now (AGENTS.md rule 2) and list every file it must write.`,
      { label: `scope ${u.id}`, phase: 'Scope', schema: SCOPE_SCHEMA, effort: 'medium' })
      .then((s) => (s ? { ...u, write: s.write, feasible: s.feasible, blocker: s.blocker } : null)))))
    .filter(Boolean)
  const blocked = scoped.filter((u) => !u.feasible)
  blocked.forEach((u) => log(`blocked: ${u.id} — ${u.blocker}`))
  const order = ['P0', 'P9', 'P7', 'P8', 'P4', 'P1', 'P3', 'P10', 'P5', 'P6']
  const todo = scoped.filter((u) => u.feasible)
    .sort((a, b) => order.indexOf(a.programme) - order.indexOf(b.programme))
  const batches = []
  for (const u of todo) {
    const fits = batches.find((b) => !b.some((o) => o.write.some((f) => u.write.includes(f)) ||
      (u.after || []).includes(`programme-${o.programme}`)))
    if (fits) fits.push(u)
    else batches.push([u])
  }
  log(`${todo.length} slices in ${batches.length} conflict-free batches; ${blocked.length} blocked`)
  return { batches, blocked }
}

async function integrate(done, label) {
  const ok = done.filter(Boolean).filter((r) => r.built && r.built.testsPassed && r.built.analyzeClean)
  log(`${label}: ${ok.length}/${done.length} units ready to integrate`)
  if (!ok.length) return { ok, report: 'nothing to merge' }
  const report = await agent(
    `You are the integrator for revamp ${label}. In the main checkout /home/eslam/Storage/Code/oc_app on branch ` +
      `${BASE}, merge these branches one at a time with --no-ff, in this order: ${ok.map((r) => 'revamp/' + r.unit).join(', ')}.\n` +
      'Conflicts: ARB files by 3-way union of keys (git show :1:/:2:/:3:), then gen-l10n; lib/ui/kit/kit.dart exports: union; ' +
      'goldens: take either side, then regenerate that golden test after merging and look at it; ' +
      'test/kit_ratchet_baseline.json: regenerate from the ratchet test output (counts may only go down). ' +
      'After all merges: gen-l10n, analyze (must be clean), then run test/kit_ratchet_test.dart, test/design_standard_test.dart, ' +
      'test/l10n_coverage_test.dart, test/ui_ledger_coverage_test.dart and every test file the merged branches touched, with -j 3. ' +
      'A failing test after a redesign may be a product bug: read it before changing it. Commit each fix with [skip ci] and the ' +
      'trailers. Never push. Report: merged, skipped (why), test results, ratchet total before/after.',
    { label: `integrate ${label}`, phase: 'Integrate' },
  )
  return { ok, report }
}

const reports = []
let results = []
let blocked = []
if (WAVE === '3') {
  const plan = await batchesForWave3(UNITS)
  blocked = plan.blocked
  let n = 0
  for (const batch of plan.batches) {
    n += 1
    const done = await pipeline(batch, (u) => buildReviewFix(u))
    results = results.concat(done)
    reports.push(await integrate(done, `wave 3 batch ${n}`))
  }
} else if (WAVE === '2c') {
  // The chat library has one editor at a time: the chain runs in order and
  // each link is integrated before the next starts.
  for (const u of UNITS) {
    const done = [await buildReviewFix(u)]
    results = results.concat(done)
    reports.push(await integrate(done, `chat chain ${u.id}`))
  }
} else {
  results = await pipeline(UNITS, (u) => buildReviewFix(u))
  reports.push(await integrate(results, `wave ${WAVE}`))
}

const merged = reports.flatMap((r) => r.ok.map((o) => o.unit))
const notReady = UNITS.map((u) => u.id).filter((id) => !merged.includes(id) && !blocked.some((b) => b.id === id))
if (notReady.length) log(`not merged: ${notReady.join(', ')}`)
return { wave: WAVE, merged, notReady, blocked: blocked.map((u) => ({ id: u.id, blocker: u.blocker })), results, reports: reports.map((r) => r.report) }

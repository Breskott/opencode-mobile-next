# E7 (Arabic / RTL) + daily fixes — root integration record

Source base `a4b2433`. Integration branch `feature/e7-fixes-integration`,
merged into `dev` on 2026-09-10. Plan and per-slice finish lines:
[PLAN.md](PLAN.md). Worker contract lives outside the tree (machine-local
`oc_app-ui-audit-20260909/e7-fixes/WORKER-CONTRACT.md`).

## What was integrated

Eleven worker branches, merged in dependency order with the English ARB
merged by key (no key conflicts) and the generated Dart regenerated once:

| Slice | Branch | State at handover from the swarm |
|---|---|---|
| Locale plumbing | `feature/e7-locale` | committed |
| Appearance preview + Settings | `feature/e7-appearance-preview` | committed + uncommitted edits |
| Projects / Attention / Monitor | `fix/e7-project-attention` | committed |
| Reader preferences | `feature/e7-reader-preferences` | uncommitted |
| Workspace / Activity | `fix/e7-workspace-clarity` | uncommitted |
| Chat results, menu, localization | `fix/e7-chat-results` | uncommitted |
| Library / providers / MCP | `fix/e7-library-language` | uncommitted |
| Setup / Termux / terminal | `fix/e7-setup-language` | uncommitted |
| Voice model | `fix/e7-voice-model-language` | uncommitted |
| Arabic corpus (baseline keys) | `l10n/e7-arabic-core`, `l10n/e7-arabic-features` | committed |
| Root shared/common UI | (integration worktree) | uncommitted |

Every uncommitted worker state was first committed verbatim as a
`wip(e7-<slice>)` checkpoint on its own branch, so nothing from the swarm was
lost or rewritten before merging. The session-auto-approval worker
(`feature/e7-session-auto-approval`) produced no source and is still open.

## Arabic catalog

`lib/l10n/app_ar.arb` is **generated**: `python3 tool/assemble_arabic_arb.py`
unions every `docs/qa/e7-*/messages_ar*.json` fragment with the two corpus
files (`arabic_core.json`, `arabic_features.json`) and `arabic_chat.json`, in
template key order, and fails on any missing key or placeholder mismatch
(placeholders are compared against the ARB metadata, not a regex over the
Arabic text). Root translated the 257 shared/chat keys nobody owned in
`docs/qa/e7-shared/messages_ar-root.json`. Coverage at integration:
3418 / 3418 keys, 0 placeholder mismatches, 0 ICU warnings from
`flutter gen-l10n`.

Add a key → add its Arabic in the owning fragment → rerun the script →
`flutter gen-l10n`. Never hand-edit `lib/l10n/app_localizations*.dart`.

## Integration fixes (root)

- `lib/ui/early_l10n.dart` — `earlyAppLocalizations(context)` reads the
  enclosing `Localizations` widget without an inherited dependency. Work that
  starts in `initState` (health checks, todos, relations, destinations,
  server commands) must use it; `Localizations.localeOf` asserts there.
- `productErrorText(error, l10n: …)` gained an optional catalog for its two
  English fallbacks; `showProductError` tolerates trees without app
  localizations.
- Composer (user feedback 2026-09-09): the "sends after this run" hint and
  the OpenCode 2 steer/queue toggle appear only while a run is active **and**
  something is typed. On OpenCode 1 the hint now says steering mid-run needs
  OpenCode 2, because v1 has no inbox and can only queue.
- Session menu chips measure their row with `LayoutBuilder`; a size-less
  `MediaQuery` used to collapse every chip to zero width.
- `InfoLabel` terms wrap; `SectionLabel` wraps its trailing status under the
  caption; create-worktree and create-workspace dialogs are scrollable. All
  three overflowed at 2.5x on 320dp.
- Analyzer: `intl` `TextDirection` clash hidden in the quota screens,
  nullable arguments, missing imports, a stray `const`, lookups hoisted ahead
  of awaits, `dart fix` + `dart format` over the merged tree.

## Verification

Pinned Flutter 3.47.2 (`~/.shorebird/bin/cache/flutter/e16cf749…`).

- `flutter analyze --no-pub`: No issues found.
- `packages/opencode_sdk`: `dart analyze` clean, `dart test` 47 passed.
- App suite: see the final run recorded in [suite-final.json](suite-final.json)
  (written by root after the last merge; 275 test files, `--concurrency=4`).

Not verified here: physical ARM64 phone, real Arabic locale on a device,
TalkBack, provider-backed background-agent completion. Those remain the open
items from `docs/qa/oc2-setup/README.md`.

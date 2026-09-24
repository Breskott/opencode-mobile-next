# QA record: the agent knows it runs on the phone

## Scope

- **Problem:** on the owner's phone (Termux, OpenCode 2, GPT-6 Astra), the agent believed it ran on a desktop. It said "open this session in the OpenCode desktop app" and "no phone ADB connection needed" (`before-agent-thinks-desktop.jpg`). Nothing on a phone server told it otherwise.
- **Fix:** before each start, both phone servers write a marked block into OpenCode's global `AGENTS.md`, which is loaded into every conversation. The block says:
  - the agent runs on the person's Android phone and the person uses the app;
  - there is no desktop app, display or adb;
  - `127.0.0.1` links open in the phone's browser;
  - bind to localhost;
  - headless browsers are heavy;
  - memory is limited and there is Android's 32-process limit;
  - long builds are slow.
- **Module:** `lib/domain/phone_agent_context.dart`.
- **Used by:** the Termux runner in `lib/termux/bridge.dart`, and `BuiltinLinux.serverScript` in `lib/builtin/builtin_linux.dart`.
- **Files written:**
  - `/root/.config/opencode/AGENTS.md` (OpenCode 1);
  - `/root/.oc-opencode2/config/opencode/AGENTS.md` (OpenCode 2, isolated config). OpenCode's V2 docs (opencode.ai/v2/docs/instructions) confirm the global `AGENTS.md` is loaded first.
- Only the text between the markers is replaced. The person's own text in the file stays. A failure never stops the server (`|| true`).

## Builds

`feat/phone-setup-v2`, the commit that adds this record. No APK built for it yet.

## Devices

None yet.
- The shell step ran on the PC with `dash`, as Ubuntu's `sh` would.
- The owner's phone was unreachable (Termux closed by Android) and was not changed.

## Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Run the context script into an empty root | Both files hold exactly the block | `phone_agent_context_test` | PASS |
| 2 | A file with the person's rules; run the Termux script twice, then the built-in one | The person's text is kept, and one block, the built-in one | as expected | PASS |
| 3 | The person adds text after the block; run again | Their text kept, no leading blank line, one block | Failed at first (a leading blank line); fixed in the awk | PASS |
| 4 | Both server scripts write it before OpenCode starts | Block before `exec`/`serve`, guarded by `\|\| true` | as expected | PASS |
| 5 | `bash -n` on the whole manager and on the runner it installs; `dash -n` on the script; run the exact runner lines with `dash` | Valid; the file is written | as expected | PASS |
| 6 | Existing guards | Server still binds 127.0.0.1 only (the text avoids the literal "0.0.0.0" the guard test forbids); the manager pin is updated on purpose | 607 tests in the related files pass | PASS |

## How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test test/phone_agent_context_test.dart test/builtin_linux_test.dart
```

## NOT proven

- **A model actually changes its answer.** This needs a device run: ask "where are you running?" on the phone server. It is planned for the integrated emulator run.
- **The owner's phone** gets it only after it has an APK with this change and the server restarts. The manager script is rewritten on each start and restart.
- **Other agents:** Claude Code or Pi through Paseo on the phone read their own instruction files (`~/.claude/CLAUDE.md`); not covered.

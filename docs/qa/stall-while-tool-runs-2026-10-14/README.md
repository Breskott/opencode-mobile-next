# Stall while a command runs (2026-10-14)

Owner screenshots: a `flutter build web` shell step running; the chat said "taking longer than usual",
offered "Run this command again" and "Try again", then showed a banner, "Connection lost" and "Offline".
Before images are the owner's screenshots (scratchpad `owner-*.jpg`); after images need a phone run and
are not included (owner tests, per the standing rule).

| # | Root cause | Fix | Test |
|---|------------|-----|------|
| 1 | `TurnStallTracker` counted only message/part/delta events as progress; a running tool emits nothing for minutes, so 45 s of silence became "model slow". Every protocol (OpenCode, OpenCode 2, Paseo, Codex) is normalised to v1 `message.part.updated`, so one feeder (`connection/turn_stall.dart`) covers all. | Tool parts pending/running per session hold the watch off; when the last one ends the silence clock restarts. Waits for a person were already "needs you". | `phone_agents_stall_tests.dart` "a running command is activity" (fails without the fix, checked) |
| 2 | `_shellRerun` / `bodyIsEmpty` checked only `executed`. | `ToolState.inFlight`; rerun only when not pending/running. | `tool_card_test.dart` running + pending |
| 3 | "Try again" was a learned phrase offered in the working moment. | `PhraseChipStore.isRedoPhrase`; never offered in `working`. | `phrase_chips_test.dart` |
| 4 | The in-app server was judged only by failed health/SSE; a CPU-loaded phone looks identical to a dead server. The banner and "Connection lost" came from that. | Native `BuiltinLinux.status().serverRunning` polled every 10 s while disconnected. Alive = busy: `defersTurnInterruption` (no banner, no turn line). After 2 min with a running tool: one neutral line "OpenCode on this phone is busy", no Restart. | stall test "alive but silent phone server is busy" |
| 5 | Restart already had a confirm sheet, but it only said a turn stops. | While a tool runs the sheet says the running command stops too. | covered by string wiring; no new test |
| 6 | Composer note claimed "Offline" for any non-connected link (the app has no network probe). | Note is "Sends when {agent} answers" (en, ar), agent defaults to OpenCode. | `kit_composer_test`, `chat_3_test`, `l10n_fg5_screens_test` |
| 7 | Banner title "Connecting to X" plus action "Reconnect to X" while already connecting. | While waiting: "Reconnecting…" (server named only with 2+ saved), no action, "Try now" in the menu. | `connection_status_presentation_test` |

## Attribution (Codex vs OpenCode)
The screenshots' chat header says "In-app Ubuntu", the composer says "Ask OpenCode…" and the app-wide banner reads
the main connection. In code the composer already says "Ask Codex…" for a `ServerBackend.codex` profile
(`agent_cards.dart::_agentName`), so these screens are an OpenCode controller whose model is "GPT-6.1 Sol".
The banner is app-wide (`AppConnectionStatusScope`, main controller) and not scoped to the chat's own controller;
not changed here. Codex transport (`lib/codex/transport.dart`, ping every 20 s, 15 s request timeout) emits running
tool parts with ids, so the stall fix covers it; the ping policy was left unchanged (no evidence it dropped).

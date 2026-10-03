# revamp-slice-R10: R10 Capability registry: terminal-only, MCP why, tool inventory (2026-09-27)

## 1. Scope

- Unit: `slice-R10` (wave 3, kit-change). Finish line: the capability registry (`docs/ux-system/capabilities.json` + `KitCapabilities`) has a Terminal-only entry, a Tool list entry and an extra-tools reason that explains a server which cannot add them. Non-goal: moving the Terminal, Tools or MCP screens onto the new ids (outside this unit's write set).
- Files changed: `docs/ux-system/capabilities.json`, `lib/ui/kit/kit_capability_explainer.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/kit/kit_capability_explainer_test.dart`, `test/kit/kit_capability_explainer_r10_test.dart` (new), `test/goldens/kit/kit_capability_explainer_golden_test.dart` (one scene added) and its two new PNGs.
- Pages (map ids): none; registry and kit part only.
- Specs followed: `docs/ux-system/kit-api/KitCapabilityExplainer.md` (registry parity, copy keys `kitCap<Id>Title/Why`, why wording, no engine words, no "assistant"); STANDARDS.md §15, §16; R11 (additive: two new entries, no API change).
- Contract problems (PROC-20): the task names the record folder `docs/qa/revamp-<unit id>/`, STANDARDS EVID-1 wants `-<YYYY-MM-DD>`; followed the task and the existing `revamp-chat-*` folders.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a: no pages.
- States per page (STATE-20): n/a. The new entries have no enable flow, so `.row` and `.state` render the explains variant (covered by `kit_capability_explainer_r10_test.dart` "the row explains without an enable action" and the `row_terminal` golden).
- Deferred states (STATE-21): none.

### What changed, item by item

| Item | Before | After |
|---|---|---|
| Terminal on its own | only `flag:fileBrowsing+terminal` ("Files and Terminal", "doesn't share its files or terminal") | new `flag:terminal`: title "Terminal", reason "This server doesn't open a terminal for you.", hosts line "Works on this phone and computers with OpenCode"; not on Codex or Paseo, partly on the demo |
| Extra tools why (`kitCapMcpAnyWhy`) | "No extra tools are added on this server yet." (reads as an empty state / invitation) | "This server can't add extra tools from the app." (the invitation stays in `kitCapMcpAnyOffer`) |
| Tool list | no entry; the Tools page gates on `server.oc1` | new `flag:toolInventory`: title "Tool list", reason "This server doesn't list the tools its agent can use."; supported on OpenCode 1 computers, partly on this phone and Termux (only while they run OpenCode 1), not on OpenCode 2, Codex, Paseo or the demo |

Moved or removed: nothing on a page. Adoption on screens is listed under NOT proven.

## 2. Builds

- Branch `revamp/slice-R10`, base `643a5104`, code head `dfadc43f`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_capability_explainer_r10_test.dart` + `test/kit/kit_capability_explainer_test.dart` | pass | 47 passed | PASS |
| 2 | `--update-goldens --plain-name row_terminal test/goldens/kit/kit_capability_explainer_golden_test.dart` | two new images, looked at | 2 passed; images below | PASS |
| 3 | `flutter analyze` on the changed Dart files and `lib/l10n/` | no issues | no issues | PASS |

Ratchet, design-standard and l10n-coverage suites were not run (owner decision 2026-09-27: run only the unit's own files).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | Registry parity | `kit_capability_explainer_test.dart` "every matrix capability has equal supported and partly sets" (now 35 rows) and `kit_capability_explainer_r10_test.dart` "flag:terminal matches…", "flag:toolInventory matches…" | run 1 |
  | STATE-12 (says which host can) | r10 "title, reason and hosts line are about the terminal alone" | run 1 |
  | COPY-11 (no engine words) | `kit_capability_explainer_test.dart` "names the host and the hosts that can, without engine words" (iterates every entry, including the new two) | run 1 |
  | AUTO-20 (no "assistant") | `kit_capability_explainer_test.dart` "no kitCap/kitHost copy mentions the setup assistant" | run 1 |

- Changed test expectations (TEST-19): `kit_capability_explainer_test.dart` matrix length 33 → 35 (two new rows, this unit).
- Goldens changed (each opened and looked at):
  - `test/goldens/kit/kit_capability_explainer_row_terminal_dark.png` and `_light.png`: new scene, "Terminal" dimmed row on a Paseo server named laptop: "Terminal isn't available on laptop (Paseo). Works on this phone and computers with OpenCode." No approved VL render for this scene (EVID-12: n/a).
- Before and after: no before render (new scene); after: `after-kit-capability-explainer-row-terminal-dark.png`, `after-kit-capability-explainer-row-terminal-light.png`.
- Accessibility: composed from `KitRow.unavailable`, unchanged; the row reads "Terminal, unavailable, {why}". No new targets.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_capability_explainer_r10_test.dart test/kit/kit_capability_explainer_test.dart
$F test -j 1 --plain-name row_terminal test/goldens/kit/kit_capability_explainer_golden_test.dart
$F analyze lib/ui/kit/kit_capability_explainer.dart test/kit lib/l10n
```

## 7. NOT proven

- Not run on a device or emulator.
- Screens do not use the new ids yet: `lib/ui/screens/terminal_screen.dart:85` (`_terminalCapability`) and `lib/ui/screens/server_capabilities_screen.dart:70` (terminal feature) still name `flag:fileBrowsing+terminal`; `lib/ui/screens/capabilities_screen.dart:130-135` still names `server.oc1`. Those files are outside this unit's write set; switching them to `flag:terminal` / `flag:toolInventory` is a one-line change each for their owners.
- `mcp_setup_screen.dart:384-388` shows its own `mcpSetupUnavailableBody` rather than `whyOf('mcp.any')`, so the new reason appears only where callers use the registry.
- `docs/ux-system/kit-api/KitCapabilityExplainer.md` still says "33" capabilities; the spec is not in this unit's write set.
- The shared suites (ratchet, design standard, l10n coverage, `server_capabilities_screen_test.dart`) were not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R10` |
| Enabled | No: registry entries only, until the Terminal/Tools screens adopt the ids | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | `revamp/slice-R10` |
| Deployed | No | |
| Released | No | |

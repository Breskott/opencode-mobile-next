# slice-qa-phone-setup — backlog B2 and B6 (emulator QA 2026-09-28)

Finish line: a nominal 2 GB phone can set up OpenCode on itself with a plain
"may be slow" note, and a saved server's connection trouble no longer sits as
a two-row banner on every setup step.
Non-goal: the in-app server's start path (`lib/main.dart` auto-start,
`lib/builtin/**` start), kit rows, Add server and other copy items (B3, B4,
B8, B9 belong to other agents).

Source: [BACKLOG.md](../emulator-qa-2026-09-28/BACKLOG.md) B2 (screens 04,
05, 96) and B6 (screens 97–117).

## B2 — memory gate for This phone setup

The gate stays on **total RAM** (`VoiceDeviceInfo.totalMemoryMb`, from
`ActivityManager.MemoryInfo.totalMem`), never Android's `memoryClass`.

| Total RAM | Before | After |
|---|---|---|
| under 1,800 MB (e.g. 1,700) | refused ("needs at least 2048 MB") | refused: "This phone doesn't have enough memory" / "OpenCode needs a phone with at least 1,800 MB of memory; this one has 1,700 MB. Run it on a computer instead and connect this phone to it." Set up disabled; Other ways (by address) stays below |
| 1,800 – 3,071 MB (nominal 2 GB = 1,972; nominal 3 GB ≈ 2,900) | 1,972 refused; 2,900 allowed silently | allowed, with one plain line above "Includes …": "It may be slow on this phone, which has 1,972 MB of memory." |
| 3,072 MB and over (e.g. 4,096) | allowed | allowed, no note |
| unknown | allowed | allowed, no note (unchanged) |

- `lib/builtin/setup/preflight.dart`: `minimumSetupMemoryMb` 2048 → 1800;
  new `comfortableSetupMemoryMb = 3072`, `SetupPreflightResult.mayBeSlow`
  and `mayBeSlow` getter (supported, carries `totalMemoryMb`). Order is
  unchanged: ABI, memory floor, free space, then the slow note (a low-space
  phone is still blocked for space).
- `phone_setup_start_screen.dart`: the note (`phone-setup-start-may-be-slow`)
  on the fresh state. The only other users of the gate — the Customize/Add
  tools sheet and the AI Team intro — read `supported`, so they now let a
  1,800–2,047 MB phone through too and keep their refusal copy for the rest.
  There is no other 2048 MB memory rule in the app (first run and This phone
  both lead to this page; the "2 GB free" strings are about storage).
- Copy (`app_en.arb`): `phoneSetupPreflightLowMemoryHeadline`,
  `phoneSetupPreflightLowMemoryBody` (numbers grouped, way forward added),
  new `phoneSetupPreflightMayBeSlow`. The stale Arabic entries for the two
  changed keys were removed (they fall back to English; Arabic is not
  authored).

## B6 — one-line status over the phone's own setup

Choice: **show it compactly**, not hide it. The line is about a different
saved server, so hiding it (`bodySays`) would stop telling the truth; the
setup page does not say it itself. Instead the phone setup pages keep the
line as one row — the words and More — with the action folded into More
(first item), and no supporting/slow line. "Reconnect to 127.0.0.1",
Details and Switch server are one tap away behind "…".

- Kit: `KitStatus.compact()` (kit_status_line.dart), `KitStatusLineSlot.compact`
  (kit_status_slot.dart) and `KitScreen.bodyQuiets` on all three
  constructors (kit_screen.dart). `bodySays` wins for a kind in both, so
  P4.4's rule (the page says it once) is unchanged; every other page still
  gets the full line with its action in view.
- Pages with `bodyQuiets: {KitStatusKind.connection}`: phone setup start
  ("On this phone"), progress, ready, Termux setup, Termux job and the
  unsupported page.

## Images (Flutter goldens, light, real fonts, DPR 1 — not device screenshots)

"Before" is the same golden test run on the base commit `5decfa8e` in a
temporary worktree; "after" is this branch (the committed goldens in
`test/revamp/goldens/qa_phone_setup_*`).

| State | Before | After |
|---|---|---|
| 1,972 MB phone, phone | [before](before_qa_phone_setup_start_2gb_light.png) | [after](after_qa_phone_setup_start_2gb_light.png) |
| 1,972 MB phone, wide | [before](before_qa_phone_setup_start_2gb_1280x800_light.png) | [after](after_qa_phone_setup_start_2gb_1280x800_light.png) |
| 1,700 MB phone | [before](before_qa_phone_setup_start_low_memory_light.png) | [after](after_qa_phone_setup_start_low_memory_light.png) |
| Setup progress under another server's line, phone | [before](before_qa_phone_setup_progress_other_server_light.png) | [after](after_qa_phone_setup_progress_other_server_light.png) |
| Setup progress under another server's line, wide | [before](before_qa_phone_setup_progress_other_server_1280x800_light.png) | [after](after_qa_phone_setup_progress_other_server_1280x800_light.png) |
| Start page under another server's line | [before](before_qa_phone_setup_start_other_server_light.png) | [after](after_qa_phone_setup_start_other_server_light.png) |

## Tests (pinned Flutter 3.47.1, via `tool/qa/machine_lock.sh`)

New / changed:
- `test/setup_preflight_test.dart`: 1,700 refused; 1,800 (floor), 1,972 and
  2,900 supported with `mayBeSlow`; 3,072 and 4,096 no note; low space on a
  slow phone still blocks; unknown memory no note.
- `test/phone_setup_start_screen_test.dart`: 1,700 MB refusal copy and way
  forward, Set up disabled; 1,972 and 2,900 MB show the note and Set up
  runs; 4,096 MB no note.
- `test/kit/kit_status_slot_test.dart`: `bodyQuiets` draws one line, action
  in More (first) and working; `bodySays` wins; `KitStatus.compact` fields.
- `test/revamp/slice_qa_phone_setup_test.dart`: start and progress pages
  under a "127.0.0.1 isn't answering" condition — told once, no visible
  Reconnect link, line one row high, Reconnect first in More and fires; no
  line without a condition; B2 + B6 together.
- `test/revamp/slice_qa_phone_setup_golden_test.dart`: the six goldens.

Run once, all passed:
- Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text,
  kit_manifest, kit_draft_manifest, architecture_boundaries, golden_harness
  — 129 passed.
- Affected files: kit_screen, kit_status_line, kit_status_slot,
  phone_setup_progress/ready/termux_job/termux screens, setup_preflight,
  slice_p4_4, goldens/phone_setup_golden, screen_phone_1 (+golden),
  slice_close_servers_termux_golden, the new slice tests — 243 passed; plus
  phone_setup_start_screen_test.
- `flutter analyze --no-pub`: No issues found.

No full suite (owner speed rule). No new failures to compare against the
base.

## Still needs a device

- A real nominal 2 GB phone (or the 2 GB emulator from the QA pass) running
  setup to the end: the note only says it may be slow; whether OpenCode is
  usable at 1,972 MB is unmeasured.
- The live connection line on the emulator during setup (screens 97–117
  retaken) — the goldens use a fixture condition shaped like
  `connectionKitStatus`'s not-answering line, not the controller.

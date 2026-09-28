# slice-builtin-speed — 2026-09-28

**Owner report (build 2063, Nubia NX721J, Android 15):** replies from OpenCode
in the app's built-in Ubuntu "feel very slow compared to Termux".

**Finish line:** the cause is measured, the app says plainly when replies come
from OpenCode's slower free model and leads to provider sign-in, the phone
stays awake while a reply runs on the in-app server, and each reply's timing
is visible on This phone. **Non-goal:** changing the proot launch or bundling
another proot when the numbers do not call for it; editing the chat library
(owned by the chat chain).

## Root causes, with numbers

### 1. proot is not the cause (measured)

Phone, read-only over adb by the coordinator while the in-app server ran:
`libproot.so` and `opencode` are in seccomp mode 2; `opencode` has
`Seccomp_filters: 2` (proot itself 1, the app's own filter) and
`TracerPid` = proot, so **proot's seccomp acceleration is active**. cgroup
cpu/cpuset `top-app`. `/global/health` through adb forward: 25–35 ms. proot's
voluntary context switches ≈ 44k: normal traced-syscall overhead.

Emulator benchmark (emulator-5554, x86_64 Android 14, app uid via `su`,
Ubuntu with node + npm OpenCode; 5 runs each, variants interleaved, host load
≈ 13). Median ms (min–max):

| Workload | Ours (as shipped) | `PROOT_NO_SECCOMP=1` | no `--link2symlink` | no fake /proc binds | proot-distro style |
|---|---|---|---|---|---|
| `true` (proot start) | 13 (12–14) | 11 | 12 | 12 | 20 (19–21) |
| `node -e 0` | 48 | 60 | 46 | 47 | 58 |
| `opencode --version` | 622 (610–623) | 810 (788–1062) | 615 | 615 | 703 (693–798) |
| 200 × `/bin/true` | 292 | 461 (454–538) | 285 | 292 | 348 |
| node walk + stat, 5k files | 728 (637–1301) | 736 | 675 | 758 | 733 |
| `git status`, 5k-file repo | 343 (314–429) | 347 | 296 (284–298) | 337 | 354 |
| node 20k × 1 KB write/read | 2877 (2797–3031) | 4064 (4000–4254) | 2785 | 2941 | 3355 (3342–3546) |

- `PROOT_VERBOSE=1`: `ptrace acceleration (seccomp mode 2, new syscall order)
  enabled`; `libproot.so -V`: `built-in accelerators: process_vm = yes,
  seccomp_filter = yes` (Termux proot 5.1.107.94, the same package Termux
  ships). Turning seccomp off makes exec/I/O work 1.3–1.6× slower — so it
  matters, and it is on.
- `--link2symlink` costs 3–13 % (within noise except `git status`); dpkg and
  git need hard links on Android, so it stays. Fake /proc binds: no effect.
- The proot-distro launch (fake kernel release, `/dev/random`, system binds,
  `PROOT_L2S_DIR`) is **slower** than ours (+7 ms start, +17 % I/O).
- Termux's newest proot is 5.1.107.95 (2026-09-25): two correctness fixes
  (fork event without PID; seccomp exit handling), no speed change. Not bumped.

Scripts and raw output: [bench/](bench/) (`bench-raw.txt`; `setup.sh` makes
the 5k-file tree and repo, `bench.sh <nativeDir> <reps> <workloads>` runs the
variants as the app uid).

**Decision:** keep the launch flags, environment and binary unchanged.

### 2. Probable main cause: OpenCode's free model (no provider signed in)

After the storage reset / move from Termux, the in-app server has no provider
sign-ins (sign-ins never move). OpenCode then answers with its own free
default model (e.g. `opencode/big-pickle`): shared, rate-limited, slower.
Termux's server uses the owner's own provider. The app did not say so.

### 3. No wake lock for the in-app server

The foreground service (type `specialUse`) kept the process alive, but
`dumpsys power` showed `mWakeLockSummary=0x0`: with the screen off the phone
sleeps mid-reply. Termux normally holds a partial wake lock.

### 4. Minor: rootfs size walk

`bytesUsed()` walked the whole Ubuntu tree (emulator: 21,122 entries;
`find` 132–141 ms warm, ≈ 822 ms cold) at most once a minute while the app
polls status every 5 s. Small, but it competes with a reply for the disk.

## What changed

- **Free-model notice** (`lib/domain/free_model.dart`,
  `lib/state/free_model_notice.dart`): one rule — the model in use is
  OpenCode's own (`opencode`), priced zero, and no other provider is signed in
  (a model without a price is never assumed free; someone signed in elsewhere
  who picks a free model chose it). This phone shows, when connected to that
  server: "Using OpenCode's free model — it's slower. Sign in to your provider
  to use your own." with **Sign in to a provider** (the server's provider
  sign-ins, the same page Settings and `/connect` open).
- **Move from Termux › done:** the sign-in row now says why it matters:
  "…Sign-ins never move: until you sign in here, replies use OpenCode's free
  model, which is slower."
- **Wake lock while a reply runs** (`lib/builtin/reply_watch.dart`,
  `BuiltinLinux.kt`, manifest `WAKE_LOCK`): a `PARTIAL_WAKE_LOCK`
  (`OpenCode:reply`, not reference-counted) held only while the connected
  server is the in-app one and a session is busy, and only while the server
  process runs. Every hold times out by itself (10 min asked, 15 min native
  cap); renewed every 5 min while a reply runs; released at once when none
  does, when the server stops, or when the watch is disposed. One unbroken
  stretch is capped at 6 h (counted in renewals), then not held again until
  the replies stop (`reply.awake_capped` mark). The Android 15 6-hour
  foreground-service cap applies to `dataSync`/`mediaProcessing`; this
  service is `specialUse`, which has no such cap — the 6 h stretch ceiling is
  ours, per AGENTS.md "no unbounded background lifetime".
- **Reply timing** (`ReplyWatch`): from the server's events — user message →
  first assistant output (text, reasoning, tool or delta) → idle/error — into
  the performance trace as `reply.first_token` (attrs `server=in-app|other`,
  `server_ms` = the same wait by the server's own clock, `model`) and
  `reply.done` (`first_ms`, `model`, error outcome). These reach the problem
  report with the other OCTRACE spans.
- **This phone:** a **Reply speed** row ("Last reply: first words after 4.1 s,
  finished after 22.0 s"; left out until a reply was timed) and, folded under
  **Details**, Performance values: *Linux speed mode* (Fast: proot with
  seccomp / Slow: proot without seccomp / Not known while OpenCode is
  stopped — read from `/proc` Seccomp_filters of proot vs the server),
  *Phone kept awake*, *First words, last reply* (app vs server), *Model, last
  reply*.
- `bytesUsed()`: measured at most every 10 minutes, at background thread
  priority, and not started while a reply holds the wake lock.

## Needs the chat chain (not edited here)

The chat and its model chip should say the same thing; the chat library is
owned by the chat chain (brief rule 4), so this slice gives the hook instead:

- `connectionUsesFreeModel(conn, sessionID: widget.sessionID)` in
  `lib/state/free_model_notice.dart` (per-session model, else the server's).
- Copy: `l10n.freeModelNotice`, `l10n.freeModelSignIn`.
- Action: the existing `_ChatCommandAction.integrations` target
  (`IntegrationsScreen(mode: IntegrationsMode.providers)`).
- Model chip (`lib/ui/kit/chat/kit_composer_chips.dart`): a "free" state that
  reads the same function.

## Tests

New: `test/reply_watch_test.dart` (7: timing app vs server, failed reply,
other server, repeated user message, wake hold/renew/release, 6 h ceiling,
not for other servers), `test/free_model_test.dart` (4),
`test/this_phone_speed_test.dart` (4: notice + sign-in opens providers, not
with a provider signed in, not when not connected, Reply speed row +
Performance under Details). All pass.

Existing, run once, all pass (195): `this_phone_screen_test`,
`this_phone_component_removal_test`, `this_phone_plain_failures_test`,
`termux_migration_ui_test`, `builtin_linux_test`, `l10n_coverage_test`,
`ui_glossary_test`, `kit_ratchet_test`, `perf_trace_test`,
`phone_server_card_queued_prompts_test`,
`phone_server_remove_keep_projects_test`, `revamp/screen_phone_1_test`,
`termux_clarity_test`. `flutter analyze` (whole project): no issues.
Release build: `flutter build apk --release --build-number=2064` under
`tool/qa/machine_lock.sh build` → built `app-release.apk` (89.9 MB);
`key.properties` copied from the main checkout and deleted after.

## Images

Before: the same page without these parts —
`test/revamp/goldens/close_servers_this_phone_up_to_date_light.png` and
`test/revamp/goldens/phone_this_phone_details_log_light.png`.
After (synthetic data, `tool/capture/builtin_speed_capture_test.dart`):

- `after_this_phone_free_model_{412x915,1280x800}.png`
- `after_this_phone_reply_speed_{412x915,1280x800}.png`
- `after_this_phone_performance_details_{412x915,1280x800}.png`

## How the owner confirms on the phone

1. Open **This phone**. If "Using OpenCode's free model — it's slower" shows,
   tap **Sign in to a provider**, sign in, pick your model, and ask again.
2. After a reply, **Reply speed** shows first words / finished. Open
   **Details**: *Linux speed mode* should read "Fast: proot with seccomp";
   *First words* splits the wait between the app and the server — a large
   server number is the model/provider, a large gap between the two is the
   phone or the app.
3. Lock the screen during a long reply: it keeps going (*Phone kept awake:
   Now, while a reply runs*). Read-only check:
   `adb shell dumpsys power | grep OpenCode:reply` while a reply runs, and
   gone after it ends.
4. Report a problem: `reply.first_token` / `reply.done` lines with
   `server_ms`, `first_ms` and the model are in the trace.

Device proof on the owner's phone is still needed (no device was touched
here beyond the emulator benchmark).

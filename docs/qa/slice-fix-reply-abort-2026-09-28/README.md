# slice-fix-reply-abort — 2026-09-28

Fixes F2 (P1, lost work) and F6 (P3) from
`docs/qa/emulator-qa-claude-2026-09-28/README.md`.

## Root cause

On every connect, `_loadCatalog` compares `/provider` `connected` with
`/config/providers` (the instance's live runtime). Any provider that is
connected but not in the runtime was "healed" by
`refreshProviderRuntime()`, which is `POST /instance/dispose` for the project
and for the server-default location. Disposing an OpenCode 1 instance aborts
every reply running in it (`MessageAbortedError`, shown as "You stopped this
reply").

The detection was not wrong about the wire; it was wrong about the meaning.
Reproduced on a sandboxed OpenCode 1.18.23 (fake credentials in a throwaway
`XDG_DATA_HOME`, no real keys read or printed):

| auth.json entry | `/provider` connected | `/config/providers` | after dispose |
| --- | --- | --- | --- |
| anthropic (oauth) | yes | no | still no |
| google (oauth) | yes | no | still no |
| openai (oauth, built-in plugin) | yes | yes | yes |
| groq (api key added after start) | yes | no | **yes** |

`connected` comes from the auth store; the runtime only loads a sign-in it
has a loader for. Anthropic and Google OAuth sign-ins have no plugin on 1.18,
so a dispose can never load them. The heal guard was per connection
generation only, so **every cold start** disposed the instance again —
aborting whatever was running — and the picker kept saying "not loaded yet"
(F6).

## Fix

- `SdkProductRepository.refreshProviderRuntime` reads `/session/status` for
  both locations it disposes and throws `ProviderRuntimeBusyException(n)`
  (domain) without disposing while any session is `busy` or `retry`. An
  unreadable status also refuses. This guards every caller: the catalog heal,
  the one-time connect migration, the picker's Reload, key connect/disconnect
  and OAuth finish (the last three treat "busy" as deferred, not a failure).
- `ConnectionController`: a refused heal is deferred and re-run when the last
  running session goes idle (`session.status idle`, `session.idle`,
  `session.error`). `providerReloadWaitingOn` carries the count.
- A set that stayed unloaded after a real refresh is remembered per profile
  and location (`oc.providerRuntimeUnloadable.<profileId>.<location>`, swept
  by profile deletion). A later start that finds the same set does not
  dispose at all. The manual Reload still retries and clears it on success.
- Picker (F6): `unloadedProvidersUnusable` switches the copy from "has not
  loaded them yet" to "this server could not load those sign-ins even after
  a reload … Sign in another way under Providers, or pick another model", and
  appends "The reload waits for N running replies to finish, because
  reloading would stop them" while deferred.
- OpenCode 2: no equivalent. `providerRuntimeRefresh` is false (v2
  hot-reloads provider config) and its `refreshProviderRuntime` is never
  called; `disposeFolderInstance` is v1-only and only for a folder the app
  just created.

## Tests

New `test/provider_reload_running_reply_test.dart` (11 tests):
repository refuses to dispose while a reply runs (project and default
instance, `retry` counted), refuses when status is unreadable, disposes both
when idle, a key saved during a reply connects without a dispose; cold start
with a running reply does not reset and reloads after `session.idle`; an
unloadable set is not re-disposed on the next cold start and is marked
unusable; manual reload during replies waits; deletion sweep sees the key;
picker copy.

Fail-first: with the guard and the remembered-set check reverted, 5 of the 11
fail (all three repository dispose guards, the second-cold-start test and the
manual-reload test); restored, all pass.

Existing files run (all pass): provider_runtime_heal, product_repository
(three dispose-order expectations now include the two status reads),
model_picker, revamp/slice_p3_3_model_sheet, revamp/shared_chat_1,
library_integrations, connection_v2, kit_ratchet, integration_auth_recovery,
credential_ingress_redaction, profile_deletion, e7_library_layout,
chat_live_events, library_commands, chat_server_state_ui, library_refresh,
library_skills, api2_provider_workflows, revamp/screen_library_3,
architecture_boundaries. `flutter analyze`: no issues.

## Still needs a device

Repeat the QA recipe on the emulator: long prompt, force-stop within 5 s,
relaunch — `/session/status` must stay busy and the reply finish; then open
the model picker and check the Anthropic/Google row reads "could not load".
No screenshots: the picker row is the existing kit row with new copy.

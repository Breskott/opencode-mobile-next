# API-key-led sign-in for Anthropic and Google — 2026-09-29

Finish line: for Anthropic and Google the person adds an API key (with the
provider's official key page one tap away) instead of a browser sign-in that
this server can never load, and lands back knowing whether it loaded.
Non-goal: any OAuth plugin (Codex feasibility: docs/qa/codex-oauth-2026-09-29).

## What changed
- Providers › Connect Anthropic / Google: only the key method is offered (when
  the server advertises one; nothing is invented otherwise). It opens the key
  dialog directly; one plain line says why browser sign-in is not used and that
  the key is separately billed. "Get a key from Anthropic|Google" leaves the
  dialog, asks through `openExternalLink` (console.anthropic.com/settings/keys,
  aistudio.google.com/apikey), and returns to the key dialog. Other providers
  keep their method choice. The row summary agrees ("Add an API key").
- After a key is saved the catalog refreshes (the server's idle-safe runtime
  refresh already runs in `connectIntegrationKey`; never while replies run).
  The status says: ready with a model in the catalog; waiting for running
  replies; could not load after a refresh; or not loaded yet. OAuth completion
  no longer says "connected" for a provider still listed as unloaded.
- Free-model notice now says "Add an API key from your provider…" and its
  action reads "Add an API key" (same destination: Providers).
- Model picker row for providers the server could not load after a reload
  points to API keys under Providers instead of "sign in another way".
- Keys stay a secret field, never echoed (test asserts the value is not shown).

## Tests
- New in test/library_integrations_test.dart: key-led flow for both providers
  (no method sheet, no OAuth call, link confirm names the host, back in the
  dialog, key saved, value never shown, honest "not loaded yet" status); no key
  method keeps the server's offer; other providers keep the choice sheet; key
  page URLs. New assertion in test/model_picker_test.dart.
- Ran: library_integrations, model_picker, chat_free_model_note, kit_ratchet,
  redaction, credential_ingress_redaction, ui_glossary, no_raw_error_text,
  golden_harness, architecture_boundaries, l10n_coverage; whole-project
  `flutter analyze` clean. (There is no kit_manifest_test.dart in this tree.)
- The 9 pre-existing evidence goldens were not touched.

## Images
- anthropic_key_412_dark.png, anthropic_key_1280_light.png

## Needs a device
Real key entry against a live server, and that the provider row loads and a
model is pickable afterwards (this needs a real key; not exercised).
